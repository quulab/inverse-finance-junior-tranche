using JDola as jDola;
using MockERC20 as dolaToken;
using MockDBR as dbrToken;
using LinearInterpolationDelayModel as linearInterpolationDelayModel;

methods {
    // ERC20
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
}

definition SECONDS_IN_WEEK() returns uint256 = 604800;

function applySafeAssumptions(env e) {
    uint256 dolaReserve;
    uint256 dbrReserve;
    (dolaReserve, dbrReserve) = jDola.getReserves(e);

    require dolaReserve > 0 && dbrReserve > 0;
    require e.msg.sender != currentContract;
    require e.block.timestamp >= SECONDS_IN_WEEK();
    require withdrawFeeBps(e) <= 100; // 1%
}

//===========
// High
//===========

// Methods are called by expected roles
rule high_accessControl(method f) filtered {
    f -> f.selector != sig:initialize(address).selector
} {
    env e;
    calldataarg args;

    f(e, args);

    assert
        (
            f.selector == sig:setWithdrawDelayModel(address).selector ||
            f.selector == sig:setWithdrawFee(uint256).selector ||
            f.selector == sig:setExitWindow(uint256).selector ||
            f.selector == sig:setGov(address).selector
        )
        =>
        e.msg.sender == currentContract.gov;
}

//===========
// Unit
//===========

// `queueWithdrawal()` updates storage as expected
rule unit_queueWithdrawal_integrity() {
    env e;

    uint256 amount;
    uint256 maxWithdrawDelay;

    applySafeAssumptions(e);

    uint256 expectedFee = getFee(e, amount, e.msg.sender);

    uint256 userSharesBalanceBefore = jDola.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceBefore = jDola.balanceOf(e, currentContract);
    
    queueWithdrawal(e, amount, maxWithdrawDelay);

    uint256 userSharesBalanceAfter = jDola.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceAfter = jDola.balanceOf(e, currentContract);

    assert userSharesBalanceBefore == userSharesBalanceAfter + amount;
    assert 
        expectedFee > 0 && jDola.previewRedeem(e, expectedFee) > 0 
        =>
        contractSharesBalanceBefore == contractSharesBalanceAfter - (amount - expectedFee);
}

// `completeWithdraw()` updates storage as expected
rule unit_completeWithdraw_integrity() {
    env e;

    applySafeAssumptions(e);

    require e.msg.sender != jDola && e.msg.sender != dolaToken;

    uint256 withdrawAmountsBefore = withdrawAmounts(e, e.msg.sender);
    uint256 userDolaBalanceBefore = dolaToken.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceBefore = jDola.balanceOf(e, currentContract);
    uint256 expectedDolaAmountToBeRedeemed = jDola.previewRedeem(e, withdrawAmountsBefore);

    completeWithdraw(e);

    uint128 exitWindowStart;
    uint128 exitWindowEnd;
    (exitWindowStart, exitWindowEnd) = exitWindows(e, e.msg.sender);

    uint256 withdrawAmountsAfter = withdrawAmounts(e, e.msg.sender);
    uint256 userDolaBalanceAfter = dolaToken.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceAfter = jDola.balanceOf(e, currentContract);

    assert exitWindowStart == 0 && exitWindowEnd == 0;
    assert withdrawAmountsAfter == 0;
    assert require_uint256(userDolaBalanceBefore + expectedDolaAmountToBeRedeemed) == userDolaBalanceAfter;
    assert contractSharesBalanceBefore == require_uint256(contractSharesBalanceAfter + withdrawAmountsBefore);
}

// `completeWithdraw()` revets when expected
rule unit_completeWithdraw_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 currentWeek = require_uint256(e.block.timestamp / SECONDS_IN_WEEK());

    uint128 exitWindowStart;
    uint128 exitWindowEnd;
    (exitWindowStart, exitWindowEnd) = exitWindows(e, e.msg.sender);

    uint256 withdrawAmount = withdrawAmounts(e, e.msg.sender);
    uint256 redeemedAssetsAmount = jDola.previewRedeem(e, withdrawAmount);

    require jDola.totalSupply(e) >= withdrawAmount, "There're always available shares to withdraw";

    bool isEtherSent = e.msg.value > 0;
    bool hasWithdrawalStarted = e.block.timestamp >= exitWindowStart;
    bool hasWithdrawalEnded = e.block.timestamp > exitWindowEnd;
    bool isWithdrawAmountZero = withdrawAmounts(e, e.msg.sender) == 0;
    bool isRemainingLastRevenueOverflow = jDola.weeklyRevenue(e, require_uint256(currentWeek - 1)) * (SECONDS_IN_WEEK() - (e.block.timestamp % SECONDS_IN_WEEK())) / SECONDS_IN_WEEK() > max_uint256;
    bool hasVaultEnoughBalance = dolaToken.balanceOf(e, jDola) >= redeemedAssetsAmount;
    bool isMinAssetsLimitReached = (redeemedAssetsAmount + jDola.MIN_ASSETS(e)) > jDola.totalAssets(e) && (redeemedAssetsAmount != jDola.totalAssets(e));
    bool isMinSharesLimitReached = (jDola.totalSupply(e) - withdrawAmount < jDola.MIN_SHARES(e)) && (withdrawAmount != jDola.totalSupply(e));
    bool isRedeemedAssetsAmountZero = redeemedAssetsAmount == 0;
    bool hasContractEnoughShares = jDola.balanceOf(e, currentContract) >= withdrawAmount;

    bool isExpectedToRevert = 
        isEtherSent ||
        !hasWithdrawalStarted ||
        hasWithdrawalEnded ||
        isWithdrawAmountZero ||
        isRemainingLastRevenueOverflow ||
        !hasVaultEnoughBalance ||
        isMinAssetsLimitReached ||
        isRedeemedAssetsAmountZero ||
        !hasContractEnoughShares ||
        isMinSharesLimitReached;

    completeWithdraw@withrevert(e);

    assert lastReverted <=> isExpectedToRevert;
}

// `cancelWithdrawal()` updates storage as expected
rule unit_cancelWithdrawal_integrity() {
    env e;

    applySafeAssumptions(e);

    uint256 withdrawAmount = withdrawAmounts(e, e.msg.sender);

    uint256 userSharesBalanceBefore = jDola.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceBefore = jDola.balanceOf(e, currentContract);

    cancelWithdrawal(e);

    uint128 exitWindowStart;
    uint128 exitWindowEnd;
    (exitWindowStart, exitWindowEnd) = exitWindows(e, e.msg.sender);

    uint256 userSharesBalanceAfter = jDola.balanceOf(e, e.msg.sender);
    uint256 contractSharesBalanceAfter = jDola.balanceOf(e, currentContract);

    assert exitWindowStart == 0 && exitWindowEnd == 0;
    assert withdrawAmounts(e, e.msg.sender) == 0;
    assert require_uint256(userSharesBalanceBefore + withdrawAmount) == userSharesBalanceAfter;
    assert contractSharesBalanceBefore - withdrawAmount == contractSharesBalanceAfter;
}

// `cancelWithdrawal()` revets when expected
rule unit_cancelWithdrawal_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint128 exitWindowStart;
    uint128 exitWindowEnd;
    (exitWindowStart, exitWindowEnd) = exitWindows(e, e.msg.sender);

    uint256 withdrawAmount = withdrawAmounts(e, e.msg.sender);

    bool isEtherSent = e.msg.value > 0;
    bool isWithdrawAmountZero = withdrawAmount == 0;
    bool hasExitWindowStarted = exitWindowStart > e.block.timestamp;
    bool hasContractEnoughBalance = jDola.balanceOf(e, currentContract) >= withdrawAmount;

    bool isExpectedToRevert = 
        isEtherSent ||
        isWithdrawAmountZero ||
        hasExitWindowStarted ||
        !hasContractEnoughBalance;

    cancelWithdrawal@withrevert(e);

    assert lastReverted <=> isExpectedToRevert;
}

// `initialize()` reverts when expected
rule unit_initialize_revertConditions() {
    env e;

    address newVault;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isVaultInitialized = currentContract.vault != 0;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isVaultInitialized;

    initialize@withrevert(e, newVault);

    assert lastReverted <=> isExpectedToRevert;
}

// `setWithdrawDelayModel()` updates storage as expected
rule unit_setWithdrawDelayModel_integrity() {
    env e;

    address newWithdrawDelayModel;

    setWithdrawDelayModel(e, newWithdrawDelayModel);

    assert currentContract.withdrawDelayModel == newWithdrawDelayModel;
}

// `setWithdrawDelayModel()` reverts when expected
rule unit_setWithdrawDelayModel_revertConditions() {
    env e;

    address newWithdrawDelayModel;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setWithdrawDelayModel@withrevert(e, newWithdrawDelayModel);

    assert lastReverted <=> isExpectedToRevert;
}

// `setWithdrawFee()` updates storage as expected
rule unit_setWithdrawFee_integrity() {
    env e;

    uint256 withdrawFeeBps;

    setWithdrawFee(e, withdrawFeeBps);

    assert currentContract.withdrawFeeBps == withdrawFeeBps;
}

// `setWithdrawFee()` reverts when expected
rule unit_setWithdrawFee_revertConditions() {
    env e;

    uint256 withdrawFeeBps;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isWithdrawFeeBpsTooBig = withdrawFeeBps > 100;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isWithdrawFeeBpsTooBig;

    setWithdrawFee@withrevert(e, withdrawFeeBps);

    assert lastReverted <=> isExpectedToRevert;
}

// `setExitWindow()` updates storage as expected
rule unit_setExitWindow_integrity() {
    env e;

    uint256 newExitWindow;

    setExitWindow(e, newExitWindow);

    assert currentContract.exitWindow == newExitWindow;
}

// `setExitWindow()` reverts when expected
rule unit_setExitWindow_revertConditions() {
    env e;

    uint256 newExitWindow;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isExitWindowTooSmall = newExitWindow < MIN_EXIT_WINDOW(e);
    bool isExitWindowTooBig = newExitWindow > MAX_EXIT_WINDOW(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isExitWindowTooSmall ||
        isExitWindowTooBig;

    setExitWindow@withrevert(e, newExitWindow);

    assert lastReverted <=> isExpectedToRevert;
}

// `setGov()` updates storage as expected
rule unit_setGov_integrity() {
    env e;

    address newGov;

    setGov(e, newGov);

    assert currentContract.pendingGov == newGov;
}

// `setGov()` reverts when expected
rule unit_setGov_revertConditions() {
    env e;

    address newGov;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setGov@withrevert(e, newGov);

    assert lastReverted <=> isExpectedToRevert;
}

// `acceptGov()` updates storage as expected
rule unit_acceptGov_integrity() {
    env e;

    address pendingGov = currentContract.pendingGov;

    acceptGov(e);

    assert currentContract.gov == pendingGov;
    assert currentContract.pendingGov == 0;
}

// `acceptGov()` reverts when expected
rule unit_acceptGov_revertConditions() {
    env e;

    bool isEtherSent = e.msg.value > 0;
    bool isPendingGov = e.msg.sender == currentContract.pendingGov;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isPendingGov;

    acceptGov@withrevert(e);

    assert lastReverted <=> isExpectedToRevert;
}