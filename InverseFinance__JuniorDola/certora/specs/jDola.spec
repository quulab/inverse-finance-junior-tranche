using MockERC20 as dolaToken;
using MockDBR as dbrToken;

methods {
    // ERC20
    function _.transfer(address, uint256) external => DISPATCHER(true);
}

definition SECONDS_IN_WEEK() returns uint256 = 604800;

function applySafeAssumptions(env e) {
    uint256 dolaReserve;
    uint256 dbrReserve;
    (dolaReserve, dbrReserve) = getReserves(e);

    require dolaReserve > 0 && dbrReserve > 0;
    require e.msg.sender != currentContract;
    require e.block.timestamp >= SECONDS_IN_WEEK();
    require e.block.timestamp >= currentContract.lastUpdate;
}

//===========
// High
//===========

// K invariant always holds
rule high_kInvariantAlwaysHolds(method f) filtered {
    f -> 
        f.selector != sig:setDbrReserve(uint256).selector && 
        f.selector != sig:setDolaReserve(uint256).selector &&
        f.selector != sig:initialize(uint256,uint256).selector
} 
{
    env e;
    calldataarg args;

    applySafeAssumptions(e);

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);
    mathint K = dolaReserveBefore * dbrReserveBefore;

    f(e, args);

    uint256 dolaReserveAfter;
    uint256 dbrReserveAfter;
    (dolaReserveAfter, dbrReserveAfter) = getReserves(e);

    require dolaReserveAfter > 0 && dbrReserveAfter > 0;

    assert dolaReserveAfter * dbrReserveAfter >= K;
}

// Methods are called by expected roles
rule high_accessControl(method f) filtered {
    f -> f.selector != sig:initialize(uint256,uint256).selector
} {
    env e;
    calldataarg args;

    f(e, args);

    assert
        (
            f.selector == sig:setDbrReserve(uint256).selector ||
            f.selector == sig:setDolaReserve(uint256).selector ||
            f.selector == sig:setMaxYearlyRewardBudget(uint256).selector ||
            f.selector == sig:setSlashingModule(address,bool).selector ||
            f.selector == sig:setOperator(address).selector ||
            f.selector == sig:setPendingGov(address).selector ||
            f.selector == sig:sweep(address,uint256,address).selector
        )
        =>
        e.msg.sender == currentContract.gov;

    assert
        (
            f.selector == sig:setYearlyRewardBudget(uint256).selector
        )
        =>
        e.msg.sender == currentContract.gov ||
        e.msg.sender == currentContract.operator;
}

//===========
// Unit
//===========

// `initialize()` reverts when expected
rule unit_initialize_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 dbrReserve;
    uint256 dolaReserve;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isDbrReserveAlreadySet = currentContract.dbrReserve != 0;
    bool isDolaReserveAlreadySet = currentContract.dolaReserve != 0;
    bool isDbrReserveZero = dbrReserve == 0;
    bool isDolaReserveZero = dolaReserve == 0;
    bool isKTooHigh = dbrReserve * dolaReserve >= max_uint192;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isDbrReserveAlreadySet ||
        isDolaReserveAlreadySet ||
        isDbrReserveZero ||
        isDolaReserveZero;

    initialize@withrevert(e, dbrReserve, dolaReserve);

    assert lastReverted <=> isExpectedToRevert;
}

// `buyDbr()` updates storage as expected
rule unit_buyDbr_integrity() {
    env e;

    uint256 exactDolaIn; 
    uint256 exactDbrOut; 
    address receiver;

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;

    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);
    uint256 receiverDbrBalanceBefore = dbrToken.balanceOf(e, receiver);

    buyDbr(e, exactDolaIn, exactDbrOut, receiver);

    uint256 dolaReserveAfter = dolaReserve(e);
    uint256 dbrReserveAfter = dbrReserve(e);
    uint256 receiverDbrBalanceAfter = dbrToken.balanceOf(e, receiver);

    assert dolaReserveAfter == require_uint256(dolaReserveBefore + exactDolaIn);
    assert dbrReserveAfter == dbrReserveBefore - exactDbrOut;
    assert receiverDbrBalanceAfter == require_uint256(receiverDbrBalanceBefore + exactDbrOut);
}

// `buyDbr()` reverts when expected
rule unit_buyDbr_revertConditions() {
    env e;

    uint256 exactDolaIn; 
    uint256 exactDbrOut; 
    address receiver;

    applySafeAssumptions(e);

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);
    mathint K = require_uint256(dolaReserveBefore * dbrReserveBefore);

    bool isEtherSent = e.msg.value > 0;
    bool isReceiverZero = receiver == 0;
    bool isKInvariantBroken = (dolaReserveBefore + exactDolaIn) * (dbrReserveBefore - exactDbrOut) < K;
    bool isDolaReserveOverflow = dolaReserveBefore + exactDolaIn > max_uint256;
    bool isDbrReserveUnderflow = dbrReserveBefore - exactDbrOut < 0;
    bool isReserveOverflow = (dolaReserveBefore + exactDolaIn) * (dbrReserveBefore - exactDbrOut) > max_uint256;
    bool isEnoughAllowance = dolaToken.allowance(e, e.msg.sender, currentContract) >= exactDolaIn;
    bool isWeeklyRevenueOverflow = weeklyRevenue(e, require_uint256(e.block.timestamp / SECONDS_IN_WEEK())) + exactDolaIn > max_uint256;
    bool hasEnoughBalance = dolaToken.balanceOf(e, e.msg.sender) >= exactDolaIn;
    bool isDbrTotalSupplyOverflow = dbrToken.totalSupply(e) + exactDbrOut > max_uint256;

    bool isExpectedToRevert = 
        isEtherSent ||
        isReceiverZero ||
        isKInvariantBroken ||
        isDolaReserveOverflow ||
        isDbrReserveUnderflow ||
        isReserveOverflow ||
        !isEnoughAllowance ||
        isWeeklyRevenueOverflow ||
        !hasEnoughBalance ||
        isDbrTotalSupplyOverflow;

    buyDbr@withrevert(e, exactDolaIn, exactDbrOut, receiver);

    assert lastReverted <=> isExpectedToRevert;
}

// `donate()` updates storage as expected
rule unit_donate_integrity() {
    env e;

    uint256 amount;

    applySafeAssumptions(e);

    uint256 userBalanceBefore = dolaToken.balanceOf(e, e.msg.sender);
    uint256 weeklyRevenueBefore = weeklyRevenue(e, require_uint256(e.block.timestamp / 604800));

    donate(e, amount);

    uint256 userBalanceAfter = dolaToken.balanceOf(e, e.msg.sender);
    uint256 weeklyRevenueAfter = weeklyRevenue(e, require_uint256(e.block.timestamp / 604800));

    assert userBalanceBefore == userBalanceAfter + amount;
    assert weeklyRevenueBefore + amount == weeklyRevenueAfter;
}

// `donate()` reverts when expected
rule unit_donate_revertConditions() {
    env e;

    uint256 amount;

    applySafeAssumptions(e);

    bool isEtherSent = e.msg.value > 0;
    bool isEnoughAllowance = dolaToken.allowance(e, e.msg.sender, currentContract) >= amount;
    bool isWeeklyRevenueOverflow = weeklyRevenue(e, require_uint256(e.block.timestamp / SECONDS_IN_WEEK())) + amount > max_uint256;
    bool hasEnoughBalance = dolaToken.balanceOf(e, e.msg.sender) >= amount;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isEnoughAllowance ||
        isWeeklyRevenueOverflow ||
        !hasEnoughBalance;

    donate@withrevert(e, amount);

    assert lastReverted <=> isExpectedToRevert;
}

// `slash()` updates storage as expected
rule unit_slash_integrity() {
    env e;

    uint256 amount;

    applySafeAssumptions(e);

    require totalAssets(e) - 1000000000000000000 == amount, "There're always available assets";

    uint256 senderBalanceBefore = dolaToken.balanceOf(e, e.msg.sender);
    uint256 contractBalanceBefore = dolaToken.balanceOf(e, currentContract);

    slash(e, amount);

    uint256 senderBalanceAfter = dolaToken.balanceOf(e, e.msg.sender);
    uint256 contractBalanceAfter = dolaToken.balanceOf(e, currentContract);

    assert require_uint256(senderBalanceBefore + amount) == senderBalanceAfter;
    assert contractBalanceBefore == require_uint256(contractBalanceAfter + amount);
}

// `slash()` reverts when expected
rule unit_slash_revertConditions() {
    env e;

    uint256 amount;

    applySafeAssumptions(e);

    require totalAssets(e) - 1000000000000000000 == amount, "There're always available assets";

    bool isEtherSent = e.msg.value > 0;
    bool isSlashingModule = slashingModules(e, e.msg.sender);
    bool isZeroSlash = amount == 0;
    bool hasContractEnoughBalance = dolaToken.balanceOf(e, currentContract) >= amount;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isSlashingModule ||
        isZeroSlash ||
        !hasContractEnoughBalance;

    slash@withrevert(e, amount);

    assert lastReverted <=> isExpectedToRevert;
}

// `setDbrReserve()` updates storage as expected
rule unit_setDbrReserve_integrity() {
    env e;

    applySafeAssumptions(e);

    uint256 dbrReserve;

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);

    setDbrReserve(e, dbrReserve);

    assert currentContract.dolaReserve == dolaReserveBefore * dbrReserve / dbrReserveBefore;
    assert currentContract.dbrReserve == dbrReserve;
}

// `setDbrReserve()` reverts when expected
rule unit_setDbrReserve_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 dbrReserve;

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isDbrReserveZero = dbrReserve == 0;
    bool isDbrReserveTooBig = dbrReserve > max_uint112;
    bool isOverflow = dolaReserveBefore * dbrReserve > max_uint256;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isDbrReserveZero ||
        isDbrReserveTooBig ||
        isOverflow;

    setDbrReserve@withrevert(e, dbrReserve);

    assert lastReverted <=> isExpectedToRevert;
}

// `setDolaReserve()` updates storage as expected
rule unit_setDolaReserve_integrity() {
    env e;

    applySafeAssumptions(e);

    uint256 dolaReserve;

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);

    setDolaReserve(e, dolaReserve);

    assert currentContract.dbrReserve == dbrReserveBefore * dolaReserve / dolaReserveBefore;
    assert currentContract.dolaReserve == dolaReserve;
}

// `setDolaReserve()` reverts when expected
rule unit_setDolaReserve_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 dolaReserve;

    uint256 dolaReserveBefore;
    uint256 dbrReserveBefore;
    (dolaReserveBefore, dbrReserveBefore) = getReserves(e);

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isDolaReserveZero = dolaReserve == 0;
    bool isDolaReserveTooBig = dolaReserve > max_uint112;
    bool isOverflow = dbrReserveBefore * dolaReserve > max_uint256;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isDolaReserveZero ||
        isDolaReserveTooBig ||
        isOverflow;

    setDolaReserve@withrevert(e, dolaReserve);

    assert lastReverted <=> isExpectedToRevert;
}

// `setMaxYearlyRewardBudget()` updates storage as expected
rule unit_setMaxYearlyRewardBudget_integrity() {
    env e;

    applySafeAssumptions(e);

    uint256 maxYearlyRewardBudget;

    uint256 yearlyRewardBudgetBefore = currentContract.yearlyRewardBudget;

    setMaxYearlyRewardBudget(e, maxYearlyRewardBudget);

    assert currentContract.maxYearlyRewardBudget == maxYearlyRewardBudget;
    assert yearlyRewardBudgetBefore > maxYearlyRewardBudget => currentContract.yearlyRewardBudget == maxYearlyRewardBudget;
}

// `setMaxYearlyRewardBudget()` reverts when expected
rule unit_setMaxYearlyRewardBudget_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 maxYearlyRewardBudget;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setMaxYearlyRewardBudget@withrevert(e, maxYearlyRewardBudget);

    assert lastReverted <=> isExpectedToRevert;
}

// `setYearlyRewardBudget()` updates storage as expected
rule unit_setYearlyRewardBudget_integrity() {
    env e;

    applySafeAssumptions(e);

    uint256 yearlyRewardBudget;

    setYearlyRewardBudget(e, yearlyRewardBudget);

    assert currentContract.yearlyRewardBudget == yearlyRewardBudget;
}

// `setYearlyRewardBudget()` reverts when expected
rule unit_setYearlyRewardBudget_revertConditions() {
    env e;

    applySafeAssumptions(e);

    uint256 yearlyRewardBudget;

    bool isEtherSent = e.msg.value > 0;
    bool isOperatorOrGov = e.msg.sender == operator(e) || e.msg.sender == gov(e);
    bool isYearlyRewardBudgetGreaterThanMax = yearlyRewardBudget > currentContract.maxYearlyRewardBudget;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isOperatorOrGov ||
        isYearlyRewardBudgetGreaterThanMax;

    setYearlyRewardBudget@withrevert(e, yearlyRewardBudget);

    assert lastReverted <=> isExpectedToRevert;
}

// `setSlashingModule()` updates storage as expected
rule unit_setSlashingModule_integrity() {
    env e;

    applySafeAssumptions(e);

    address slashingModule;
    bool isEnabled;

    setSlashingModule(e, slashingModule, isEnabled);

    assert slashingModules(e, slashingModule) == isEnabled;
}

// `setSlashingModule()` reverts when expected
rule unit_setSlashingModule_revertConditions() {
    env e;

    applySafeAssumptions(e);

    address slashingModule;
    bool isEnabled;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setSlashingModule@withrevert(e, slashingModule, isEnabled);

    assert lastReverted <=> isExpectedToRevert;
}

// `setOperator()` updates storage as expected
rule unit_setOperator_integrity() {
    env e;

    applySafeAssumptions(e);

    address operator;

    setOperator(e, operator);

    assert currentContract.operator == operator;
}

// `setOperator()` reverts when expected
rule unit_setOperator_revertConditions() {
    env e;

    applySafeAssumptions(e);

    address operator;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setOperator@withrevert(e, operator);

    assert lastReverted <=> isExpectedToRevert;
}

// `setPendingGov()` updates storage as expected
rule unit_setPendingGov_integrity() {
    env e;

    applySafeAssumptions(e);

    address newGov;

    setPendingGov(e, newGov);

    assert currentContract.pendingGov == newGov;
}

// `setPendingGov()` reverts when expected
rule unit_setPendingGov_revertConditions() {
    env e;

    applySafeAssumptions(e);

    address newGov;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setPendingGov@withrevert(e, newGov);

    assert lastReverted <=> isExpectedToRevert;
}

// `acceptGov()` updates storage as expected
rule unit_acceptGov_integrity() {
    env e;

    applySafeAssumptions(e);

    address pendingGov = currentContract.pendingGov;

    acceptGov(e);

    assert currentContract.gov == pendingGov;
    assert currentContract.pendingGov == 0;
}

// `acceptGov()` reverts when expected
rule unit_acceptGov_revertConditions() {
    env e;

    applySafeAssumptions(e);

    bool isEtherSent = e.msg.value > 0;
    bool isPendingGov = e.msg.sender == currentContract.pendingGov;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isPendingGov;

    acceptGov@withrevert(e);

    assert lastReverted <=> isExpectedToRevert;
}

// `sweep()` updates storage as expected
rule unit_sweep_integrity() {
    env e;

    applySafeAssumptions(e);

    address token;
    uint256 amount;
    address receiver;

    require receiver != currentContract;

    uint256 receiverBalanceBefore = token.balanceOf(e, receiver);
    uint256 contractBalanceBefore = token.balanceOf(e, currentContract);

    sweep(e, token, amount, receiver);

    uint256 receiverBalanceAfter = token.balanceOf(e, receiver);
    uint256 contractBalanceAfter = token.balanceOf(e, currentContract);

    assert require_uint256(receiverBalanceBefore + amount) == receiverBalanceAfter;
    assert contractBalanceBefore - amount == contractBalanceAfter;
}

// `sweep()` reverts when expected
rule unit_sweep_revertConditions() {
    env e;

    applySafeAssumptions(e);

    address token;
    uint256 amount;
    address receiver;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isValidToken = token != DBR(e) && token != asset(e);
    bool hasContractEnoughBalance = token.balanceOf(e, currentContract) >= amount;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        !isValidToken ||
        !hasContractEnoughBalance;

    sweep@withrevert(e, token, amount, receiver);

    assert lastReverted <=> isExpectedToRevert;
}