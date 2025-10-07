# Test Naming Convention

## Standard: `test_Topic_Intention`

All tests follow Harbor's **PascalCase** naming convention:

### Format

```
test_[Topic]_[Intention]
```

### Examples

#### Success Cases

- `test_Propose_WithoutLock` - Topic: Propose, Intention: WithoutLock
- `test_Accept_Success` - Topic: Accept, Intention: Success
- `test_Redeem_AfterAcceptance` - Topic: Redeem, Intention: AfterAcceptance
- `test_Config_DefaultValues` - Topic: Config, Intention: DefaultValues

#### Failure/Revert Cases

- `test_Propose_RevertsWithInsufficientTokens` - Clearly states it reverts
- `test_Redeem_RevertsBeforeAcceptance` - Revert condition
- `test_Accept_OnlyOwner` - Access control test
- `test_Expire_RevertsBeforeThreshold` - Time-based revert

#### Integration/Complex Tests

- `test_Redeem_MultipleLocks` - Testing multiple items
- `test_Redeem_PartialWithdrawal` - Complex scenario
- `test_ListPositions_ByOwner` - Query operation

#### Fuzz Tests

- `testFuzz_Propose_VariousAmountsAndDurations` - Use `testFuzz_` prefix
- `testFuzz_Support_VariousAmountsAndDurations`
- `testFuzz_Redeem_VariousTimePeriods`

### Topics (Common Patterns)

**Actions:**

- `Propose` - Proposing initiatives
- `Support` - Supporting initiatives
- `Accept` - Accepting initiatives
- `Expire` - Expiring initiatives
- `Redeem` - Redeeming tokens
- `Transfer` - Transferring NFTs
- `Claim` - Claiming rewards
- `Create` - Factory creation
- `AddIncentive` - Adding incentives

**State/Queries:**

- `Config` - Configuration values
- `Balance` - Balance checks
- `BondDetails` - Bond information
- `ListPositions` - Listing queries
- `PreviewRewards` - Calculation previews

### Intentions (Common Patterns)

**Success Scenarios:**

- `Success` - Generic success
- `WithLock` / `WithoutLock` - With/without locking
- `AfterAcceptance` / `AfterExpiration` - Time-based
- `Multiple` / `MultipleLocks` - Batch operations
- `DefaultValues` - Default state
- `Correct` / `CalculatesCorrectly` - Verification

**Failure Scenarios:**

- `Reverts[Condition]` - Revert with reason
- `RevertsWithInsufficientTokens`
- `RevertsBeforeAcceptance`
- `RevertsWhenExpired`
- `RevertsTwice`
- `OnlyOwner` - Access control

**Complex Scenarios:**

- `PartialWithdrawal`
- `MultipleUsersSimultaneously`
- `WithDifferentDurations`
- `ByOwner` - Filtered by user

## ❌ Avoid These Patterns

- ❌ `test_proposeInitiative` - camelCase
- ❌ `test_propose_initiative` - snake_case
- ❌ `testProposeInitiative` - No underscore
- ❌ `test_proposeRevertsInsufficientTokens` - Missing topic clarity

## ✅ Correct Patterns

- ✅ `test_Propose_WithLock` - Clear topic and intention
- ✅ `test_Propose_RevertsWithInsufficientTokens` - Clear failure case
- ✅ `test_Config_DefaultValues` - Clear what's being tested
- ✅ `testFuzz_Propose_VariousAmounts` - Fuzz test prefix

## Existing Test Updates

All existing tests have been updated to follow this convention:

### Before → After

- `test_defaultConfig` → `test_Config_DefaultValues`
- `test_proposeInitiative` → `test_Propose_WithoutLock`
- `test_proposeInitiativeWithLock` → `test_Propose_WithLock`
- `test_supportInitiative` → `test_Support_WithLockedTokens`
- `test_acceptInitiative` → `test_Accept_Success`
- `test_onlyOwnerCanAccept` → `test_Accept_OnlyOwner`
- `test_redemptions` → `test_Redeem_AfterAcceptance`
- `test_cannotRedeemBeforeAcceptance` → `test_Redeem_RevertsBeforeAcceptance`
- `test_cannotRedeemTwice` → `test_Redeem_RevertsTwice`
- `test_redeemMany` → `test_Redeem_MultipleLocks`
- `test_expireInitiative` → `test_Expire_AfterInactivity`
- `testFactoryDeployment` → `test_Create_DeploysSignalsContract`
- `test_initialState` → `test_Setup_InitialState`

## Benefits

1. **Scannable** - Easy to see what's being tested at a glance
2. **Consistent** - Matches Harbor's established pattern
3. **Groupable** - Tests naturally group by topic when sorted
4. **Clear Intent** - Intention is explicit in the name
5. **Professional** - Follows Solidity/Foundry best practices
