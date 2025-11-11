pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC4626.sol";
import {LinearInterpolationDelayModel} from "../../src/LinearInterpolationDelayModel.sol";
import {WithdrawalEscrow} from "../../src/WithdrawalEscrow.sol";
import {JDola} from "../../src/jDola.sol";
import {MockERC20} from "./MockERC20.sol";

contract ProtocolTest is Test {
    LinearInterpolationDelayModel linearInterpolationDelayModel;
    WithdrawalEscrow withdrawalEscrow;
    JDola jDola;
    MockERC20 dbrToken;
    MockERC20 dolaToken;

    address gov = makeAddr("gov");
    address newGov = makeAddr("newGov");
    address operator = makeAddr("operator");
    address user = makeAddr("user");

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

        dbrToken = new MockERC20("DBR", "DBR");
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

        vm.prank(gov);
        jDola.initialize(
            100 ether, // _dbrReserve
            100 ether // _dolaReserve
        );

        dolaToken.mint(user, 1000 ether);

        vm.startPrank(user);
        dolaToken.approve(address(jDola), type(uint256).max);
        vm.stopPrank();
    }

    function testJDola() public {

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
}
