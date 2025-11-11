pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LinearInterpolationDelayModel} from "src/LinearInterpolationDelayModel.sol";
import {WithdrawalEscrow, IWithdrawDelayModel} from "src/WithdrawalEscrow.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC4626.sol";
import {JDola} from "src/jDola.sol";

contract MintableERC20 is ERC20 {
    constructor(string memory name, string memory sym) ERC20(name, sym, 18){
    }

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}

contract JDolaTest is Test{

    WithdrawalEscrow withdrawalEscrow;
    IWithdrawDelayModel withdrawDelayModel;
    address gov = address(0xA);
    address operator = address(0xB);
    address user = address(0xC);
    address slashingModule = address(0xD);
    uint MAX_WITHDRAWAL_DELAY = 60 days;
    MintableERC20 asset;
    MintableERC20 dbr;
    JDola jDola;

    function setUp() external {
       withdrawDelayModel = IWithdrawDelayModel(address(new LinearInterpolationDelayModel(1 days, 30 days, 5000, gov)));
       withdrawalEscrow = new WithdrawalEscrow(gov, address(withdrawDelayModel));
       asset = new MintableERC20("test DOLA", "DOLA");
       dbr = new MintableERC20("test DBR", "DBR");
       jDola = new JDola(gov, operator, address(withdrawalEscrow), address(dbr), asset, "testJDOLA", "TJD");
       vm.prank(gov);
       withdrawalEscrow.initialize(address(jDola));
       vm.warp(21 days);
    }

    function testDeposit() external {
        uint depositAmount = 1e18;
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);

        uint minShares = jDola.MIN_SHARES();
        vm.expectRevert("Shares below MIN_SHARES");
        jDola.deposit(minShares - 1, user);

        jDola.deposit(1e18, user);
        
        vm.assertEq(jDola.balanceOf(user), depositAmount, "Received shares not equal expected");
        vm.assertEq(jDola.totalAssets(), depositAmount, "Total assets not equal assets deposited");
    }

    function testWithdraw() external {
        uint depositAmount = jDola.MIN_ASSETS();
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);

        vm.expectRevert("Only withdraw escrow");
        jDola.withdraw(1, user, user);

        jDola.approve(address(withdrawalEscrow), depositAmount);
        withdrawalEscrow.queueWithdrawal(depositAmount / 2, MAX_WITHDRAWAL_DELAY);
        (uint start,) = withdrawalEscrow.exitWindows(user);
        vm.warp(start);

        vm.expectRevert("Assets below MIN_ASSETS");
        withdrawalEscrow.completeWithdraw();
        
        jDola.approve(address(withdrawalEscrow), depositAmount);
        withdrawalEscrow.cancelWithdrawal();
        withdrawalEscrow.queueWithdrawal(jDola.balanceOf(user), MAX_WITHDRAWAL_DELAY);
        (start,) = withdrawalEscrow.exitWindows(user);
        vm.warp(start);

        withdrawalEscrow.completeWithdraw();
        vm.assertEq(asset.balanceOf(user), depositAmount, "User didn't successfully withdraw");
        vm.assertEq(jDola.totalAssets(), 0, "Assets still remaining in vault");
        vm.assertEq(jDola.totalSupply(), 0, "Shares still remaining in vault");
    }

    function testInitialize() external {
        vm.expectRevert("ONLY GOV");
        vm.prank(user);
        jDola.initialize(1, 1);

        vm.startPrank(gov);
        vm.expectRevert("initial reserves cant be 0");
        jDola.initialize(1, 0);

        vm.expectRevert("initial reserves cant be 0");
        jDola.initialize(0, 1);

        vm.expectRevert("K factor too high");
        jDola.initialize(2 ** (192/2), 2 ** (192/2));

        //Initialization using realistic auction depth
        uint initDbrReserve = 1_000_000 * 1e18;
        uint initDolaReserve = 100_000 * 1e18;
        jDola.initialize(initDbrReserve, initDolaReserve);
        (uint dolaReserve, uint dbrReserve) = jDola.getReserves();
        vm.assertNotEq(jDola.lastUpdate(), 0, "lastUpdate didn't update");
        vm.assertEq(jDola.dolaReserve(), initDolaReserve, "Cached dola reserve not equal initial dola reserves");
        vm.assertEq(jDola.dbrReserve(), initDbrReserve, "Cached dbr reserve not equal initial dbr reserves");
        vm.assertEq(dolaReserve, initDolaReserve, "Dynamic dola reserves not equal initial dola reserves");
        vm.assertEq(dbrReserve, initDbrReserve, "Dynamic dbr reserves not equal initial dbr reserves");
    }

    function testTotalAssets() external {
        vm.assertEq(jDola.totalAssets(), 0, "Total assets not 0 at deployment");
        
        uint depositAmount = jDola.MIN_ASSETS();
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);

        vm.assertEq(jDola.totalAssets(), depositAmount, "total assets not equal deposit amount");
        asset.mint(user, depositAmount);
        asset.approve(address(jDola), depositAmount);
        jDola.donate(depositAmount);
        
        vm.assertEq(jDola.totalAssets(), depositAmount, "total assets not equal deposit amount");
        
        vm.warp(block.timestamp + 7 days);
        vm.assertEq(jDola.totalAssets(), depositAmount, "total assets not equal deposit amount");

        vm.warp(block.timestamp + 1 days);
        vm.assertApproxEqAbs(jDola.totalAssets(), depositAmount + depositAmount / 7, 1, "total assets did not increment properly after 1 day");
        
        vm.warp(block.timestamp + 1 days);
        vm.assertApproxEqAbs(jDola.totalAssets(), depositAmount + 2 * depositAmount / 7, 1, "total assets did not increment properly after 2 days");

        vm.warp(block.timestamp + 4 days);
        vm.assertApproxEqAbs(jDola.totalAssets(), depositAmount + 6 * depositAmount / 7, 1, "total assets did not increment properly after 6 days");

        vm.warp(block.timestamp + 1 days);
        vm.assertApproxEqAbs(jDola.totalAssets(), 2 * depositAmount, 1, "total assets did not fully increment after 7 days");

        vm.warp(block.timestamp + 1 days);
        vm.assertEq(jDola.totalAssets(), 2 * depositAmount, "total assets did not stop incrementing");

        redeem(jDola.balanceOf(user), user);
        vm.assertEq(asset.balanceOf(user), depositAmount * 2);
    }

    function testBuyDbr(uint dolaIn, uint dbrOut) external {
        dolaIn = dolaIn % 1_000 * 1e18;
        dbrOut = dbrOut % 1_000 * 1e18;
        uint depositAmount = jDola.MIN_ASSETS();
        asset.mint(user, depositAmount);
        
        vm.prank(gov);
        jDola.initialize(1_000 * 1e18, 1_000 * 1e18);

        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        asset.mint(user, dolaIn);
        asset.approve(address(jDola), dolaIn);
        
        (uint dolaReserve, uint dbrReserve) = jDola.getReserves();
        uint k = dolaReserve * dbrReserve;
        //If new k > old k, we expect failure
        if((dolaReserve + dolaIn) * (dbrReserve - dbrOut) < k){
            vm.expectRevert();
            jDola.buyDbr(dolaIn, dbrOut, user);
            return;
        }
        uint prevAssets = jDola.totalAssets();
        jDola.buyDbr(dolaIn, dbrOut, user);
        (uint newDolaReserve, uint newDbrReserve) = jDola.getReserves();
        vm.assertGe(newDolaReserve * newDbrReserve, k, "Violated K invariant");
        vm.assertEq(dolaReserve + dolaIn, newDolaReserve, "Dola reserve didn't increase by dolaIn");
        vm.assertEq(dbrReserve - dbrOut, newDbrReserve,  "Dbr reserve didn't decrease by dbrOut");
        vm.assertEq(dbr.balanceOf(user), dbrOut, "User didn't receive expected DBR");
        vm.assertEq(asset.balanceOf(user), 0, "User didn't send DOLA amount");
        vm.assertEq(asset.balanceOf(address(jDola)), prevAssets + dolaIn, "Contract didn't receive dola");
        vm.assertEq(jDola.totalAssets(), prevAssets, "Assets increased prematurely");
        vm.warp(block.timestamp + 14 days);
        vm.assertEq(jDola.totalAssets(), prevAssets + dolaIn, "Asset didnt increase correctly after 2 weeks");
    }

    function testDonate(uint donationAmount) external {
        donationAmount = bound(donationAmount, 0, type(uint128).max);
        asset.mint(user, donationAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), donationAmount);
        vm.assertEq(0, jDola.totalAssets(), "Not zero assets");
        
        uint initialDonation = donationAmount / 2;
        jDola.donate(initialDonation);

        vm.assertEq(donationAmount - initialDonation, asset.balanceOf(user), "User didn't send half of donation amount");
        vm.assertEq(asset.balanceOf(address(jDola)), initialDonation, "jDola didn't receive half of donation amount");

        jDola.donate(donationAmount - initialDonation);
        vm.assertEq(0, asset.balanceOf(user), "User didn't send full donation amount");
        vm.assertEq(asset.balanceOf(address(jDola)), donationAmount, "jDola didn't receive full donation amount");
        vm.assertEq(jDola.totalAssets(), 0, "jDola accounted for assets too soon");

        vm.warp(block.timestamp + 14 days);
        if(donationAmount >= jDola.MAX_ASSETS()){
            vm.assertEq(jDola.totalAssets(), jDola.MAX_ASSETS(), "jDola at max assets");
        } else {
            vm.assertEq(jDola.totalAssets(), donationAmount, "jDola accounted for assets too soon");
        }
    }

    function testSlash() external {
        uint depositAmount = jDola.MIN_ASSETS() * 2;
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        vm.stopPrank();
 
        vm.expectRevert("ONLY SLASHING MODULE");
        vm.prank(slashingModule);
        jDola.slash(1e18);

        vm.prank(gov);
        jDola.setSlashingModule(slashingModule, true);

        uint assets = jDola.totalAssets();
        vm.prank(slashingModule);
        uint amountSlashed = jDola.slash(depositAmount);
        vm.assertEq(amountSlashed, assets - jDola.MIN_ASSETS(), "Assets slashed = total assets - min assets");
        vm.assertEq(jDola.totalAssets(), jDola.MIN_ASSETS(), "Not min assets left");
        vm.assertEq(asset.balanceOf(slashingModule), amountSlashed, "Slashing module didnt receive amount slashed");

        vm.prank(slashingModule);
        vm.expectRevert("Zero slash");
        jDola.slash(depositAmount);
    }

    function testSetDbrReserve() external {
        uint initDbrReserve = 1_000_000 * 1e18;
        uint initDolaReserve = 100_000 * 1e18;
        vm.prank(gov);
        jDola.initialize(initDbrReserve, initDolaReserve);
        
        vm.expectRevert("ONLY GOV");
        jDola.setDbrReserve(1);

        vm.prank(gov);
        vm.expectRevert("dbr reserve cant be 0");
        jDola.setDbrReserve(0);

        vm.prank(gov);
        vm.expectRevert("dbr reserves can't exceed 2**112");
        jDola.setDbrReserve(2**112 + 1);

        vm.prank(gov);
        jDola.setDbrReserve(initDbrReserve * 10);
        (uint dolaReserve, uint dbrReserve) = jDola.getReserves();
        vm.assertEq(dbrReserve, initDbrReserve * 10, "dbr reserve didnt increase 10x");
        vm.assertEq(dolaReserve, initDolaReserve * 10, "dola reserve didnt increase 10x");
    }

    function testSetDolaReserve() external {
        uint initDbrReserve = 1_000_000 * 1e18;
        uint initDolaReserve = 100_000 * 1e18;
        vm.prank(gov);
        jDola.initialize(initDbrReserve, initDolaReserve);
        
        vm.expectRevert("ONLY GOV");
        jDola.setDolaReserve(1);

        vm.prank(gov);
        vm.expectRevert("dola reserve cant be 0");
        jDola.setDolaReserve(0);

        vm.prank(gov);
        vm.expectRevert("dola reserves can't exceed 2**112");
        jDola.setDolaReserve(2**112 + 1);

        vm.prank(gov);
        jDola.setDolaReserve(initDolaReserve * 10);
        (uint dolaReserve, uint dbrReserve) = jDola.getReserves();
        vm.assertEq(dbrReserve, initDbrReserve * 10, "dbr reserve didnt increase 10x");
        vm.assertEq(dolaReserve, initDolaReserve * 10, "dola reserve didnt increase 10x");
    }

    function testSetMaxYearlyRewardBudget() external {
        uint initDbrReserve = 1_000_000 * 1e18;
        uint initDolaReserve = 100_000 * 1e18;
        vm.prank(gov);
        jDola.initialize(initDbrReserve, initDolaReserve);
 
        vm.expectRevert("ONLY GOV");
        jDola.setMaxYearlyRewardBudget(1_000_000 * 1e18);

        vm.prank(gov);
        jDola.setMaxYearlyRewardBudget(1_000_000 * 1e18);
        vm.assertEq(jDola.maxYearlyRewardBudget(), 1_000_000 * 1e18);

        vm.startPrank(operator);
        jDola.setYearlyRewardBudget(jDola.maxYearlyRewardBudget());
        vm.stopPrank();

        vm.prank(gov);
        jDola.setMaxYearlyRewardBudget(1e18);
        vm.assertEq(jDola.yearlyRewardBudget(), 1e18, "yearly reward budget wasnt lowered to max");
    }

    function testSetYearlyRewardBudget() external {
        uint initDbrReserve = 1_000_000 * 1e18;
        uint initDolaReserve = 100_000 * 1e18;
        vm.prank(gov);
        jDola.initialize(initDbrReserve, initDolaReserve);
 
        vm.expectRevert("ONLY OPERATOR");
        jDola.setYearlyRewardBudget(1e18);

        vm.expectRevert("REWARD BUDGET ABOVE MAX");
        vm.prank(operator);
        jDola.setYearlyRewardBudget(1e18);

        vm.prank(gov);
        jDola.setMaxYearlyRewardBudget(1e18);
        vm.prank(operator);
        jDola.setYearlyRewardBudget(1e18);

        vm.assertEq(jDola.yearlyRewardBudget(), 1e18);
    }

    function testSetSlashingModule() external {
        vm.expectRevert("ONLY GOV");
        jDola.setSlashingModule(user, true);

        vm.prank(gov);
        jDola.setSlashingModule(user, true);
        vm.assertEq(jDola.slashingModules(user), true, "user not slashing module");

        vm.prank(gov);
        jDola.setSlashingModule(user, false);
        vm.assertEq(jDola.slashingModules(user), false, "user still slashing module");
    }

    function testSetOperator() external {
        vm.expectRevert("ONLY GOV");
        jDola.setOperator(user);

        vm.prank(gov);
        jDola.setOperator(user);
        vm.assertEq(jDola.operator(), user, "user not operator");
    }

    function testChangeGov() external {
        vm.expectRevert("ONLY GOV");
        jDola.setPendingGov(user);

        vm.prank(gov);
        jDola.setPendingGov(user);
        assertEq(jDola.pendingGov(), user, "user not pending gov");

        vm.expectRevert("ONLY PENDINGGOV");
        jDola.acceptGov();

        vm.prank(user);
        jDola.acceptGov();
        assertEq(jDola.gov(), user, "user not gov");
        assertEq(jDola.pendingGov(), address(0), "pending gov not address(0)");
    }


    function redeem(uint amount, address redeemer) internal {
        jDola.approve(address(withdrawalEscrow), amount);
        withdrawalEscrow.queueWithdrawal(amount, MAX_WITHDRAWAL_DELAY);
        (uint start,) = withdrawalEscrow.exitWindows(redeemer);
        vm.warp(start);
        withdrawalEscrow.completeWithdraw();
    }
}
