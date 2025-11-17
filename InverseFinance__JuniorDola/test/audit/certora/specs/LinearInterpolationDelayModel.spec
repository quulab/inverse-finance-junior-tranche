//===========
// High
//===========

// Methods are called by expected roles
rule high_accessControl() {
    env e;
    method f;
    calldataarg args;

    f(e, args);

    assert
        (
            f.selector == sig:setMinDelay(uint96).selector ||
            f.selector == sig:setMaxDelay(uint96).selector ||
            f.selector == sig:setMaxDelayThresholdBps(uint16).selector ||
            f.selector == sig:setPendingGov(address).selector
        )
        =>
        e.msg.sender == currentContract.gov;
}

//===========
// Unit
//===========

// `setMinDelay()` updates storage as expected
rule unit_setMinDelay_integrity() {
    env e;

    uint96 minDelay;

    setMinDelay(e, minDelay);

    assert currentContract.minDelay == minDelay;
}

// `setMinDelay()` reverts when expected
rule unit_setMinDelay_revertConditions() {
    env e;

    uint96 minDelay;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isMinDelayGreaterThanMaxDelay = minDelay > currentContract.maxDelay;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isMinDelayGreaterThanMaxDelay;

    setMinDelay@withrevert(e, minDelay);

    assert lastReverted <=> isExpectedToRevert;
}

// `setMaxDelay()` updates storage as expected
rule unit_setMaxDelay_integrity() {
    env e;

    uint96 maxDelay;

    setMaxDelay(e, maxDelay);

    assert currentContract.maxDelay == maxDelay;
}

// `setMaxDelay()` reverts when expected
rule unit_setMaxDelay_revertConditions() {
    env e;

    uint96 maxDelay;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isMaxDelayLessThanMinDelay = maxDelay < currentContract.minDelay;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isMaxDelayLessThanMinDelay;

    setMaxDelay@withrevert(e, maxDelay);

    assert lastReverted <=> isExpectedToRevert;
}

// `setMaxDelayThresholdBps()` updates storage as expected
rule unit_setMaxDelayThresholdBps_integrity() {
    env e;

    uint16 maxDelayThresholdBps;

    setMaxDelayThresholdBps(e, maxDelayThresholdBps);

    assert currentContract.maxDelayThresholdBps == maxDelayThresholdBps;
}

// `setMaxDelayThresholdBps()` reverts when expected
rule unit_setMaxDelayThresholdBps_revertConditions() {
    env e;

    uint16 maxDelayThresholdBps;

    bool isEtherSent = e.msg.value > 0;
    bool isGov = e.msg.sender == gov(e);
    bool isMaxDelayThresholdBpsExceeded = maxDelayThresholdBps > 10000;

    bool isExpectedToRevert = 
        isEtherSent ||
        !isGov ||
        isMaxDelayThresholdBpsExceeded;

    setMaxDelayThresholdBps@withrevert(e, maxDelayThresholdBps);

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

