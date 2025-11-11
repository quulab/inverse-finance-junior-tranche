# Inverse Finance - Junior Tranche  contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethereum
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
We are only integrating DOLA and DBR. Both are standard ERC-20 tokens, though DBR do have special behaviour in the case of a user using it for borrowing on FiRM markets.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
- Gov is trusted
- Operator is trusted to set the reward budget within the constraints set by Gov
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No. The protocols that we will integrate with are all under control of Inverse Finance governance. The main contracts we integrate with are our FiRM market contracts, which is a fixed rate lending market ran by Inverse Finance.
___

### Q: Is the codebase expected to comply with any specific EIPs?
We partially comply with the ERC-4626 standard, but break it when it comes to withdrawals, as the owner of shares is not able to directly withdraw from the vault but must go through the withdrawalEscrow process to do so.

We should be fully compliant with the ERC20 standard.

Issues that violate EIP "MUST" statements (even in view functions n;t used by write functions) may be deemed valid Medium severity, even if the impact is low/info. However, it's known that the contracts are not compliant when it comes to ERC4626 withdrawals and that's considered out of scope.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
A slasher will have to observe the chain for bad debt and slash jrDOLA depositors. There is incentive for DOLA holders to do this to make sure backing of their stablecoin is there, and for the Inverse Finance DAO to protect DOLA peg. For the purpose of this contest, assume that slashing will always happen in a timely manner.

___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
It should never be possible to slash jrDOLA holders to repay healthy debt. Oracle manipulations are out of scope here.
jrDOLA shares should always increase, or hold, DOLA value over time, as long as no slashings occur.

___

### Q: Please discuss any design choices you made.
We considered having functionality for scaling down the amount of jrDola shares per Dola in cases where multiple slashing events drive up the share/Dola ratio, but decided against it, as in these situations something will have gone dramatically wrong on the risk side of things, and starting over with a new deployment or contract would be better. If this makes the contract possible to break for an attacker at will, it should be considered a valid finding, but not if it’s only possible in extreme scenarios like more bad debt occurring than funds deposited, or a streak of very slashing events.

The withdrawal fee was added to discourage people continuously withdrawing to try and front run bad debt or slashing events while sitting in the exit window.

___

### Q: Please provide links to previous audits (if any) and all the known issues or acceptable risks.
https://www.inverse.finance/audits/junior-sherlock.pdf

The vault share inflation attack is known and should be considered out of scope. The protocol team will deposit on deployment and even if the attacker manages to front-run the deposit, the new vault will be deployed. Thus, a vault inflation attack will be considered invalid.

It's known that in a scenario where bad debt exceeds the total slashable amount from junior tranche, the users won't be able to withdraw as there won't be funds for it (besides the new deposits or accruing rewards).

Extreme slashing scenarios where repeated slashing and deposits cause shares to deflate are similarly known, and fall under known issues. These scenarios are considered a failure of risk parameterisation of the protected FiRM markets.
The slashing is considered extreme if all available funds are slashed
The slashing is considered extreme if several slashing actions compound to create extreme share deflation (share/deposit ratio exceeds 1000000x, ie, there are >=1_million_e18 shares for 1e18 of the underlying asset)
If the issue requires such an extreme slashing as a precondition and cannot happen without it, then the issue is considered Medium at max, as it's an extensive constraint.

It's known that due to extreme slashing will brick deposits (users won't be able to deposit) regarding share deflation up until the total share limit. However, if the issue requires extreme slashing, but is not connected to reaching the max total shares, then it's not considered known, but can be viewed as Medium at max (due to extensive constraints).

___

### Q: Please list any relevant protocol resources.
https://docs.inverse.finance/inverse-finance/
https://docs.inverse.finance/risk-working-group-digest/
https://www.inverse.finance/



# Audit scope

[InverseFinance__JuniorDola @ 3e5a39251fe92abaa306657c62f9b45ce6c1b234](https://github.com/sherlock-scoping/InverseFinance__JuniorDola/tree/3e5a39251fe92abaa306657c62f9b45ce6c1b234)
- [InverseFinance__JuniorDola/src/FiRMSlashingModule.sol](InverseFinance__JuniorDola/src/FiRMSlashingModule.sol)
- [InverseFinance__JuniorDola/src/jDola.sol](InverseFinance__JuniorDola/src/jDola.sol)
- [InverseFinance__JuniorDola/src/LinearInterpolationDelayModel.sol](InverseFinance__JuniorDola/src/LinearInterpolationDelayModel.sol)
- [InverseFinance__JuniorDola/src/WithdrawalEscrow.sol](InverseFinance__JuniorDola/src/WithdrawalEscrow.sol)


