pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LinearInterpolationDelayModel} from "src/LinearInterpolationDelayModel.sol";
import {WithdrawalEscrow, IWithdrawDelayModel} from "src/WithdrawalEscrow.sol";
import {FiRMSlashingModule} from "src/FiRMSlashingModule.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC4626.sol";
import {JDola} from "src/jDola.sol";

contract MintableERC20 is ERC20 {
    constructor(string memory name, string memory sym) ERC20(name, sym, 18){
    }

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}

contract MockDbr is MintableERC20 {

    constructor() MintableERC20("test DBR", "DBR") {}
    
    mapping(address => bool) public markets;

    function setMarket(address market, bool isMarket) external {
        markets[market] = isMarket;
    }
}

contract MockMarket {
    MintableERC20 public dbr;
    MintableERC20 public dola;
    mapping(address => uint) public debts;
    mapping(address => uint) public collateral;
    uint public collateralPrice;
    
    constructor(address _dbr, address _dola){
        dbr = MintableERC20(_dbr);
        dola = MintableERC20(_dola);
    }

    function setDebt(address borrower, uint amount) external {
        debts[borrower] = amount;
    }

    function setCollateral(address borrower, uint amount) external {
        collateral[borrower] = amount;
    }

    function setCollateralPrice(uint price) external {
        collateralPrice = price;
    }

    function getCollateralValue(address borrower) external view returns(uint){
        return collateral[borrower] * collateralPrice / 1e18;
    }

    function repay(address borrower, uint amount) external {
        dola.transferFrom(msg.sender, address(this), amount);
        debts[borrower] -= amount;
    }
}

contract FiRMSlashingModuleTest is Test{

    WithdrawalEscrow withdrawalEscrow;
    IWithdrawDelayModel withdrawDelayModel;
    address gov = address(0xA);
    address operator = address(0xB);
    address borrower = address(0xC);
    address depositor = address(0xD);
    address guardian = address(0xE);
    uint MAX_WITHDRAWAL_DELAY = 60 days;
    MintableERC20 dola;
    MockDbr dbr;
    MockMarket market;
    JDola jDola;
    FiRMSlashingModule slashingModule;

    function setUp() external {
       withdrawDelayModel = IWithdrawDelayModel(address(new LinearInterpolationDelayModel(1 days, 30 days, 5000, gov)));
       withdrawalEscrow = new WithdrawalEscrow(gov, address(withdrawDelayModel));
       dola = new MintableERC20("test DOLA", "DOLA");
       dbr = new MockDbr();
       jDola = new JDola(gov, operator, address(withdrawalEscrow), address(dbr), dola, "testJDOLA", "TJD");
       slashingModule = new FiRMSlashingModule(address(jDola), address(dbr), address(dola), gov);
       market = new MockMarket(address(dbr), address(dola));
       vm.prank(gov);
       withdrawalEscrow.initialize(address(jDola));
       vm.warp(21 days);
    }

    function testSlash() external {
        market.setCollateral(borrower, 1e18);
        market.setDebt(borrower, 1e18);
        market.setCollateralPrice(1e18);

        vm.expectRevert("Market not allowed");
        slashingModule.slash(address(market), address(borrower));

        vm.prank(gov);
        slashingModule.allowMarket(address(market));
        
        vm.expectRevert("Market not active FiRM market");
        slashingModule.slash(address(market), address(borrower));

        vm.prank(gov);
        dbr.setMarket(address(market), true);

        vm.expectRevert("Market protection not activated");
        slashingModule.slash(address(market), address(borrower));

        vm.warp(slashingModule.activationTime(address(market)));

        vm.expectRevert("No bad debt");
        slashingModule.slash(address(market), address(borrower));

        market.setCollateralPrice(1e18/2);

        vm.expectRevert("Debt too low");
        slashingModule.slash(address(market), address(borrower));

        market.setDebt(borrower, 1000 * 1e18);
        market.setCollateral(borrower, 1000 * 1e18);

        vm.expectRevert("Collateral value too high");
        slashingModule.slash(address(market), address(borrower));

        market.setCollateral(borrower, 200 * 1e18);

        vm.expectRevert("ONLY SLASHING MODULE");
        slashingModule.slash(address(market), address(borrower));

        vm.prank(gov);
        jDola.setSlashingModule(address(slashingModule), true);

        dola.mint(depositor, 10000 * 1e18);
        vm.startPrank(depositor);
        dola.approve(address(jDola), 10000 * 1e18);
        jDola.deposit(jDola.MIN_ASSETS(), depositor);
        vm.stopPrank();

        vm.expectRevert("Zero slash");
        slashingModule.slash(address(market), address(borrower));

        vm.startPrank(depositor);
        jDola.deposit(dola.balanceOf(depositor), depositor);
        vm.stopPrank();

        uint marketDolaBalBefore = dola.balanceOf(address(market));
        uint totalAssetsBefore = jDola.totalAssets();
        uint badDebt = market.debts(borrower) - market.getCollateralValue(borrower);
        uint slashed = slashingModule.slash(address(market), address(borrower));

        vm.assertEq(slashed, badDebt, "Slashed not equal bad debt");
        vm.assertEq(market.debts(borrower), market.getCollateralValue(borrower), "Remaining debt not equal collateral value");
        vm.assertEq(dola.balanceOf(address(market)), marketDolaBalBefore + slashed, "Market DOLA balance didn't increase by slashed");
        vm.assertEq(totalAssetsBefore - slashed, jDola.totalAssets(), "Total assets did not decrease by slashed");
    }

    function testFuzzSlashing(uint debtAmount) external {
        uint depositAmount = 10000 * 1e18;
        debtAmount = bound(debtAmount, 200 * 1e18, depositAmount * 2);
        vm.startPrank(gov);
        slashingModule.allowMarket(address(market));
        dbr.setMarket(address(market), true);
        vm.warp(slashingModule.activationTime(address(market)));
        market.setCollateralPrice(1e18);
        market.setDebt(borrower, debtAmount);
        market.setCollateral(borrower, 200 * 1e18 - 1);
        jDola.setSlashingModule(address(slashingModule), true);
        vm.stopPrank();

        dola.mint(depositor, depositAmount);
        vm.startPrank(depositor);
        dola.approve(address(jDola), depositAmount);
        jDola.deposit(jDola.MIN_ASSETS(), depositor);
        vm.stopPrank();

        vm.expectRevert("Zero slash");
        slashingModule.slash(address(market), address(borrower));

        vm.startPrank(depositor);
        jDola.deposit(dola.balanceOf(depositor), depositor);
        vm.stopPrank();

        uint marketDolaBalBefore = dola.balanceOf(address(market));
        uint totalAssetsBefore = jDola.totalAssets();
        uint badDebt = market.debts(borrower) - market.getCollateralValue(borrower);
        uint availableAssets = jDola.totalAssets() - jDola.MIN_ASSETS();
        uint slashed = slashingModule.slash(address(market), address(borrower));
        if(badDebt > depositAmount){
            uint newBadDebt = market.debts(borrower) - market.getCollateralValue(borrower);
            vm.assertEq(newBadDebt, badDebt - slashed, "Bad debt did not decrease by slashed");
            vm.assertEq(slashed, availableAssets, "Slashed not equal available assets");
            vm.assertEq(0, jDola.totalAssets() - jDola.MIN_ASSETS(), "Available assets not equal 0");
        } else {
            vm.assertEq(slashed, badDebt, "Slashed not equal bad debt");
            vm.assertEq(market.debts(borrower), market.getCollateralValue(borrower), "Remaining debt not equal collateral value");
        }
        vm.assertEq(dola.balanceOf(address(market)), marketDolaBalBefore + slashed, "Market DOLA balance didn't increase by slashed");
        vm.assertEq(totalAssetsBefore - slashed, jDola.totalAssets(), "Total assets did not decrease by slashed");
    }

    function testAllowMarket() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.allowMarket(address(market));

        vm.prank(gov);
        slashingModule.allowMarket(address(market));
        assert(slashingModule.allowedMarkets(address(market)));
        vm.assertEq(slashingModule.activationTime(address(market)), block.timestamp + slashingModule.activationDelay());
    }

    function testDisallowMarket() external {
        vm.startPrank(gov);
        slashingModule.allowMarket(address(market));
        slashingModule.setGuardian(guardian);
        vm.stopPrank();

        vm.expectRevert("ONLY GUARDIAN OR GOV");
        slashingModule.disallowMarket(address(market));

        vm.warp(slashingModule.activationTime(address(market)));

        vm.expectRevert("GUARDIAN CANNOT REMOVE ACTIVE MARKET");
        vm.prank(guardian);
        slashingModule.disallowMarket(address(market));

        vm.prank(gov);
        slashingModule.disallowMarket(address(market));
        vm.assertEq(slashingModule.allowedMarkets(address(market)), false);
        vm.assertEq(slashingModule.activationTime(address(market)), 0);

        vm.prank(gov);
        slashingModule.allowMarket(address(market));

        vm.prank(guardian);
        slashingModule.disallowMarket(address(market));
        vm.assertEq(slashingModule.allowedMarkets(address(market)), false);
        vm.assertEq(slashingModule.activationTime(address(market)), 0);
    }

    function testSetMaxCollateralValue() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.setMaxCollateralValue(1);

        vm.expectRevert("Max collateral value must be > 0");
        vm.prank(gov);
        slashingModule.setMaxCollateralValue(0);

        vm.prank(gov);
        slashingModule.setMaxCollateralValue(1);
        vm.assertEq(slashingModule.maxCollateralValue(), 1);
    }

    function testSetMinDebt() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.setMinDebt(1000 * 1e18);

        vm.prank(gov);
        slashingModule.setMinDebt(1000 * 1e18);

        vm.assertEq(slashingModule.minDebt(), 1000 * 1e18);
    }

    function testSetActivationDelay() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.setActivationDelay(1);

        uint minDelay = slashingModule.MIN_ACTIVATION_DELAY();
        vm.expectRevert("ACTIVATION DELAY BELOW MIN");
        vm.prank(gov);
        slashingModule.setActivationDelay(minDelay - 1);

        vm.prank(gov);
        slashingModule.setActivationDelay(minDelay);
        vm.assertEq(slashingModule.activationDelay(), minDelay);
    }

    function testSetGov() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.setPendingGov(guardian);

        vm.prank(gov);
        slashingModule.setPendingGov(guardian);
        vm.assertEq(slashingModule.pendingGov(), guardian);

        vm.expectRevert("ONLY PENDING GOV");
        slashingModule.acceptGov();

        vm.prank(guardian);
        slashingModule.acceptGov();
        vm.assertEq(slashingModule.gov(), guardian);
        vm.assertEq(slashingModule.pendingGov(), address(0));
    }

    function testSetGuardian() external {
        vm.expectRevert("ONLY GOV");
        slashingModule.setGuardian(borrower);

        vm.prank(gov);
        slashingModule.setGuardian(borrower);
        vm.assertEq(slashingModule.guardian(), borrower);
    }
}
