pragma solidity ^0.8.24;

import {WithdrawalEscrow} from "../../src/WithdrawalEscrow.sol";

contract WithdrawalEscrowHarness is WithdrawalEscrow {
    constructor(address _gov, address _withdrawDelayModel) WithdrawalEscrow(_gov, _withdrawDelayModel) {}

    //============
    // Helpers
    //============

    function getFee(uint256 amount, address user) public returns (uint256) {
        uint totalWithdrawAmount = amount + withdrawAmounts[user];
        uint128 exitWindowStart = exitWindows[user].start;
        uint fee;
        if(withdrawFeeBps > 0){
            //If user has had a chance to withdraw, we apply full fee, otherwise only apply fee on new amount
            fee = totalWithdrawAmount > amount && block.timestamp > exitWindowStart ?
                totalWithdrawAmount * withdrawFeeBps / 10000 :
                amount * withdrawFeeBps / 10000;
        }
        return fee;
    }

    function getReentrancyGuardSlotValue() public view returns (uint256) {
        uint256 _REENTRANCY_GUARD_SLOT = 0x8000000000ab143c06;
        uint256 value;
        assembly {
            value := tload(_REENTRANCY_GUARD_SLOT)
        }
        return value;
    }
}