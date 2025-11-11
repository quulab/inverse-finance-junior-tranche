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

    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }

}

contract MockDelayModel is IWithdrawDelayModel{
    bool public revertOnNext;
    uint public response;

    function getWithdrawDelay(uint totalSupply, uint totalWithdrawing, address withdrawer) external returns(uint){
        if(revertOnNext) revert();
        return response;
    }

    function setResponse(uint _response) external {
        response = _response;
    }

    function toggleRevertOnNext() external {
        revertOnNext = !revertOnNext;
    }
    
}

contract WithdrawalEscrowTest is Test{

    uint public MAX_WITHDRAWAL_DELAY = 60 days;
    WithdrawalEscrow withdrawalEscrow;
    IWithdrawDelayModel withdrawDelayModel;
    address gov = address(0xA);
    address operator = address(0xB);
    address user = address(0xC);
    MintableERC20 asset;
    MintableERC20 dbr;
    JDola jDola;

    function setUp() external{
       withdrawDelayModel = IWithdrawDelayModel(address(new LinearInterpolationDelayModel(1 days, 30 days, 5000, gov)));
       withdrawalEscrow = new WithdrawalEscrow(gov, address(withdrawDelayModel));
       asset = new MintableERC20("test DOLA", "DOLA");
       dbr = new MintableERC20("test DBR", "DBR");
       jDola = new JDola(gov, operator, address(withdrawalEscrow), address(dbr), asset, "testJDOLA", "TJD");
       vm.prank(gov);
       withdrawalEscrow.initialize(address(jDola));
       vm.warp(21 days);
    }

    function test_getWithdrawDelay(uint totalSupply, uint totalWithdrawing) external {
        totalSupply = bound(totalSupply, 0, type(uint128).max);
        totalWithdrawing = bound(totalWithdrawing, 0, totalSupply);
        assertEq(
            withdrawalEscrow.getWithdrawDelay(totalSupply, totalWithdrawing, msg.sender),
            withdrawDelayModel.getWithdrawDelay(totalSupply, totalWithdrawing, msg.sender)
        );
    }

    function test_queueWithdrawal() external {
        uint depositAmount = 1e20;
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        assertEq(asset.balanceOf(user), depositAmount);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));

        uint bal = jDola.balanceOf(user);
        uint expectedDelay = withdrawalEscrow.getWithdrawDelay(bal, bal, user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), 0, "Unexpected user collateral");
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), bal, "Withdrawal escrow didn't receive jdola shares");
        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), bal, "Unexpected withdraw amount");
    }

    function test_queueWithdrawal_withWithdrawFee() external {
        uint depositAmount = 1e20;
        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(100);
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        assertEq(asset.balanceOf(user), depositAmount);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));

        uint bal = jDola.balanceOf(user);
        uint expectedDelay = withdrawalEscrow.getWithdrawDelay(bal, bal, user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), 0, "Unexpected user collateral");
        uint expectedWithdrawAmount = bal - bal * withdrawalEscrow.withdrawFeeBps() / 10000;
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), expectedWithdrawAmount, "Withdrawal escrow didn't receive jdola shares");
        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), expectedWithdrawAmount, "Unexpected withdraw amount");
    }

    function test_queueWithdrawal_multipleWithdrawalsBeforeExitWindow() external {
        uint depositAmount = 1e20;
        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(100);
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        assertEq(asset.balanceOf(user), depositAmount);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));

        uint bal = jDola.balanceOf(user) / 2;
        uint expectedDelay = withdrawalEscrow.getWithdrawDelay(bal, bal, user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), depositAmount / 2, "Unexpected user collateral");
        uint expectedWithdrawAmount = bal - bal * withdrawalEscrow.withdrawFeeBps() / 10000;
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), expectedWithdrawAmount, "Withdrawal escrow didn't receive jdola shares");
        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), expectedWithdrawAmount, "Unexpected withdraw amount");

        expectedDelay = withdrawalEscrow.getWithdrawDelay(bal * 2, bal * 2, user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), 0, "Unexpected user collateral");
        expectedWithdrawAmount = bal * 2 - bal * 2 * withdrawalEscrow.withdrawFeeBps() / 10000;
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), expectedWithdrawAmount, "Withdrawal escrow didn't receive jdola shares");
        (start, end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), expectedWithdrawAmount, "Unexpected withdraw amount");
    }

    function test_queueWithdrawal_renewWithdrawalAfterExitWindow() external {
        uint depositAmount = 1e20;
        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(100);
        asset.mint(user, depositAmount);
        vm.startPrank(user);
        assertEq(asset.balanceOf(user), depositAmount);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));

        uint bal = jDola.balanceOf(user);
        uint expectedDelay = withdrawalEscrow.getWithdrawDelay(bal, bal, user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), 0, "Unexpected user collateral");
        uint expectedWithdrawAmount = bal - bal * withdrawalEscrow.withdrawFeeBps() / 10000;
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), expectedWithdrawAmount, "Withdrawal escrow didn't receive jdola shares");
        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), expectedWithdrawAmount, "Unexpected withdraw amount");

        vm.warp(end + 1);
        expectedDelay = withdrawalEscrow.getWithdrawDelay(bal, bal, user);
        withdrawalEscrow.queueWithdrawal(0, MAX_WITHDRAWAL_DELAY);

        assertEq(jDola.balanceOf(user), 0, "Unexpected user collateral");
        expectedWithdrawAmount = expectedWithdrawAmount - expectedWithdrawAmount * withdrawalEscrow.withdrawFeeBps() / 10000;
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), expectedWithdrawAmount, "Withdrawal escrow didn't receive jdola shares");
        (start, end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, block.timestamp + expectedDelay, "Unexpected withdraw delay");
        assertEq(end, block.timestamp + expectedDelay + withdrawalEscrow.exitWindow(), "Unexpected exit window end");
        assertEq(withdrawalEscrow.withdrawAmounts(user), expectedWithdrawAmount, "Unexpected withdraw amount");
    }

    function test_completeWithdrawal_withdrawWithinExitWindow() external {
        uint depositAmount = 1e20;
        asset.mint(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));
        vm.stopPrank();

        uint bal = jDola.balanceOf(user);
        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        vm.warp(start);

        vm.prank(user);
        withdrawalEscrow.completeWithdraw();
        assertEq(asset.balanceOf(user), depositAmount, "Didn't receive expected amount");
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), 0);
        assertEq(withdrawalEscrow.withdrawAmounts(user), 0, "User didn't fully withdraw");
        (start, end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, 0, "ExitWindow start not 0 after completion");
        assertEq(end, 0, "ExitWindow end not 0 after completion");
    }

    function test_completeWithdrawal_failOutsideExitWindow() external {
        uint depositAmount = 1e20;
        asset.mint(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));
        vm.stopPrank();

        uint bal = jDola.balanceOf(user);
        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        vm.warp(start-1);
        
        vm.expectRevert("Exit window hasn't started");
        vm.prank(user);
        withdrawalEscrow.completeWithdraw();
        
        vm.warp(end+1);
        vm.expectRevert("Exit window has ended");
        vm.prank(user);
        withdrawalEscrow.completeWithdraw();
    }

    function test_cancelWithdrawal() external {
        uint depositAmount = 1e20;
        asset.mint(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);
        vm.startPrank(user);
        asset.approve(address(jDola), depositAmount);
        jDola.deposit(depositAmount, user);
        jDola.approve(address(withdrawalEscrow), jDola.balanceOf(user));
        vm.stopPrank();

        uint bal = jDola.balanceOf(user);
        vm.prank(user);
        withdrawalEscrow.queueWithdrawal(bal, MAX_WITHDRAWAL_DELAY);

        (uint128 start, uint128 end) = withdrawalEscrow.exitWindows(user);
        vm.warp(start-1);
        
        vm.expectRevert("Cant cancel before exit window start");
        vm.prank(user);
        withdrawalEscrow.cancelWithdrawal();
        
        vm.warp(start+1);
        vm.prank(user);
        withdrawalEscrow.cancelWithdrawal();
        assertEq(jDola.balanceOf(user), depositAmount, "Didn't receive expected amount of jDOLA");
        assertEq(jDola.balanceOf(address(withdrawalEscrow)), 0);
        assertEq(withdrawalEscrow.withdrawAmounts(user), 0, "User didn't cancel withdrawal");
        (start, end) = withdrawalEscrow.exitWindows(user);
        assertEq(start, 0, "ExitWindow start not 0 after cancellation");
        assertEq(end, 0, "ExitWindow end not 0 after cancellation");
    }

    // Gov functions

    function test_setWithdrawDelayModel() external {
        address mockDelayModel = address(new MockDelayModel());
        vm.expectRevert("Only gov");
        withdrawalEscrow.setWithdrawDelayModel(mockDelayModel);

        vm.prank(gov);
        withdrawalEscrow.setWithdrawDelayModel(mockDelayModel);
        assertEq(address(withdrawalEscrow.withdrawDelayModel()), mockDelayModel);
    }

    function test_setWithdrawFee() external {
        vm.expectRevert("Only gov");
        withdrawalEscrow.setWithdrawFee(50);

        vm.expectRevert("Withdraw fee exceed 1%");
        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(101);

        vm.prank(gov);
        withdrawalEscrow.setWithdrawFee(99);

        assertEq(withdrawalEscrow.withdrawFeeBps(), 99);
    }

    function test_setExitWindow() external {
        uint minExitWindow = withdrawalEscrow.MIN_EXIT_WINDOW();
        uint maxExitWindow = withdrawalEscrow.MAX_EXIT_WINDOW();
        
        vm.expectRevert("Only gov");
        withdrawalEscrow.setExitWindow(minExitWindow + 1);

        vm.expectRevert("Exit window below min");
        vm.prank(gov);
        withdrawalEscrow.setExitWindow(minExitWindow - 1);

        vm.expectRevert("Exit window above max");
        vm.prank(gov);
        withdrawalEscrow.setExitWindow(maxExitWindow + 1);

        vm.prank(gov);
        withdrawalEscrow.setExitWindow(maxExitWindow - 1);

        assertEq(withdrawalEscrow.exitWindow(), maxExitWindow - 1);
    }

    function test_changeGov() external {
        vm.expectRevert("Only gov");
        withdrawalEscrow.setGov(user);

        vm.prank(gov);
        withdrawalEscrow.setGov(user);

        assertEq(withdrawalEscrow.pendingGov(), user);

        vm.expectRevert("Only pendingGov");
        withdrawalEscrow.acceptGov();

        vm.prank(user);
        withdrawalEscrow.acceptGov();

        assertEq(withdrawalEscrow.gov(), user);
        assertEq(withdrawalEscrow.pendingGov(), address(0));
    }

}
