pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {LinearInterpolationDelayModel} from "src/LinearInterpolationDelayModel.sol";

contract LinearInterpolationDelayModelTest is Test{

    LinearInterpolationDelayModel linearDelayModel;
    address gov = address(0xA);

    function setUp() external{
       linearDelayModel = new LinearInterpolationDelayModel(1 days, 30 days, 5000, gov);
    }

    function test_getWithdrawDelay(uint totalSupply, uint totalWithdrawing) external {
        totalSupply = bound(totalSupply, 1, 2 ** 128 - 1);
        totalWithdrawing = bound(totalWithdrawing, 1, 2 ** 128 - 1);
        if(totalWithdrawing >= totalSupply * linearDelayModel.maxDelayThresholdBps() / 10_000){
            assertEq(linearDelayModel.maxDelay(), linearDelayModel.getWithdrawDelay(totalSupply, totalWithdrawing, address(0)), "Withdrawal delay not max delay");
        } else {
            uint maxDelayThreshold = totalSupply * linearDelayModel.maxDelayThresholdBps() / 10_000;
            uint expectedDelay = (linearDelayModel.minDelay() * (maxDelayThreshold - totalWithdrawing) + linearDelayModel.maxDelay() * totalWithdrawing) / maxDelayThreshold;
            assertEq(expectedDelay, linearDelayModel.getWithdrawDelay(totalSupply, totalWithdrawing, address(0)), "Withdrawal delay not what's expected");
        }
    }

    function test_setMinDelay(uint minDelay) external {
        minDelay = bound(minDelay, 0, linearDelayModel.maxDelay() * 2);
        
        vm.expectRevert("Only gov");
        linearDelayModel.setMinDelay(uint96(minDelay));

        if(minDelay > linearDelayModel.maxDelay()){
            vm.prank(gov);
            vm.expectRevert("min delay > max delay");
            linearDelayModel.setMinDelay(uint96(minDelay));
        } else {
            vm.prank(gov);
            linearDelayModel.setMinDelay(uint96(minDelay));
            assertEq(linearDelayModel.minDelay(), minDelay, "Min delay not properly set");
        }
    }

    function test_setMaxDelay(uint maxDelay) external {
        maxDelay = bound(maxDelay, 0, linearDelayModel.minDelay() * 2);
        
        vm.expectRevert("Only gov");
        linearDelayModel.setMaxDelay(uint96(maxDelay));

        if(maxDelay < linearDelayModel.minDelay()){
            vm.prank(gov);
            vm.expectRevert("max delay < min delay");
            linearDelayModel.setMaxDelay(uint96(maxDelay));
        } else {
            vm.prank(gov);
            linearDelayModel.setMaxDelay(uint96(maxDelay));
            assertEq(linearDelayModel.maxDelay(), maxDelay, "Min delay not properly set");
        }
    }

    function test_setMaxDelayThresholdBps(uint maxDelayThresholdBps) external {
        maxDelayThresholdBps = bound(maxDelayThresholdBps, 0, 10000 * 2);
        
        vm.expectRevert("Only gov");
        linearDelayModel.setMaxDelayThresholdBps(uint16(maxDelayThresholdBps));

        if(maxDelayThresholdBps < linearDelayModel.minDelay()){
            vm.prank(gov);
            vm.expectRevert("max delay < min delay");
            linearDelayModel.setMaxDelay(uint16(maxDelayThresholdBps));
        } else {
            vm.prank(gov);
            linearDelayModel.setMaxDelay(uint16(maxDelayThresholdBps));
            assertEq(linearDelayModel.maxDelayThresholdBps(), maxDelayThresholdBps, "Min delay not properly set");
        }
    }

    function test_setPendingGov() external {
        vm.expectRevert("Only gov");
        linearDelayModel.setPendingGov(address(this));

        vm.prank(gov);
        linearDelayModel.setPendingGov(address(this));
        assertEq(linearDelayModel.pendingGov(), address(this));
    }

    function test_acceptGov() external {
        vm.expectRevert("Only gov");
        linearDelayModel.setPendingGov(address(0xb));

        vm.prank(gov);
        linearDelayModel.setPendingGov(address(0xb));
        
        vm.expectRevert("Only pending gov");
        linearDelayModel.acceptGov();

    }
}
