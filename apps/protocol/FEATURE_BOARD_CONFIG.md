# Feature: Board Configuration - Proposal Requirements

## Overview

Add configurable requirements for who can propose initiatives on a Signals board.

## Requirements

### User Story

As a board administrator, I want to configure proposal requirements so that I can control who can create new initiatives based on token holdings.

### Acceptance Criteria

- [ ] Boards can configure proposal requirements at initialization
- [ ] Three requirement modes: None, MinBalance, MinBalanceAndDuration
- [ ] Requirements are enforced when proposing initiatives
- [ ] Requirements are IMMUTABLE after initialization (set once, never changed)
- [ ] Requirements are queryable via interface
- [ ] Full test coverage for all modes

## Design

### Enum: ProposalRequirementType

```solidity
enum ProposalRequirementType {
    None,                    // No requirements - anyone can propose
    MinBalance,              // Requires minimum token balance
    MinBalanceAndDuration    // Requires min balance held for min duration (future)
}
```

### Struct: ProposalRequirements

```solidity
struct ProposalRequirements {
    ProposalRequirementType requirementType;
    uint256 minBalance;           // Minimum tokens required (used by MinBalance & MinBalanceAndDuration)
    uint256 minHoldingDuration;   // Minimum blocks to hold tokens (used by MinBalanceAndDuration)
}
```

### Storage Variables

```solidity
/// @notice Configuration for proposal requirements (immutable after initialization)
ProposalRequirements public immutable proposalRequirements;
```

**Note**: Requirements are set during initialization and cannot be changed.

### Interface Changes

#### ISignals.sol

```solidity
// Add to ISignals interface

/// @notice Types of proposal requirements
enum ProposalRequirementType {
    None,
    MinBalance,
    MinBalanceAndDuration
}

/// @notice Configuration for proposal requirements
struct ProposalRequirements {
    ProposalRequirementType requirementType;
    uint256 minBalance;
    uint256 minHoldingDuration;
}

/// @notice Error when user doesn't meet proposal requirements
error ProposalRequirementsNotMet(string reason);

/// @notice Get current proposal requirements (immutable)
/// @return Current proposal requirements configuration
function getProposalRequirements() external view returns (ProposalRequirements memory);

/// @notice Check if an address meets proposal requirements
/// @param proposer Address to check
/// @return True if address can propose
function canPropose(address proposer) external view returns (bool);
```

### Implementation

#### 1. Add to Signals.sol

```solidity
/// @notice Configuration for proposal requirements
ProposalRequirements public proposalRequirements;

/// @notice Modifier to check proposal requirements
modifier meetsProposalRequirements() {
    ProposalRequirements memory reqs = proposalRequirements;

    if (reqs.requirementType == ProposalRequirementType.None) {
        // No requirements - anyone can propose
        _;
        return;
    }

    if (reqs.requirementType == ProposalRequirementType.MinBalance) {
        uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
        if (balance < reqs.minBalance) {
            revert ProposalRequirementsNotMet("Insufficient token balance");
        }
        _;
        return;
    }

    if (reqs.requirementType == ProposalRequirementType.MinBalanceAndDuration) {
        // Check balance first
        uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
        if (balance < reqs.minBalance) {
            revert ProposalRequirementsNotMet("Insufficient token balance");
        }

        // Check holding duration (requires governance token with checkpoints)
        // For now, we'll add interface check and graceful fallback
        try IVotes(underlyingToken).getPastVotes(msg.sender, block.number - reqs.minHoldingDuration)
            returns (uint256 pastBalance) {
            if (pastBalance < reqs.minBalance) {
                revert ProposalRequirementsNotMet("Tokens not held long enough");
            }
        } catch {
            // Token doesn't support checkpoints - revert with helpful message
            revert ProposalRequirementsNotMet("Token does not support holding duration checks");
        }
        _;
        return;
    }
}

/// @notice Get current proposal requirements
function getProposalRequirements() external view returns (ProposalRequirements memory) {
    return proposalRequirements;
}

/// @notice Update proposal requirements (owner only)
function setProposalRequirements(ProposalRequirements calldata requirements)
    external
    onlyOwner
{
    // Validate requirements
    if (requirements.requirementType == ProposalRequirementType.MinBalance) {
        if (requirements.minBalance == 0) {
            revert ProposalRequirementsNotMet("MinBalance must be greater than 0");
        }
    }

    if (requirements.requirementType == ProposalRequirementType.MinBalanceAndDuration) {
        if (requirements.minBalance == 0) {
            revert ProposalRequirementsNotMet("MinBalance must be greater than 0");
        }
        if (requirements.minHoldingDuration == 0) {
            revert ProposalRequirementsNotMet("MinHoldingDuration must be greater than 0");
        }
    }

    proposalRequirements = requirements;

    emit ProposalRequirementsUpdated(
        requirements.requirementType,
        requirements.minBalance,
        requirements.minHoldingDuration
    );
}

/// @notice Check if an address meets proposal requirements
function canPropose(address proposer) public view returns (bool) {
    ProposalRequirements memory reqs = proposalRequirements;

    if (reqs.requirementType == ProposalRequirementType.None) {
        return true;
    }

    if (reqs.requirementType == ProposalRequirementType.MinBalance) {
        uint256 balance = IERC20(underlyingToken).balanceOf(proposer);
        return balance >= reqs.minBalance;
    }

    if (reqs.requirementType == ProposalRequirementType.MinBalanceAndDuration) {
        uint256 balance = IERC20(underlyingToken).balanceOf(proposer);
        if (balance < reqs.minBalance) {
            return false;
        }

        // Try to check past balance
        try IVotes(underlyingToken).getPastVotes(proposer, block.number - reqs.minHoldingDuration)
            returns (uint256 pastBalance) {
            return pastBalance >= reqs.minBalance;
        } catch {
            return false; // Token doesn't support checkpoints
        }
    }

    return false;
}
```

#### 2. Update proposeInitiative functions

```solidity
function proposeInitiative(string memory _title, string memory _body)
    external
    meetsProposalRequirements  // ADD THIS
    hasSufficientTokens(proposalThreshold)
    hasValidInput(_title, _body)
{
    _addInitiative(_title, _body);
}

function proposeInitiativeWithLock(
    string memory _title,
    string memory _body,
    uint256 _amount,
    uint256 _lockDuration
)
    external
    meetsProposalRequirements  // ADD THIS
    hasSufficientTokens(proposalThreshold)
    hasValidInput(_title, _body)
    returns (uint256 tokenId)
{
    uint256 id = _addInitiative(_title, _body);
    tokenId = _addLock(id, msg.sender, _amount, _lockDuration);
}
```

#### 3. Update initialize function

Add to SignalsFactory initialization parameters:

```solidity
struct FactoryDeployment {
    address owner;
    address underlyingToken;
    uint256 proposalThreshold;
    uint256 acceptanceThreshold;
    uint256 maxLockIntervals;
    uint256 proposalCap;
    uint256 lockInterval;
    uint256 decayCurveType;
    uint256[] decayCurveParameters;
    ProposalRequirements proposalRequirements;  // ADD THIS
}
```

## Test Plan

### Unit Tests (test/signals/Signals.ProposalRequirements.t.sol)

```solidity
contract SignalsProposalRequirementsTest is Test, SignalsHarness {

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ProposalRequirements_DefaultNone() public {}
    function test_ProposalRequirements_InitializeWithMinBalance() public {}
    function test_ProposalRequirements_InitializeWithMinBalanceAndDuration() public {}

    /*//////////////////////////////////////////////////////////////
                        NONE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_None_AllowsAnyUser() public {}
    function test_Propose_None_AllowsZeroBalance() public {}

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalance_AllowsWhenMet() public {}
    function test_Propose_MinBalance_RevertsWhenNotMet() public {}
    function test_Propose_MinBalance_ChecksExactThreshold() public {}
    function test_CanPropose_MinBalance_ReturnsCorrectly() public {}

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE AND DURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalanceAndDuration_AllowsWhenMet() public {}
    function test_Propose_MinBalanceAndDuration_RevertsInsufficientBalance() public {}
    function test_Propose_MinBalanceAndDuration_RevertsInsufficientDuration() public {}
    function test_Propose_MinBalanceAndDuration_RevertsUnsupportedToken() public {}

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetProposalRequirements_Success() public {}
    function test_SetProposalRequirements_OnlyOwner() public {}
    function test_SetProposalRequirements_RevertsInvalidMinBalance() public {}
    function test_SetProposalRequirements_EmitsEvent() public {}

    /*//////////////////////////////////////////////////////////////
                        QUERY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetProposalRequirements_ReturnsCorrectly() public {}
    function test_CanPropose_ChecksCorrectly() public {}

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_WithLock_RespectRequirements() public {}
    function test_Propose_RequirementsIndependentFromThreshold() public {}
}
```

### Integration Tests

```solidity
contract SignalsProposalRequirementsIntegrationTest is Test, SignalsHarness {
    function test_Integration_ChangeRequirementsMidLifecycle() public {}
    function test_Integration_UserGainsBalanceCanPropose() public {}
    function test_Integration_UserLosesBalanceCannotPropose() public {}
}
```

## Implementation Phases

### Phase 1: Core Infrastructure ✅

- [ ] Add ProposalRequirementType enum to ISignals
- [ ] Add ProposalRequirements struct to ISignals
- [ ] Add storage variable to Signals.sol
- [ ] Add error types and events

### Phase 2: None & MinBalance Modes ✅

- [ ] Implement `meetsProposalRequirements` modifier for None mode
- [ ] Implement `meetsProposalRequirements` modifier for MinBalance mode
- [ ] Implement `setProposalRequirements` function
- [ ] Implement `getProposalRequirements` function
- [ ] Implement `canPropose` view function
- [ ] Update `proposeInitiative` functions
- [ ] Update factory initialization

### Phase 3: Testing (None & MinBalance) ✅

- [ ] Create Signals.ProposalRequirements.t.sol
- [ ] Test None mode
- [ ] Test MinBalance mode
- [ ] Test configuration functions
- [ ] Test query functions
- [ ] Integration tests

### Phase 4: MinBalanceAndDuration Mode (Optional) 🔮

- [ ] Add IVotes interface import
- [ ] Implement checkpoint checking in modifier
- [ ] Handle unsupported tokens gracefully
- [ ] Test with Governor-style tokens
- [ ] Test fallback behavior
- [ ] Document limitations

## Migration Strategy

### Backwards Compatibility

- Default to `ProposalRequirementType.None` for existing boards
- No breaking changes to existing functions
- Factory update required for new deployments

### Upgrade Path

1. Deploy updated Signals implementation
2. Deploy updated SignalsFactory
3. Existing boards continue with None mode
4. New boards can configure requirements at initialization
5. Existing boards can update via `setProposalRequirements`

## API Examples

### Creating a board with minimum balance requirement

```solidity
ProposalRequirements memory reqs = ProposalRequirements({
    requirementType: ProposalRequirementType.MinBalance,
    minBalance: 1000 * 1e18, // 1000 tokens
    minHoldingDuration: 0
});

ISignalsFactory.FactoryDeployment memory config = ISignalsFactory.FactoryDeployment({
    // ... other params
    proposalRequirements: reqs
});

address board = factory.create(config);
```

### Checking if user can propose

```solidity
bool canAlicePropose = signals.canPropose(alice);
if (!canAlicePropose) {
    // Show error to user
}
```

### Updating requirements

```solidity
ProposalRequirements memory newReqs = ProposalRequirements({
    requirementType: ProposalRequirementType.MinBalance,
    minBalance: 5000 * 1e18, // Increase to 5000 tokens
    minHoldingDuration: 0
});

signals.setProposalRequirements(newReqs); // Only owner
```

## Open Questions

1. **Should proposalThreshold be deprecated?**
   - Current: `proposalThreshold` is checked via `hasSufficientTokens` modifier
   - Proposal: Keep both? Or merge into ProposalRequirements?
   - Decision: Keep both - threshold is about ability to pay, requirements are about eligibility

2. **Should we validate token supports ERC20 interface?**
   - Could add check in setProposalRequirements
   - Trade-off: Extra gas vs safety

3. **Gas optimization for canPropose?**
   - Currently pure view, could cache results
   - Trade-off: Complexity vs gas savings

4. **Should MinBalanceAndDuration be in Phase 1?**
   - Requires IVotes interface
   - Limited to governance tokens
   - Recommendation: Start with None + MinBalance, add duration later

## Success Criteria

- [ ] All proposal requirement modes implemented
- [ ] 100% test coverage for new functionality
- [ ] No breaking changes to existing contracts
- [ ] Factory updated to support configuration
- [ ] Documentation complete
- [ ] Example usage in tests
