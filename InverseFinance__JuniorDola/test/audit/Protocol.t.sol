pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC4626.sol";
import {FiRMSlashingModule} from "../../src/FiRMSlashingModule.sol";
import {LinearInterpolationDelayModel} from "../../src/LinearInterpolationDelayModel.sol";
import {WithdrawalEscrow} from "../../src/WithdrawalEscrow.sol";
import {JDola} from "../../src/jDola.sol";
import {MockDBR} from "./MockDBR.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockMarket} from "./MockMarket.sol";

contract ProtocolTest is Test {
    LinearInterpolationDelayModel linearInterpolationDelayModel;
    WithdrawalEscrow withdrawalEscrow;
    JDola jDola;
    FiRMSlashingModule firmSlashingModule;
    MockDBR dbrToken;
    MockERC20 dolaToken;
    MockMarket mockMarket;

    address gov = makeAddr("gov");
    address newGov = makeAddr("newGov");
    address operator = makeAddr("operator");
    address slasher = makeAddr("slasher");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    function setUp() public {
        linearInterpolationDelayModel = new LinearInterpolationDelayModel(
            1 days, // _minDelay 
            60 days, // _maxDelay
            10_000, // _maxDelayThresholdBps (sharpens the curve)
            gov
        );

        withdrawalEscrow = new WithdrawalEscrow(
            gov,
            address(linearInterpolationDelayModel)
        );

        dbrToken = new MockDBR("DBR", "DBR");
        dolaToken = new MockERC20("DOLA", "DOLA");

        jDola = new JDola(
            gov,
            operator,
            address(withdrawalEscrow),
            address(dbrToken),
            dolaToken,
            "DOLA_VAULT", // name
            "DOLA_VAULT" // symbol
        );

        firmSlashingModule = new FiRMSlashingModule(
            address(jDola),
            address(dbrToken),
            address(dolaToken),
            gov
        );

        vm.startPrank(gov);
        jDola.initialize(
            1_000_000_000_000 ether, // _dbrReserve
            0.000000001 ether // _dolaReserve
        );
        jDola.setSlashingModule(address(firmSlashingModule), true);
        withdrawalEscrow.initialize(address(jDola));
        vm.stopPrank();

        mockMarket = new MockMarket(address(dbrToken), address(dolaToken));

        dolaToken.mint(user, 1000 ether);
        dolaToken.mint(user2, 1000 ether);
        dolaToken.mint(user3, 1000 ether);

        vm.startPrank(user);
        dolaToken.approve(address(jDola), type(uint256).max);
        jDola.approve(address(withdrawalEscrow), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        dolaToken.approve(address(jDola), type(uint256).max);
        jDola.approve(address(withdrawalEscrow), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        dolaToken.approve(address(jDola), type(uint256).max);
        jDola.approve(address(withdrawalEscrow), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * Scenario:
     * 1. User deposits 1 DOLA
     * 2. User queues 0.5 DOLA for withdrawal
     * 3. On completing withdrawal tx reverts with "Assets below MIN_ASSETS"
     */
    function test_exceedMinAssets_fail() public {
        skip(7 days);

        vm.prank(user);
        jDola.deposit(1 ether, user);

        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(0.5 ether, type(uint256).max);

        skip(31 days);

        vm.prank(user);
        vm.expectRevert("Assets below MIN_ASSETS");
        withdrawalEscrow.completeWithdraw();
    }

    /**
     * Scenario:
     * 1. User deposits 1 DOLA
     * 2. User queues 1 DOLA for withdrawal
     * 3. Complete withdrawal succeeds leading to assets < MIN_ASSETS
     */
    function test_exceedMinAssets_success() public {
        skip(7 days);

        vm.prank(user);
        jDola.deposit(1 ether, user);

        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(1 ether, type(uint256).max);

        skip(60 days);

        vm.prank(user);
        withdrawalEscrow.completeWithdraw();
    }

    /**
     * Scenario:
     * 1. Government sets DBR reserve to 100 ether
     * 2. User mints 100 DBR for 0 DOLA
     */
    function test_kInvariantBroken() public {        
        vm.prank(gov);
        jDola.setDbrReserve(100 ether);

        console.log("===before===");
        debugReserves(); 
        debugBalance(address(dbrToken), user, "DBR balance (user)");

        // buyDbr
        vm.prank(user);
        jDola.buyDbr(
            0, // exactDolaIn
            100 ether, // exactDbrOut
            user
        );

        console.log("===after===");
        debugReserves();
        debugBalance(address(dbrToken), user, "DBR balance (user)");

        // Output:
        // ===before===
        // ===reserves===
        // DOLA reserve:  0
        // DBR reserve :  100000000000000000000
        // DBR balance (user) 0e0
        // ===after===
        // ===reserves===
        // DOLA reserve:  0
        // DBR reserve :  0
        // DBR balance (user) 1e20
    }

    /**
     * 1. User deposits 100 DOLA
     * 2. User2 deposits 100 DOLA
     * 3. User3 buys DBR for 15 DOLA
     * 4. User withdraws 100 DOLA shares and gets 7.5 DOLA
     * 5. User2 withdraws 100 DOLA shares and gets 7.5 DOLA
     */
    function testScenario1() public {
        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(100); // 1%

        // Scenario
        skip(7 days);

        debugBalance(address(dolaToken), user, "DOLA balance (user)");
        debugBalance(address(dolaToken), user2, "DOLA balance (user2)");

        vm.prank(user);
        jDola.deposit(100 ether, user);

        vm.prank(user2);
        jDola.deposit(100 ether, user2);

        vm.prank(user3);
        jDola.buyDbr(
            15 ether, // exactDolaIn
            10 ether, // exactDbrOut
            user3
        );

        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(100 ether, type(uint256).max);

        vm.prank(user2);
        withdrawalEscrow.queueWithdrawal(100 ether, type(uint256).max);

        skip(31 days);

        vm.prank(user);
        withdrawalEscrow.completeWithdraw();

        skip(29 days);

        vm.prank(user2);
        withdrawalEscrow.completeWithdraw();

        debugBalance(address(dolaToken), user, "DOLA balance (user)");
        debugBalance(address(dolaToken), user2, "DOLA balance (user2)");
    }

    function testProtocol() public {
        //=========
        // JDola
        //=========
        
        skip(7 days);

        // // donate
        // vm.prank(user);
        // jDola.donate(1000 ether);

        // // buyDbr
        // vm.prank(user);
        // jDola.buyDbr(
        //     15 ether, // exactDolaIn
        //     10 ether, // exactDbrOut
        //     user
        // );

        // // slash
        // skip(14 days);
        // vm.prank(slasher);
        // jDola.slash(1000 ether);

        // // setMaxYearlyRewardBudget
        // vm.prank(gov);
        // jDola.setMaxYearlyRewardBudget(10_000 ether);

        // // setYearlyRewardBudget
        // vm.prank(operator);
        // jDola.setYearlyRewardBudget(10_000 ether);

        //======================
        // FiRMSlashingModule
        //======================

        // vm.prank(gov);
        // firmSlashingModule.allowMarket(address(mockMarket));

        // skip(14 days);

        // mockMarket.setCollateral(user2, 100 ether);
        // mockMarket.setDebt(user2, 200 ether);
        // mockMarket.setCollateralPrice(1 ether);

        // // slash
        // firmSlashingModule.slash(address(mockMarket), user2);

        //====================
        // WithdrawalEscrow
        //====================

        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(100); // 1%

        vm.prank(user);
        jDola.mint(100 ether, user);

        // queueWithdrawal
        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(100 ether, type(uint256).max);

        skip(60 days);

        // cancelWithdrawal
        vm.prank(user);
        withdrawalEscrow.cancelWithdrawal();

        // completeWithdraw
        vm.prank(user);
        withdrawalEscrow.completeWithdraw();

        // debugBalance(address(dolaToken), user, "DOLA balance (user)");
    }

    function testLinearInterpolationDelayModel() public {
        // getWithdrawDelay
        // The more you withdraw compared to total supply the greater the delay
        // Ex: On withdrawing 100 of 1000 total supply withdraw delay is 6 days (10% of max 60 days delay)
        // uint result = linearInterpolationDelayModel.getWithdrawDelay(1000, 500, address(0));

        // vm.prank(gov);
        // linearInterpolationDelayModel.setPendingGov(newGov);

        // vm.prank(newGov);
        // linearInterpolationDelayModel.acceptGov();

        // vm.prank(newGov);
        // linearInterpolationDelayModel.setMinDelay(0);

        // vm.prank(newGov);
        // linearInterpolationDelayModel.setPendingGov(gov);
    }

    function debugBalance(address token, address target, string memory memo) public {
        console.log("%s %e", memo, ERC20(token).balanceOf(target));
    }

    function debugExitWindow(address user) public {
        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        console.log("===exit window===");
        console.log("start:", start / 1 days);
        console.log("end  :", end / 1 days);
    }

    function debugReserves() public {
        (uint dolaReserve, uint dbrReserve) = jDola.getReserves();
        console.log("===reserves===");
        console.log("DOLA reserve: ", dolaReserve);
        console.log("DBR reserve : ", dbrReserve);
    }
}
