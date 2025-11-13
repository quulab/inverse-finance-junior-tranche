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
    function _.repay(address, uint256) external => DISPATCHER(true);
}

definition SECONDS_IN_WEEK() returns uint256 = 604800;

//===========
// Unit
//===========

// // `slash()` updates storage as expected
// rule unit_slash_integrity() {
//     env e;

//     address borrower;

//     uint256 collateralAmount = mockMarket.getCollateralValue(e, borrower);
//     uint256 debtAmount = mockMarket.debts(e, borrower);

//     require jDola.totalAssets(e) - 1000000000000000000 == debtAmount - collateralAmount, "There're always available assets";

//     uint256 slashedAmount = slash(e, mockMarket, borrower);

//     assert slashedAmount == debtAmount - collateralAmount;
// }

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
