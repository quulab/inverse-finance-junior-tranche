using MockERC20 as dolaToken;
using MockDBR as dbrToken;

//===========
// Unit
//===========

// `buyDbr()` updates storage as expected
rule unit_buyDbr_integrity() {
    env e;

    uint256 exactDolaIn; 
    uint256 exactDbrOut; 
    address receiver;

    uint256 dolaReserveBefore = dolaReserve(e);
    uint256 dbrReserveBefore = dbrReserve(e);
    uint256 receiverDbrBalanceBefore = dbrToken.balanceOf(e, receiver);

    buyDbr(e, exactDolaIn, exactDbrOut, receiver);

    uint256 dolaReserveAfter = dolaReserve(e);
    uint256 dbrReserveAfter = dbrReserve(e);
    uint256 receiverDbrBalanceAfter = dbrToken.balanceOf(e, receiver);

    assert dolaReserveAfter == require_uint256(dolaReserveBefore + exactDolaIn);
    assert dbrReserveAfter == dbrReserveBefore - exactDbrOut;
    assert receiverDbrBalanceAfter == require_uint256(receiverDbrBalanceBefore + exactDbrOut);
}
