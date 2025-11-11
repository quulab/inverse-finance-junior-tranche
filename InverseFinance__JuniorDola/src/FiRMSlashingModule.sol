pragma solidity ^0.8.21;

interface IJuniorPool {
    function slash(uint amount) external returns(uint slashed);
}

interface IDBR {
    function markets(address) external view returns(bool);
}

interface IERC20 {
    function approve(address pender, uint amount) external;
}

interface IMarket {
    function debts(address borrower) external view returns(uint);
    function getCollateralValue(address borrower) external view returns(uint);
    function repay(address borrower, uint amount) external;
}

contract FiRMSlashingModule {
    
    IJuniorPool public immutable JUNIOR_POOL;
    IDBR public immutable DBR;
    IERC20 public immutable DOLA;
    address public gov;
    address public pendingGov;
    address public guardian;
    uint public maxCollateralValue = 200e18;
    uint public minDebt = 50e18;
    uint public activationDelay = 14 days;
    uint public constant MIN_ACTIVATION_DELAY = 7 days;


    mapping(address => bool) public allowedMarkets;
    mapping(address => uint) public activationTime;

    constructor(address _slashingPool, address _dbr, address _dola, address _gov){
        require(_gov != address(0), "Zero address");
        JUNIOR_POOL = IJuniorPool(_slashingPool);
        DBR = IDBR(_dbr);
        DOLA = IERC20(_dola);
        gov = _gov;
    }

    modifier onlyRole(address role, string memory errMsg) {
        require(msg.sender == role, errMsg);
        _;
    }

    event NewPendingGov(address);
    event NewGov(address);
    event NewGuardian(address);
    event NewMarket(address, uint activationTime);
    event MarketRemoved(address);
    event Slash(address indexed market, address indexed borrower, uint amount);

    /**
     * @notice Repays up to the total bad debt incurred by `borrower` in FiRM `market`
     * @dev Bad debt is not guaranteed to be repaid, as their may not be enough funds in the JUNIOR_POOL
     * @param market The FiRM market contract with bad debt
     * @param borrower The borrower that has incurred bad debt
     * @return The amount of repaid bad debt
     */
    function slash(address market, address borrower) public returns(uint) {
        require(allowedMarkets[market], "Market not allowed"); 
        require(DBR.markets(market), "Market not active FiRM market");
        require(activationTime[market] <= block.timestamp && activationTime[market] > 0, "Market protection not activated");
        uint collateralValue = IMarket(market).getCollateralValue(borrower);
        uint debt = IMarket(market).debts(borrower);
        require(debt > collateralValue, "No bad debt");
        //We require debt to be above a minDebtValue to avoid unliquidateable debt being used to drain jDOLA depositors
        require(debt >= minDebt, "Debt too low");
        //We want positions to be liquidated before repaying bad debt, so we enforce a max collateral value
        require(collateralValue <= maxCollateralValue, "Collateral value too high");
        uint slashed = JUNIOR_POOL.slash(debt - collateralValue);
        DOLA.approve(market, slashed);
        IMarket(market).repay(borrower, slashed);
        emit Slash(market, borrower, slashed);
        return slashed;
    }

    /// ADMIN METHODS

    /**
     * @notice Adds a market to the protected pool of markets after an activation delay, allowing bad debt repayments
     * @dev WARNING: MAKE SURE MARKET CONTRACT ISN'T A TROJAN CONTRACT THAT CAN STEAL BAD DEBT REPAYMENTS
     * @param market New market to add to protected pool
     */
    function allowMarket(address market) onlyRole(gov, "ONLY GOV") external {
        allowedMarkets[market] = true;
        activationTime[market] = block.timestamp + activationDelay;
        emit NewMarket(market, block.timestamp + activationDelay);
    }

    /**
     * @notice Removes a market from the protected pool of markets.
     * @dev Guardian role can disallow market during the activation delay
     * @param market Market to have protections removed
     */
    function disallowMarket(address market) external {
        require(msg.sender == guardian || msg.sender == gov, "ONLY GUARDIAN OR GOV");
        if(msg.sender == guardian){
            require(block.timestamp < activationTime[market], "GUARDIAN CANNOT REMOVE ACTIVE MARKET");
        }
        allowedMarkets[market] = false;
        activationTime[market] = 0;
        emit MarketRemoved(market);
    }

    /**
     * @notice Sets the max collateral value for slashings
     * @dev Repayment of bad debt should only happen after liquidations have taken place
     * @param _maxCollateralValue The new max collateral value
     */
    function setMaxCollateralValue(uint _maxCollateralValue) external onlyRole(gov, "ONLY GOV") {
        require(_maxCollateralValue > 0, "Max collateral value must be > 0");
        maxCollateralValue = _maxCollateralValue;
    }

    /**
     * @notice Sets the min debt value for slashings
     * @dev Min debt value avoids tiny unliquidateable positions to rack up debt and incur losses for jDOLA depositors
     * @param _minDebt The new min debt
     */
    function setMinDebt(uint _minDebt) external onlyRole(gov, "ONLY GOV") {
        minDebt = _minDebt;
    }

    /**
     * @notice Sets the activation delay.
     * @param _activationDelay The new activation delay. Must be above the hardcoded min activation delay.
     */
    function setActivationDelay(uint _activationDelay) external onlyRole(gov, "ONLY GOV") {
        require(_activationDelay >= MIN_ACTIVATION_DELAY, "ACTIVATION DELAY BELOW MIN");
        activationDelay = _activationDelay;
    }

    /**
     * @notice Sets the pending gov
     * @dev Contract uses set-accept pattern for governance change
     * @param _pendingGov The new pending gov
     */
    function setPendingGov(address _pendingGov) onlyRole(gov, "ONLY GOV") external {
        pendingGov = _pendingGov;
        emit NewPendingGov(pendingGov);
    }

    /**
     * @notice Sets the guardian role. Guardian may cancel the inclusion of new markets in the activation period.
     * @param _guardian Address of the new guardian
     */
    function setGuardian(address _guardian) onlyRole(gov, "ONLY GOV") external {
        guardian = _guardian;
        emit NewGuardian(guardian);
    }

    /**
     * @notice Callable by pending gov to accept gov role
     * @dev Contract uses set-accept pattern for governance
     */
    function acceptGov() onlyRole(pendingGov, "ONLY PENDING GOV") external {
        gov = pendingGov;
        pendingGov = address(0);
        emit NewGov(gov);
    }
}
