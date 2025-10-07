# Test Suite Improvement Plan

## Overview

This document outlines the planned improvements to the Signals protocol test suite based on comparison with Harbor's comprehensive testing approach.

## Completed ✅

### 1. Test Organization

- ✅ Added section delimiters to all test files using Harbor's format
- ✅ Organized tests into logical groups:
  - Initialization Tests
  - Proposal Tests
  - Support & Locking Tests
  - Acceptance & State Transition Tests
  - Redemption Tests
  - Expiration Tests
  - Configuration Tests
  - Error Handling Tests

### 2. Code Cleanup

- ✅ Removed duplicate TODO comments in `Signals.t.sol`
- ✅ Replaced FIXME with explanatory note about separate test coverage
- ✅ Improved test naming consistency

## Planned Improvements (Prioritized)

### Priority 1: High Impact, Low Effort

#### Event Emission Tests (Signals.t.sol)

**Why**: Events are critical for off-chain systems. Harbor tests all events thoroughly.

- [ ] `test_ProposeInitiativeEmitsCorrectEvent()` - Verify all event parameters
- [ ] `test_SupportInitiativeEmitsCorrectEvent()` - Verify support event data
- [ ] `test_AcceptInitiativeEmitsCorrectEvent()` - Verify acceptance event
- [ ] `test_ExpireInitiativeEmitsCorrectEvent()` - Verify expiration event
- [ ] `test_RedeemEmitsCorrectEvent()` - Verify redemption event

**Implementation Notes**:

```solidity
function test_ProposeInitiativeEmitsCorrectEvent() public {
    vm.startPrank(_alice);
    _token.approve(address(signals), defaultConfig.proposalThreshold);

    vm.expectEmit(true, true, true, true);
    emit ISignals.InitiativeProposed(1, _alice, "Initiative 1", "Description 1");

    signals.proposeInitiative("Initiative 1", "Description 1");
    vm.stopPrank();
}
```

#### Balance Verification Tests

**Why**: Financial accuracy is paramount. Harbor consistently checks balances.

- [ ] `test_ContractBalanceMatchesLockedTokens()` - Verify contract holds exact locked amount
- [ ] `test_TotalLockedEqualsIndividualLocks()` - Sum of locks equals total
- [ ] `test_BalanceConsistencyAfterMultipleOps()` - Multiple ops maintain consistency

### Priority 2: Medium Impact, Medium Effort

#### Boundary Condition Tests

**Why**: Edge cases often reveal bugs. Harbor tests boundaries extensively.

- [ ] `test_ProposeWithExactThreshold()` - Exact minimum proposal amount
- [ ] `test_ProposeWithMaxLockIntervals()` - Maximum lock duration
- [ ] `test_ProposeAtProposalCap()` - At maximum proposals allowed
- [ ] `test_SupportWithMinimumAmount()` - Minimum support amount

#### State Transition Edge Cases

**Why**: State machines need thorough transition testing.

- [ ] `test_CannotSupportExpiredInitiative()` - Invalid state transition
- [ ] `test_CannotAcceptExpiredInitiative()` - Invalid state transition
- [ ] `test_CannotExpireAcceptedInitiative()` - Invalid state transition

#### NFT Transfer & Ownership Tests

**Why**: NFT transferability affects token economics and security.

- [ ] `test_TransferLockedNFT()` - Can locked NFTs be transferred?
- [ ] `test_RedeemAfterNFTTransfer()` - Who can redeem after transfer?
- [ ] `test_RedeemAsNonOwner()` - Should fail for non-owners
- [ ] `test_SupportMultipleTimesWithSameNFT()` - NFT reuse attempt

### Priority 3: High Impact, Higher Effort

#### Integration Tests

**Why**: Harbor's `test_MultipleNFTsInMarket()` reveals complex interaction bugs.

- [ ] `test_MultipleUsersProposingSimultaneously()` - Concurrent proposals
- [ ] `test_MultipleUsersSupportingWithDifferentDurations()` - Various lock periods
- [ ] `test_FullLifecycle_ProposeToRedeem()` - Complete happy path
- [ ] `test_MultipleInitiativesWithDifferentStates()` - State diversity
- [ ] `test_ConcurrentRedemptions()` - Race conditions

**Implementation Notes**:

```solidity
function test_MultipleUsersProposingSimultaneously() public {
    // Setup: Alice, Bob, Charlie all have sufficient tokens

    // Alice proposes
    vm.startPrank(_alice);
    _token.approve(address(signals), defaultConfig.proposalThreshold);
    signals.proposeInitiative("Alice's Initiative", "Description A");
    vm.stopPrank();

    // Bob proposes
    vm.startPrank(_bob);
    _token.approve(address(signals), defaultConfig.proposalThreshold);
    signals.proposeInitiative("Bob's Initiative", "Description B");
    vm.stopPrank();

    // Charlie proposes
    vm.startPrank(_charlie);
    // Should fail - charlie has no tokens
    vm.expectRevert(ISignals.InsufficientTokens.selector);
    signals.proposeInitiative("Charlie's Initiative", "Description C");
    vm.stopPrank();

    // Verify correct initiative count and states
    assertEq(signals.totalInitiatives(), 2);
    assertEq(signals.getInitiative(1).proposer, _alice);
    assertEq(signals.getInitiative(2).proposer, _bob);
}
```

#### Fuzz Tests

**Why**: Harbor uses fuzzing to test parameter space. Critical for finding edge cases.

- [ ] `testFuzz_ProposeWithVariousAmounts()` - Random valid amounts
- [ ] `testFuzz_SupportWithVariousAmounts()` - Random support amounts
- [ ] `testFuzz_RedeemAfterVariousTimePeriods()` - Random time warps
- [ ] `testFuzz_MultipleOperationsRandomOrder()` - Random operation sequences

**Implementation Notes**:

```solidity
function testFuzz_ProposeWithVariousAmounts(uint256 amount, uint256 duration) public {
    // Bound inputs to valid ranges
    amount = bound(amount, defaultConfig.proposalThreshold, 1_000_000 * 1e18);
    duration = bound(duration, 1, defaultConfig.maxLockIntervals);

    vm.startPrank(_alice);
    _token.approve(address(signals), amount * 2);

    uint256 balanceBefore = _token.balanceOf(_alice);
    signals.proposeInitiativeWithLock("Fuzz Initiative", "Description", amount, duration);
    uint256 balanceAfter = _token.balanceOf(_alice);

    // Verify tokens were locked
    assertEq(balanceBefore - balanceAfter, amount);

    // Verify lock details
    ISignals.TokenLock memory lock = signals.getTokenLock(1);
    assertEq(lock.tokenAmount, amount);
    assertEq(lock.lockDuration, duration);
    vm.stopPrank();
}
```

### Priority 4: Lower Priority

#### Time-Dependent Behavior Tests

- [ ] `test_VotingPowerDecayOverTime()` - If voting power decays
- [ ] `test_MultipleExpirationsAtDifferentTimes()` - Staggered expirations
- [ ] `test_LockExpiresBeforeAcceptance()` - Lock timing edge case

#### Gas Optimization Tests

- [ ] `test_Gas_RedeemMany()` - Batch redemption efficiency
- [ ] `test_Gas_ProposeWithAndWithoutLock()` - Compare gas usage
- [ ] `test_Gas_SupportMultipleInitiatives()` - Multi-support gas costs

#### Error Handling Tests

- [ ] `test_InvalidInitiativeId()` - Non-existent ID
- [ ] `test_SupportWithZeroAmount()` - Zero amount support
- [ ] `test_LockWithZeroDuration()` - Zero duration lock
- [ ] `test_ExceedMaxLockDuration()` - Duration too long
- [ ] `test_ProposeWithEmptyTitleOrDescription()` - Empty strings

## SignalsFactory Test Improvements

### Priority 1

- [ ] `test_SignalsCreatedEventEmitsCorrectly()` - Event emission
- [ ] `test_CreateMultipleSignals()` - Multiple deployments
- [ ] `test_CreatedContractIsClone()` - Verify clone pattern

### Priority 2

- [ ] `test_CreateWithDifferentParameters()` - Parameter variations
- [ ] `test_OnlyAllowERC20Tokens()` - Token validation
- [ ] `testFuzz_CreateWithVariousParameters()` - Fuzz factory params

## Incentives Test Improvements

### Priority 1

- [ ] `test_ClaimRewardsAfterAcceptance()` - Core reward mechanism
- [ ] `test_IncentiveAddedEventEmitsCorrectly()` - Event emission
- [ ] `test_ContractHoldsCorrectIncentiveAmount()` - Balance verification

### Priority 2

- [ ] `test_FullIncentiveFlow()` - End-to-end integration
- [ ] `test_AllocationDistribution()` - Verify allocation percentages
- [ ] `test_RevertAddIncentiveUnregisteredToken()` - Token registry validation

## Implementation Strategy

### Phase 1: Quick Wins (1-2 days)

1. Implement all event emission tests (Priority 1)
2. Add balance verification tests (Priority 1)
3. Fix remaining TODOs in existing tests

### Phase 2: Core Coverage (3-5 days)

1. Implement boundary condition tests (Priority 2)
2. Add state transition edge cases (Priority 2)
3. Implement NFT ownership tests (Priority 2)

### Phase 3: Advanced Testing (1-2 weeks)

1. Build integration test suite (Priority 3)
2. Implement fuzz tests (Priority 3)
3. Add gas optimization tests (Priority 4)

### Phase 4: Complete Coverage (Ongoing)

1. Implement remaining time-dependent tests
2. Add comprehensive error handling tests
3. Continuous fuzzing and invariant testing

## Testing Best Practices (from Harbor)

### 1. Always Check Balances

```solidity
uint256 balanceBefore = token.balanceOf(user);
// ... perform action ...
uint256 balanceAfter = token.balanceOf(user);
assertEq(balanceAfter - balanceBefore, expectedDelta);
```

### 2. Test Events Thoroughly

```solidity
vm.expectEmit(true, true, true, true); // Check all parameters
emit EventName(param1, param2, param3);
// ... trigger event ...
```

### 3. Use Descriptive Test Names

Follow Harbor's **PascalCase** naming convention:

- Format: `test_Topic_Intention` or `test_FunctionName_Condition`
- Examples from Harbor:
  - `test_SellBond_PriceNotMet`
  - `test_QuoteSellBondForHarborToken_Success`
  - `test_MultipleNFTsInMarket`
- Our convention:
  - `test_Propose_ExactThreshold` (not `test_propose_exactThreshold`)
  - `test_Support_RevertsWhenExpired` (not `test_support_revertsWhenExpired`)
  - `test_Redeem_AfterNFTTransfer` (not `test_redeem_afterNFTTransfer`)
  - `testFuzz_Propose_VariousAmountsAndDurations` (fuzz tests use `testFuzz_` prefix)

### 4. Group Related Tests

Use section comments to organize tests logically.

### 5. Test Happy Path AND Failure Cases

For every success case, test the corresponding failure cases.

### 6. Verify State Transitions

After state-changing operations, verify all affected state variables.

## Metrics for Success

### Coverage Targets

- [ ] Line coverage: >95%
- [ ] Branch coverage: >90%
- [ ] Function coverage: 100%

### Test Quality Targets

- [ ] All public functions have at least 3 tests (happy path, 2 failure cases)
- [ ] All events tested for correct emission
- [ ] All state transitions tested
- [ ] Balance changes verified in every financial operation
- [ ] At least 10 integration tests covering multi-user scenarios
- [ ] At least 5 fuzz tests covering parameter spaces

## Notes

### Key Learnings from Harbor

1. **Section Organization**: Makes tests easier to navigate and maintain
2. **Balance Verification**: Critical for financial contracts
3. **Event Testing**: Essential for off-chain integrations
4. **Integration Tests**: Reveal complex interaction bugs
5. **Fuzz Testing**: Finds edge cases manual tests miss

### Test Maintenance

- Review and update this document monthly
- Mark completed items with ✅
- Add new test categories as protocol evolves
- Regular refactoring to maintain test clarity
