using JDola as jDola;
using MockERC20 as dolaToken;
using MockDBR as dbrToken;
using MockMarket as mockMarket;

methods {
    // ERC20
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    // MockMarket
    function _.getCollateralValue(address) external => DISPATCHER(true);
    function _.debts(address) external => DISPATCHER(true);
    function _.repay(address borrower, uint256 slashedAmount) external => repayCVL(borrower, slashedAmount) expect void;
}

definition SECONDS_IN_WEEK() returns uint256 = 604800;

function repayCVL(address borrower, uint256 slashedAmount) {
    // do nothing
} 

//===========
// High
//===========

// Methods are called by expected roles
rule high_accessControl() {
    env e;
    method f;
    calldataarg args;

    address pendingGovBefore = currentContract.pendingGov;

    f(e, args);

    assert
        (
            f.selector == sig:allowMarket(address).selector ||
            f.selector == sig:setMaxCollateralValue(uint256).selector ||
            f.selector == sig:setMinDebt(uint256).selector ||
            f.selector == sig:setActivationDelay(uint256).selector ||
            f.selector == sig:setPendingGov(address).selector ||
            f.selector == sig:setGuardian(address).selector
        )
        =>
        e.msg.sender == currentContract.gov;

    assert
        (
            f.selector == sig:disallowMarket(address).selector
        )
        =>
        e.msg.sender == currentContract.gov ||
        e.msg.sender == currentContract.guardian;

    assert
        (
            f.selector == sig:acceptGov().selector
        )
        =>
        e.msg.sender == pendingGovBefore;
}

//===========
// Unit
//===========

// `slash()` updates storage as expected
rule unit_slash_integrity() {
    env e;

    address borrower;

    uint256 collateralAmount = mockMarket.getCollateralValue(e, borrower);
    uint256 debtAmount = mockMarket.debts(e, borrower);

    require jDola.totalAssets(e) - 1000000000000000000 == debtAmount - collateralAmount, "There're always available assets";

    uint256 slashedAmount = slash(e, mockMarket, borrower);

    assert slashedAmount == debtAmount - collateralAmount;
}

// `slash()` revets when expected
rule unit_slash_revertConditions() {
    env e;

    address borrower;

    uint256 collateralAmount = mockMarket.getCollateralValue(e, borrower);
    uint256 debtAmount = mockMarket.debts(e, borrower);
    uint256 currentWeek = require_uint256(e.block.timestamp / SECONDS_IN_WEEK());

    require e.block.timestamp >= SECONDS_IN_WEEK();
    require jDola.totalAssets(e) - 1000000000000000000 == debtAmount - collateralAmount, "There're always available assets";

    bool isEtherSent = e.msg.value > 0;
    bool isMarketAllowed = allowedMarkets(e, mockMarket);
    bool isActiveFirmMarket = dbrToken.markets(e, mockMarket);
    bool isMarketActivated = activationTime(e, mockMarket) <= e.block.timestamp && activationTime(e, mockMarket) > 0;
    bool hasBadDebt = debtAmount > collateralAmount;
    bool isDebtTooLow = debtAmount < minDebt(e);
    bool isCollateralTooHigh = collateralAmount > maxCollateralValue(e);
    bool isSlashingModule = jDola.slashingModules(e, currentContract);
    bool hasVaultEnoughBalance = dolaToken.balanceOf(e, jDola) >= debtAmount - collateralAmount;
    bool isRemainingLastRevenueOverflow = jDola.weeklyRevenue(e, require_uint256(currentWeek - 1)) * (SECONDS_IN_WEEK() - (e.block.timestamp % SECONDS_IN_WEEK())) / SECONDS_IN_WEEK() > max_uint256;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isMarketAllowed ||
        !isActiveFirmMarket ||
        !isMarketActivated ||
        !hasBadDebt ||
        isDebtTooLow ||
        isCollateralTooHigh ||
        !isSlashingModule ||
        !hasVaultEnoughBalance ||
        isRemainingLastRevenueOverflow;

    slash@withrevert(e, mockMarket, borrower);

    assert lastReverted <=> isExpectedToRevert;
}

// `allowMarket()` updates storage as expected
rule unit_allowMarket_integrity() {
    env e;

    address market;

    allowMarket(e, market);

    assert allowedMarkets(e, market);
    assert activationTime(e, market) == e.block.timestamp + activationDelay(e);
}

// `allowMarket()` revets when expected
rule unit_allowMarket_revertConditions() {
    env e;

    address market;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isOverflow = e.block.timestamp + activationDelay(e) > max_uint256;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isOverflow;

    allowMarket@withrevert(e, market);

    assert lastReverted <=> isExpectedToRevert;
}

// `disallowMarket()` updates storage as expected
rule unit_disallowMarket_integrity() {
    env e;

    address market;

    disallowMarket(e, market);

    assert !allowedMarkets(e, market);
    assert activationTime(e, market) == 0;
}

// `disallowMarket()` revets when expected
rule unit_disallowMarket_revertConditions() {
    env e;

    address market;

    bool isEtherSent = e.msg.value > 0;
    bool isGovOrGuardian = e.msg.sender == currentContract.gov || e.msg.sender == currentContract.guardian;
    bool isGuardianTryToRemoveActiveMarket = e.msg.sender == currentContract.guardian && e.block.timestamp >= activationTime(e, market);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGovOrGuardian ||
        isGuardianTryToRemoveActiveMarket;

    disallowMarket@withrevert(e, market);

    assert lastReverted <=> isExpectedToRevert;
}

// `setMaxCollateralValue()` updates storage as expected
rule unit_setMaxCollateralValue_integrity() {
    env e;

    uint256 maxCollateralValue;

    setMaxCollateralValue(e, maxCollateralValue);

    assert currentContract.maxCollateralValue == maxCollateralValue;
}

// `setMaxCollateralValue()` revets when expected
rule unit_setMaxCollateralValue_revertConditions() {
    env e;

    uint256 maxCollateralValue;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isMaxCollateralValueZero = maxCollateralValue == 0;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isMaxCollateralValueZero;

    setMaxCollateralValue@withrevert(e, maxCollateralValue);

    assert lastReverted <=> isExpectedToRevert;
}

// `setMinDebt()` updates storage as expected
rule unit_setMinDebt_integrity() {
    env e;

    uint256 minDebt;

    setMinDebt(e, minDebt);

    assert currentContract.minDebt == minDebt;
}

// `setMinDebt()` revets when expected
rule unit_setMinDebt_revertConditions() {
    env e;

    uint256 minDebt;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setMinDebt@withrevert(e, minDebt);

    assert lastReverted <=> isExpectedToRevert;
}

// `setActivationDelay()` updates storage as expected
rule unit_setActivationDelay_integrity() {
    env e;

    uint256 activationDelay;

    setActivationDelay(e, activationDelay);

    assert currentContract.activationDelay == activationDelay;
}

// `setActivationDelay()` revets when expected
rule unit_setActivationDelay_revertConditions() {
    env e;

    uint256 activationDelay;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == currentContract.gov;
    bool isActivationDelayTooLow = activationDelay < MIN_ACTIVATION_DELAY(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isActivationDelayTooLow;

    setActivationDelay@withrevert(e, activationDelay);

    assert lastReverted <=> isExpectedToRevert;
}

// `setPendingGov()` updates storage as expected
rule unit_setPendingGov_integrity() {
    env e;

    address newGov;

    setPendingGov(e, newGov);

    assert currentContract.pendingGov == newGov;
}

// `setPendingGov()` reverts when expected
rule unit_setPendingGov_revertConditions() {
    env e;

    address newGov;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setPendingGov@withrevert(e, newGov);

    assert lastReverted <=> isExpectedToRevert;
}

// `setGuardian()` updates storage as expected
rule unit_setGuardian_integrity() {
    env e;

    address guardian;

    setGuardian(e, guardian);

    assert currentContract.guardian == guardian;
}

// `setGuardian()` reverts when expected
rule unit_setGuardian_revertConditions() {
    env e;

    address guardian;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov;

    setGuardian@withrevert(e, guardian);

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
