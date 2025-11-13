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

//===========
// Unit
//===========

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
