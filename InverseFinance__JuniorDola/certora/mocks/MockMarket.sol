pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

contract MockMarket {
    MockERC20 public dbr;
    MockERC20 public dola;

    mapping(address => uint) public debts;
    mapping(address => uint) public collateral;
    uint public collateralPrice;

    constructor(address _dbr, address _dola){
        dbr = MockERC20(_dbr);
        dola = MockERC20(_dola);
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