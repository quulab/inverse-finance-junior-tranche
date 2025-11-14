**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [weak-prng](#weak-prng) (1 results) (High)
 - [unchecked-transfer](#unchecked-transfer) (2 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (1 results) (Medium)
 - [erc20-interface](#erc20-interface) (1 results) (Medium)
 - [incorrect-equality](#incorrect-equality) (6 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (2 results) (Medium)
 - [events-access](#events-access) (1 results) (Low)
 - [events-maths](#events-maths) (7 results) (Low)
 - [missing-zero-check](#missing-zero-check) (11 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
 - [reentrancy-events](#reentrancy-events) (2 results) (Low)
 - [timestamp](#timestamp) (13 results) (Low)
 - [assembly](#assembly) (11 results) (Informational)
 - [pragma](#pragma) (1 results) (Informational)
 - [solc-version](#solc-version) (2 results) (Informational)
 - [missing-inheritance](#missing-inheritance) (3 results) (Informational)
 - [naming-convention](#naming-convention) (29 results) (Informational)
 - [too-many-digits](#too-many-digits) (7 results) (Informational)
## weak-prng
Impact: High
Confidence: Medium
 - [ ] ID-0
[JDola.totalAssets()](src/jDola.sol#L138-L144) uses a weak PRNG: "[timeElapsed = block.timestamp % 604800](src/jDola.sol#L140)" 

src/jDola.sol#L138-L144


## unchecked-transfer
Impact: High
Confidence: Medium
 - [ ] ID-1
[WithdrawalEscrow.cancelWithdrawal()](src/WithdrawalEscrow.sol#L133-L141) ignores return value by [vault.transfer(msg.sender,withdrawAmount)](src/WithdrawalEscrow.sol#L140)

src/WithdrawalEscrow.sol#L133-L141


 - [ ] ID-2
[WithdrawalEscrow.queueWithdrawal(uint256,uint256)](src/WithdrawalEscrow.sol#L78-L118) ignores return value by [vault.transferFrom(msg.sender,address(this),amount)](src/WithdrawalEscrow.sol#L92)

src/WithdrawalEscrow.sol#L78-L118


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-3
[FixedPointMathLib.rpow(uint256,uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L71-L158) performs a multiplication on the result of a division:
	- [x = xxRound_rpow_asm_0 / scalar](lib/solmate/src/utils/FixedPointMathLib.sol#L129)
	- [zx_rpow_asm_0 = z * x](lib/solmate/src/utils/FixedPointMathLib.sol#L134)

lib/solmate/src/utils/FixedPointMathLib.sol#L71-L158


## erc20-interface
Impact: Medium
Confidence: High
 - [ ] ID-4
[IERC20](src/FiRMSlashingModule.sol#L11-L13) has incorrect ERC20 function interface:[IERC20.approve(address,uint256)](src/FiRMSlashingModule.sol#L12)

src/FiRMSlashingModule.sol#L11-L13


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-5
[ERC4626.convertToShares(uint256)](lib/solmate/src/tokens/ERC4626.sol#L124-L128) uses a dangerous strict equality:
	- [supply == 0](lib/solmate/src/tokens/ERC4626.sol#L127)

lib/solmate/src/tokens/ERC4626.sol#L124-L128


 - [ ] ID-6
[ERC4626.previewMint(uint256)](lib/solmate/src/tokens/ERC4626.sol#L140-L144) uses a dangerous strict equality:
	- [supply == 0](lib/solmate/src/tokens/ERC4626.sol#L143)

lib/solmate/src/tokens/ERC4626.sol#L140-L144


 - [ ] ID-7
[JDola.beforeWithdraw(uint256,uint256)](src/jDola.sol#L111-L115) uses a dangerous strict equality:
	- [require(bool,string)(totalAssets() >= assets + MIN_ASSETS || assets == totalAssets(),Assets below MIN_ASSETS)](src/jDola.sol#L113)

src/jDola.sol#L111-L115


 - [ ] ID-8
[JDola.beforeWithdraw(uint256,uint256)](src/jDola.sol#L111-L115) uses a dangerous strict equality:
	- [require(bool,string)(totalSupply - shares >= MIN_SHARES || shares == totalSupply,Shares below MIN_SHARES)](src/jDola.sol#L114)

src/jDola.sol#L111-L115


 - [ ] ID-9
[ERC4626.convertToAssets(uint256)](lib/solmate/src/tokens/ERC4626.sol#L130-L134) uses a dangerous strict equality:
	- [supply == 0](lib/solmate/src/tokens/ERC4626.sol#L133)

lib/solmate/src/tokens/ERC4626.sol#L130-L134


 - [ ] ID-10
[ERC4626.previewWithdraw(uint256)](lib/solmate/src/tokens/ERC4626.sol#L146-L150) uses a dangerous strict equality:
	- [supply == 0](lib/solmate/src/tokens/ERC4626.sol#L149)

lib/solmate/src/tokens/ERC4626.sol#L146-L150


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-11
[WithdrawalEscrow.queueWithdrawal(uint256,uint256).fee](src/WithdrawalEscrow.sol#L96) is a local variable never initialized

src/WithdrawalEscrow.sol#L96


 - [ ] ID-12
[WithdrawalEscrow.queueWithdrawal(uint256,uint256).withdrawDelay](src/WithdrawalEscrow.sol#L79) is a local variable never initialized

src/WithdrawalEscrow.sol#L79


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-13
[WithdrawalEscrow.queueWithdrawal(uint256,uint256)](src/WithdrawalEscrow.sol#L78-L118) ignores return value by [vault.asset().approve(address(vault),feeDola)](src/WithdrawalEscrow.sol#L114)

src/WithdrawalEscrow.sol#L78-L118


 - [ ] ID-14
[WithdrawalEscrow.completeWithdraw()](src/WithdrawalEscrow.sol#L121-L131) ignores return value by [vault.redeem(withdrawAmount,msg.sender,address(this))](src/WithdrawalEscrow.sol#L129)

src/WithdrawalEscrow.sol#L121-L131


## events-access
Impact: Low
Confidence: Medium
 - [ ] ID-15
[JDola.setOperator(address)](src/jDola.sol#L277-L279) should emit an event for: 
	- [operator = _operator](src/jDola.sol#L278) 

src/jDola.sol#L277-L279


## events-maths
Impact: Low
Confidence: Medium
 - [ ] ID-16
[WithdrawalEscrow.setWithdrawFee(uint256)](src/WithdrawalEscrow.sol#L152-L155) should emit an event for: 
	- [withdrawFeeBps = _withdrawFeeBps](src/WithdrawalEscrow.sol#L154) 

src/WithdrawalEscrow.sol#L152-L155


 - [ ] ID-17
[FiRMSlashingModule.setMaxCollateralValue(uint256)](src/FiRMSlashingModule.sol#L117-L120) should emit an event for: 
	- [maxCollateralValue = _maxCollateralValue](src/FiRMSlashingModule.sol#L119) 

src/FiRMSlashingModule.sol#L117-L120


 - [ ] ID-18
[JDola.setDbrReserve(uint256)](src/jDola.sol#L220-L225) should emit an event for: 
	- [dolaReserve = dolaReserve * _dbrReserve / dbrReserve](src/jDola.sol#L223) 
	- [dbrReserve = _dbrReserve](src/jDola.sol#L224) 

src/jDola.sol#L220-L225


 - [ ] ID-19
[JDola.setDolaReserve(uint256)](src/jDola.sol#L230-L235) should emit an event for: 
	- [dbrReserve = dbrReserve * _dolaReserve / dolaReserve](src/jDola.sol#L233) 
	- [dolaReserve = _dolaReserve](src/jDola.sol#L234) 

src/jDola.sol#L230-L235


 - [ ] ID-20
[WithdrawalEscrow.setExitWindow(uint256)](src/WithdrawalEscrow.sol#L157-L161) should emit an event for: 
	- [exitWindow = _exitWindow](src/WithdrawalEscrow.sol#L160) 

src/WithdrawalEscrow.sol#L157-L161


 - [ ] ID-21
[JDola.initialize(uint256,uint256)](src/jDola.sol#L122-L131) should emit an event for: 
	- [dbrReserve = _dbrReserve](src/jDola.sol#L128) 
	- [dolaReserve = _dolaReserve](src/jDola.sol#L129) 

src/jDola.sol#L122-L131


 - [ ] ID-22
[FiRMSlashingModule.setMinDebt(uint256)](src/FiRMSlashingModule.sol#L127-L129) should emit an event for: 
	- [minDebt = _minDebt](src/FiRMSlashingModule.sol#L128) 

src/FiRMSlashingModule.sol#L127-L129


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-23
[JDola.setPendingGov(address)._gov](src/jDola.sol#L285) lacks a zero-check on :
		- [pendingGov = _gov](src/jDola.sol#L286)

src/jDola.sol#L285


 - [ ] ID-24
[JDola.constructor(address,address,address,address,ERC20,string,string)._gov](src/jDola.sol#L49) lacks a zero-check on :
		- [gov = _gov](src/jDola.sol#L58)

src/jDola.sol#L49


 - [ ] ID-25
[JDola.constructor(address,address,address,address,ERC20,string,string)._operator](src/jDola.sol#L50) lacks a zero-check on :
		- [operator = _operator](src/jDola.sol#L59)

src/jDola.sol#L50


 - [ ] ID-26
[JDola.constructor(address,address,address,address,ERC20,string,string)._withdrawEscrow](src/jDola.sol#L51) lacks a zero-check on :
		- [withdrawEscrow = _withdrawEscrow](src/jDola.sol#L60)

src/jDola.sol#L51


 - [ ] ID-27
[FiRMSlashingModule.setPendingGov(address)._pendingGov](src/FiRMSlashingModule.sol#L145) lacks a zero-check on :
		- [pendingGov = _pendingGov](src/FiRMSlashingModule.sol#L146)

src/FiRMSlashingModule.sol#L145


 - [ ] ID-28
[WithdrawalEscrow.setGov(address)._gov](src/WithdrawalEscrow.sol#L163) lacks a zero-check on :
		- [pendingGov = _gov](src/WithdrawalEscrow.sol#L164)

src/WithdrawalEscrow.sol#L163


 - [ ] ID-29
[WithdrawalEscrow.constructor(address,address)._gov](src/WithdrawalEscrow.sol#L52) lacks a zero-check on :
		- [gov = _gov](src/WithdrawalEscrow.sol#L53)

src/WithdrawalEscrow.sol#L52


 - [ ] ID-30
[LinearInterpolationDelayModel.constructor(uint96,uint96,uint16,address)._gov](src/LinearInterpolationDelayModel.sol#L21) lacks a zero-check on :
		- [gov = _gov](src/LinearInterpolationDelayModel.sol#L27)

src/LinearInterpolationDelayModel.sol#L21


 - [ ] ID-31
[LinearInterpolationDelayModel.setPendingGov(address)._gov](src/LinearInterpolationDelayModel.sol#L55) lacks a zero-check on :
		- [pendingGov = _gov](src/LinearInterpolationDelayModel.sol#L56)

src/LinearInterpolationDelayModel.sol#L55


 - [ ] ID-32
[JDola.setOperator(address)._operator](src/jDola.sol#L277) lacks a zero-check on :
		- [operator = _operator](src/jDola.sol#L278)

src/jDola.sol#L277


 - [ ] ID-33
[FiRMSlashingModule.setGuardian(address)._guardian](src/FiRMSlashingModule.sol#L154) lacks a zero-check on :
		- [guardian = _guardian](src/FiRMSlashingModule.sol#L155)

src/FiRMSlashingModule.sol#L154


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-34
Reentrancy in [WithdrawalEscrow.queueWithdrawal(uint256,uint256)](src/WithdrawalEscrow.sol#L78-L118):
	External calls:
	- [_withdrawDelay = this.getWithdrawDelay(vault.totalSupply(),vault.balanceOf(address(this)) + amount,msg.sender)](src/WithdrawalEscrow.sol#L80-L90)
	- [vault.transferFrom(msg.sender,address(this),amount)](src/WithdrawalEscrow.sol#L92)
	State variables written after the call(s):
	- [exitWindows[msg.sender] = ExitWindow(start,end)](src/WithdrawalEscrow.sol#L111)
	- [withdrawAmounts[msg.sender] = totalWithdrawAmount](src/WithdrawalEscrow.sol#L104)

src/WithdrawalEscrow.sol#L78-L118


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-35
Reentrancy in [JDola.buyDbr(uint256,uint256,address)](src/jDola.sol#L159-L168):
	External calls:
	- [DBR.mint(to,exactDbrOut)](src/jDola.sol#L166)
	Event emitted after the call(s):
	- [Buy(msg.sender,to,exactDolaIn,exactDbrOut)](src/jDola.sol#L167)

src/jDola.sol#L159-L168


 - [ ] ID-36
Reentrancy in [FiRMSlashingModule.slash(address,address)](src/FiRMSlashingModule.sol#L66-L82):
	External calls:
	- [slashed = JUNIOR_POOL.slash(debt - collateralValue)](src/FiRMSlashingModule.sol#L77)
	- [DOLA.approve(market,slashed)](src/FiRMSlashingModule.sol#L78)
	- [IMarket(market).repay(borrower,slashed)](src/FiRMSlashingModule.sol#L79)
	Event emitted after the call(s):
	- [Slash(market,borrower,slashed)](src/FiRMSlashingModule.sol#L80)

src/FiRMSlashingModule.sol#L66-L82


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-37
[ERC20.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)](lib/solmate/src/tokens/ERC20.sol#L116-L160) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(deadline >= block.timestamp,PERMIT_DEADLINE_EXPIRED)](lib/solmate/src/tokens/ERC20.sol#L125)

lib/solmate/src/tokens/ERC20.sol#L116-L160


 - [ ] ID-38
[JDola.getReserves()](src/jDola.sol#L202-L213) uses timestamp for comparisons
	Dangerous comparisons:
	- [timeElapsed > 0](src/jDola.sol#L204)

src/jDola.sol#L202-L213


 - [ ] ID-39
[JDola.slash(uint256)](src/jDola.sol#L186-L195) uses timestamp for comparisons
	Dangerous comparisons:
	- [availableAssets <= amount](src/jDola.sol#L189)
	- [require(bool,string)(amount > 0,Zero slash)](src/jDola.sol#L191)

src/jDola.sol#L186-L195


 - [ ] ID-40
[WithdrawalEscrow.completeWithdraw()](src/WithdrawalEscrow.sol#L121-L131) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(block.timestamp >= _exitWindow.start,Exit window hasn't started)](src/WithdrawalEscrow.sol#L124)
	- [require(bool,string)(block.timestamp <= _exitWindow.end,Exit window has ended)](src/WithdrawalEscrow.sol#L125)

src/WithdrawalEscrow.sol#L121-L131


 - [ ] ID-41
[FiRMSlashingModule.slash(address,address)](src/FiRMSlashingModule.sol#L66-L82) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(activationTime[market] <= block.timestamp && activationTime[market] > 0,Market protection not activated)](src/FiRMSlashingModule.sol#L69)

src/FiRMSlashingModule.sol#L66-L82


 - [ ] ID-42
[FiRMSlashingModule.disallowMarket(address)](src/FiRMSlashingModule.sol#L102-L110) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(block.timestamp < activationTime[market],GUARDIAN CANNOT REMOVE ACTIVE MARKET)](src/FiRMSlashingModule.sol#L105)

src/FiRMSlashingModule.sol#L102-L110


 - [ ] ID-43
[JDola.afterDeposit(uint256,uint256)](src/jDola.sol#L99-L103) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(totalSupply >= MIN_SHARES,Shares below MIN_SHARES)](src/jDola.sol#L100)
	- [require(bool,string)(totalSupply <= MAX_SHARES,Shares above MAX_SHARES)](src/jDola.sol#L101)
	- [require(bool,string)(totalAssets() >= MIN_ASSETS,Assets below MIN_ASSETS)](src/jDola.sol#L102)

src/jDola.sol#L99-L103


 - [ ] ID-44
[JDola.totalAssets()](src/jDola.sol#L138-L144) uses timestamp for comparisons
	Dangerous comparisons:
	- [actualAssets < MAX_ASSETS](src/jDola.sol#L143)

src/jDola.sol#L138-L144


 - [ ] ID-45
[JDola.buyDbr(uint256,uint256,address)](src/jDola.sol#L159-L168) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(dolaReserve * dbrReserve >= K,Invariant)](src/jDola.sol#L164)

src/jDola.sol#L159-L168


 - [ ] ID-46
[WithdrawalEscrow.cancelWithdrawal()](src/WithdrawalEscrow.sol#L133-L141) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(exitWindows[msg.sender].start <= block.timestamp,Cant cancel before exit window start)](src/WithdrawalEscrow.sol#L136)

src/WithdrawalEscrow.sol#L133-L141


 - [ ] ID-47
[WithdrawalEscrow.queueWithdrawal(uint256,uint256)](src/WithdrawalEscrow.sol#L78-L118) uses timestamp for comparisons
	Dangerous comparisons:
	- [exitWindowStart > start](src/WithdrawalEscrow.sol#L107)
	- [require(bool,string)(start - block.timestamp <= maxWithdrawDelay,Max withdraw delay exceeded)](src/WithdrawalEscrow.sol#L109)
	- [totalWithdrawAmount > amount && block.timestamp > exitWindowStart](src/WithdrawalEscrow.sol#L99-L101)

src/WithdrawalEscrow.sol#L78-L118


 - [ ] ID-48
[JDola.beforeWithdraw(uint256,uint256)](src/jDola.sol#L111-L115) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(totalAssets() >= assets + MIN_ASSETS || assets == totalAssets(),Assets below MIN_ASSETS)](src/jDola.sol#L113)
	- [require(bool,string)(totalSupply - shares >= MIN_SHARES || shares == totalSupply,Shares below MIN_SHARES)](src/jDola.sol#L114)

src/jDola.sol#L111-L115


 - [ ] ID-49
[JDola.initialize(uint256,uint256)](src/jDola.sol#L122-L131) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(dbrReserve == 0,dbr reserves already set)](src/jDola.sol#L123)
	- [require(bool,string)(dolaReserve == 0,dbr reserves already set)](src/jDola.sol#L124)

src/jDola.sol#L122-L131


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-50
[FixedPointMathLib.unsafeDiv(uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L238-L245) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L240-L244)

lib/solmate/src/utils/FixedPointMathLib.sol#L238-L245


 - [ ] ID-51
[FixedPointMathLib.unsafeMod(uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L229-L236) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L231-L235)

lib/solmate/src/utils/FixedPointMathLib.sol#L229-L236


 - [ ] ID-52
[FixedPointMathLib.unsafeDivUp(uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L247-L254) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L249-L253)

lib/solmate/src/utils/FixedPointMathLib.sol#L247-L254


 - [ ] ID-53
[FixedPointMathLib.sqrt(uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L166-L226)

lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227


 - [ ] ID-54
[FixedPointMathLib.mulDivUp(uint256,uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L53-L69) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L59-L68)

lib/solmate/src/utils/FixedPointMathLib.sol#L53-L69


 - [ ] ID-55
[SafeTransferLib.safeTransferFrom(ERC20,address,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L30-L61) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/SafeTransferLib.sol#L39-L58)

lib/solmate/src/utils/SafeTransferLib.sol#L30-L61


 - [ ] ID-56
[FixedPointMathLib.rpow(uint256,uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L71-L158) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L77-L157)

lib/solmate/src/utils/FixedPointMathLib.sol#L71-L158


 - [ ] ID-57
[SafeTransferLib.safeApprove(ERC20,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L94-L123) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/SafeTransferLib.sol#L102-L120)

lib/solmate/src/utils/SafeTransferLib.sol#L94-L123


 - [ ] ID-58
[SafeTransferLib.safeTransferETH(address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L14-L24) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/SafeTransferLib.sol#L18-L21)

lib/solmate/src/utils/SafeTransferLib.sol#L14-L24


 - [ ] ID-59
[SafeTransferLib.safeTransfer(ERC20,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L63-L92) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/SafeTransferLib.sol#L71-L89)

lib/solmate/src/utils/SafeTransferLib.sol#L63-L92


 - [ ] ID-60
[FixedPointMathLib.mulDivDown(uint256,uint256,uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L36-L51) uses assembly
	- [INLINE ASM](lib/solmate/src/utils/FixedPointMathLib.sol#L42-L50)

lib/solmate/src/utils/FixedPointMathLib.sol#L36-L51


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-61
3 different versions of Solidity are used:
	- Version constraint >=0.8.0 is used by:
		-[>=0.8.0](lib/solmate/src/tokens/ERC20.sol#L2)
		-[>=0.8.0](lib/solmate/src/tokens/ERC4626.sol#L2)
		-[>=0.8.0](lib/solmate/src/utils/FixedPointMathLib.sol#L2)
		-[>=0.8.0](lib/solmate/src/utils/SafeTransferLib.sol#L2)
	- Version constraint ^0.8.21 is used by:
		-[^0.8.21](src/FiRMSlashingModule.sol#L1)
	- Version constraint ^0.8.24 is used by:
		-[^0.8.24](src/LinearInterpolationDelayModel.sol#L1)
		-[^0.8.24](src/ReentrancyGuardTransient.sol#L2)
		-[^0.8.24](src/WithdrawalEscrow.sol#L1)
		-[^0.8.24](src/jDola.sol#L2)

lib/solmate/src/tokens/ERC20.sol#L2


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-62
Version constraint ^0.8.21 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication.
It is used by:
	- [^0.8.21](src/FiRMSlashingModule.sol#L1)

src/FiRMSlashingModule.sol#L1


 - [ ] ID-63
Version constraint >=0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching.
It is used by:
	- [>=0.8.0](lib/solmate/src/tokens/ERC20.sol#L2)
	- [>=0.8.0](lib/solmate/src/tokens/ERC4626.sol#L2)
	- [>=0.8.0](lib/solmate/src/utils/FixedPointMathLib.sol#L2)
	- [>=0.8.0](lib/solmate/src/utils/SafeTransferLib.sol#L2)

lib/solmate/src/tokens/ERC20.sol#L2


## missing-inheritance
Impact: Informational
Confidence: High
 - [ ] ID-64
[JDola](src/jDola.sol#L22-L319) should inherit from [IJuniorPool](src/FiRMSlashingModule.sol#L3-L5)

src/jDola.sol#L22-L319


 - [ ] ID-65
[WithdrawalEscrow](src/WithdrawalEscrow.sol#L27-L172) should inherit from [IWithdrawDelayModel](src/WithdrawalEscrow.sol#L23-L25)

src/WithdrawalEscrow.sol#L27-L172


 - [ ] ID-66
[LinearInterpolationDelayModel](src/LinearInterpolationDelayModel.sol#L3-L65) should inherit from [IWithdrawDelayModel](src/WithdrawalEscrow.sol#L23-L25)

src/LinearInterpolationDelayModel.sol#L3-L65


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-67
Parameter [LinearInterpolationDelayModel.setPendingGov(address)._gov](src/LinearInterpolationDelayModel.sol#L55) is not in mixedCase

src/LinearInterpolationDelayModel.sol#L55


 - [ ] ID-68
Parameter [FiRMSlashingModule.setActivationDelay(uint256)._activationDelay](src/FiRMSlashingModule.sol#L135) is not in mixedCase

src/FiRMSlashingModule.sol#L135


 - [ ] ID-69
Parameter [WithdrawalEscrow.initialize(address)._vault](src/WithdrawalEscrow.sol#L143) is not in mixedCase

src/WithdrawalEscrow.sol#L143


 - [ ] ID-70
Parameter [WithdrawalEscrow.setWithdrawDelayModel(address)._withdrawDelayModel](src/WithdrawalEscrow.sol#L148) is not in mixedCase

src/WithdrawalEscrow.sol#L148


 - [ ] ID-71
Parameter [FiRMSlashingModule.setMinDebt(uint256)._minDebt](src/FiRMSlashingModule.sol#L127) is not in mixedCase

src/FiRMSlashingModule.sol#L127


 - [ ] ID-72
Parameter [JDola.setYearlyRewardBudget(uint256)._yearlyRewardBudget](src/jDola.sol#L254) is not in mixedCase

src/jDola.sol#L254


 - [ ] ID-73
Variable [JDola.DBR](src/jDola.sol#L28) is not in mixedCase

src/jDola.sol#L28


 - [ ] ID-74
Variable [ERC20.INITIAL_CHAIN_ID](lib/solmate/src/tokens/ERC20.sol#L41) is not in mixedCase

lib/solmate/src/tokens/ERC20.sol#L41


 - [ ] ID-75
Variable [FiRMSlashingModule.JUNIOR_POOL](src/FiRMSlashingModule.sol#L23) is not in mixedCase

src/FiRMSlashingModule.sol#L23


 - [ ] ID-76
Parameter [FiRMSlashingModule.setGuardian(address)._guardian](src/FiRMSlashingModule.sol#L154) is not in mixedCase

src/FiRMSlashingModule.sol#L154


 - [ ] ID-77
Parameter [JDola.initialize(uint256,uint256)._dolaReserve](src/jDola.sol#L122) is not in mixedCase

src/jDola.sol#L122


 - [ ] ID-78
Function [ERC20.DOMAIN_SEPARATOR()](lib/solmate/src/tokens/ERC20.sol#L162-L164) is not in mixedCase

lib/solmate/src/tokens/ERC20.sol#L162-L164


 - [ ] ID-79
Parameter [WithdrawalEscrow.setWithdrawFee(uint256)._withdrawFeeBps](src/WithdrawalEscrow.sol#L152) is not in mixedCase

src/WithdrawalEscrow.sol#L152


 - [ ] ID-80
Parameter [FiRMSlashingModule.setPendingGov(address)._pendingGov](src/FiRMSlashingModule.sol#L145) is not in mixedCase

src/FiRMSlashingModule.sol#L145


 - [ ] ID-81
Parameter [JDola.setPendingGov(address)._gov](src/jDola.sol#L285) is not in mixedCase

src/jDola.sol#L285


 - [ ] ID-82
Parameter [WithdrawalEscrow.setGov(address)._gov](src/WithdrawalEscrow.sol#L163) is not in mixedCase

src/WithdrawalEscrow.sol#L163


 - [ ] ID-83
Variable [FiRMSlashingModule.DOLA](src/FiRMSlashingModule.sol#L25) is not in mixedCase

src/FiRMSlashingModule.sol#L25


 - [ ] ID-84
Parameter [WithdrawalEscrow.setExitWindow(uint256)._exitWindow](src/WithdrawalEscrow.sol#L157) is not in mixedCase

src/WithdrawalEscrow.sol#L157


 - [ ] ID-85
Parameter [JDola.setOperator(address)._operator](src/jDola.sol#L277) is not in mixedCase

src/jDola.sol#L277


 - [ ] ID-86
Parameter [LinearInterpolationDelayModel.setMaxDelay(uint96)._maxDelay](src/LinearInterpolationDelayModel.sol#L43) is not in mixedCase

src/LinearInterpolationDelayModel.sol#L43


 - [ ] ID-87
Parameter [LinearInterpolationDelayModel.setMinDelay(uint96)._minDelay](src/LinearInterpolationDelayModel.sol#L37) is not in mixedCase

src/LinearInterpolationDelayModel.sol#L37


 - [ ] ID-88
Parameter [JDola.setDolaReserve(uint256)._dolaReserve](src/jDola.sol#L230) is not in mixedCase

src/jDola.sol#L230


 - [ ] ID-89
Parameter [LinearInterpolationDelayModel.setMaxDelayThresholdBps(uint16)._maxDelayThresholdBps](src/LinearInterpolationDelayModel.sol#L49) is not in mixedCase

src/LinearInterpolationDelayModel.sol#L49


 - [ ] ID-90
Variable [FiRMSlashingModule.DBR](src/FiRMSlashingModule.sol#L24) is not in mixedCase

src/FiRMSlashingModule.sol#L24


 - [ ] ID-91
Parameter [JDola.initialize(uint256,uint256)._dbrReserve](src/jDola.sol#L122) is not in mixedCase

src/jDola.sol#L122


 - [ ] ID-92
Parameter [FiRMSlashingModule.setMaxCollateralValue(uint256)._maxCollateralValue](src/FiRMSlashingModule.sol#L117) is not in mixedCase

src/FiRMSlashingModule.sol#L117


 - [ ] ID-93
Variable [ERC20.INITIAL_DOMAIN_SEPARATOR](lib/solmate/src/tokens/ERC20.sol#L43) is not in mixedCase

lib/solmate/src/tokens/ERC20.sol#L43


 - [ ] ID-94
Parameter [JDola.setDbrReserve(uint256)._dbrReserve](src/jDola.sol#L220) is not in mixedCase

src/jDola.sol#L220


 - [ ] ID-95
Parameter [JDola.setMaxYearlyRewardBudget(uint256)._max](src/jDola.sol#L241) is not in mixedCase

src/jDola.sol#L241


## too-many-digits
Impact: Informational
Confidence: Medium
 - [ ] ID-96
[FixedPointMathLib.sqrt(uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227) uses literals with too many digits:
	- [! y_sqrt_asm_0 < 0x1000000000000000000](lib/solmate/src/utils/FixedPointMathLib.sol#L180-L183)

lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227


 - [ ] ID-97
[FixedPointMathLib.sqrt(uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227) uses literals with too many digits:
	- [! y_sqrt_asm_0 < 0x10000000000000000000000000000000000](lib/solmate/src/utils/FixedPointMathLib.sol#L176-L179)

lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227


 - [ ] ID-98
[FixedPointMathLib.sqrt(uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227) uses literals with too many digits:
	- [! y_sqrt_asm_0 < 0x10000000000](lib/solmate/src/utils/FixedPointMathLib.sol#L184-L187)

lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227


 - [ ] ID-99
[SafeTransferLib.safeApprove(ERC20,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L94-L123) uses literals with too many digits:
	- [mstore(uint256,uint256)(freeMemoryPointer_safeApprove_asm_0,0x095ea7b300000000000000000000000000000000000000000000000000000000)](lib/solmate/src/utils/SafeTransferLib.sol#L107)

lib/solmate/src/utils/SafeTransferLib.sol#L94-L123


 - [ ] ID-100
[SafeTransferLib.safeTransfer(ERC20,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L63-L92) uses literals with too many digits:
	- [mstore(uint256,uint256)(freeMemoryPointer_safeTransfer_asm_0,0xa9059cbb00000000000000000000000000000000000000000000000000000000)](lib/solmate/src/utils/SafeTransferLib.sol#L76)

lib/solmate/src/utils/SafeTransferLib.sol#L63-L92


 - [ ] ID-101
[SafeTransferLib.safeTransferFrom(ERC20,address,address,uint256)](lib/solmate/src/utils/SafeTransferLib.sol#L30-L61) uses literals with too many digits:
	- [mstore(uint256,uint256)(freeMemoryPointer_safeTransferFrom_asm_0,0x23b872dd00000000000000000000000000000000000000000000000000000000)](lib/solmate/src/utils/SafeTransferLib.sol#L44)

lib/solmate/src/utils/SafeTransferLib.sol#L30-L61


 - [ ] ID-102
[FixedPointMathLib.sqrt(uint256)](lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227) uses literals with too many digits:
	- [! y_sqrt_asm_0 < 0x1000000](lib/solmate/src/utils/FixedPointMathLib.sol#L188-L191)

lib/solmate/src/utils/FixedPointMathLib.sol#L164-L227


