# Test Harness: Governance Token Support

## Overview

The test harness now includes `MockERC20Votes`, an ERC20Votes token for testing proposal requirements that depend on historical token balances.

## Implementation

### MockERC20Votes

Located in: `test/mocks/MockERC20Votes.m.sol`

```solidity
contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Governance Token", "vGOV") ERC20Permit("Governance Token") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Required overrides for ERC20Votes
    function _update(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes) { ... }

    function nonces(address owner)
        public view override(ERC20Permit, Nonces) returns (uint256) { ... }
}
```

### Features

✅ **ERC20Votes** - OpenZeppelin's standard governance token
✅ **Checkpoints** - Tracks historical balances per block
✅ **Delegation** - Users must delegate to activate voting power
✅ **getPastVotes()** - Query voting power at past blocks
✅ **getPastTotalSupply()** - Query total supply at past blocks

## Usage in Tests

### Basic Setup

```solidity
contract MyTest is Test, SignalsHarness {
    function setUp() public {
        // Governance token is already available as _tokenERC20Votes
        _dealAndDelegateERC20Votes();
    }
}
```

### Helper Functions

#### `_dealAndDelegateERC20Votes()`

Mints tokens and delegates voting power to test users:
- Alice: 50,000 vGOV
- Bob: 100,000 vGOV
- Charlie: 25,000 vGOV
- Liquidity Provider: 100M vGOV

```solidity
function _dealAndDelegateERC20Votes() public {
    _tokenERC20Votes.mint(_alice, 50_000 * 1e18);
    vm.prank(_alice);
    _tokenERC20Votes.delegate(_alice); // Activate checkpoints!

    // ... same for bob, charlie, liquidityProvider
}
```

#### `getERC20VotesConfig()`

Returns a SignalsConfig using the governance token:

```solidity
ISignals.SignalsConfig memory config = getERC20VotesConfig();
// config.underlyingToken == address(_tokenERC20Votes)
```

## Example: Testing MinBalanceAndDuration

```solidity
function test_Propose_RequiresHoldingDuration() public {
    // Setup: Use governance token
    ISignals.SignalsConfig memory config = getERC20VotesConfig();
    Signals signals = deploySignalsWithConfig(config);

    // Set requirements: Must hold 50k tokens for 10 blocks
    ProposalRequirements memory reqs = ProposalRequirements({
        requirementType: ProposalRequirementType.MinBalanceAndDuration,
        minBalance: 50_000 * 1e18,
        minHoldingDuration: 10 // blocks
    });
    signals.setProposalRequirements(reqs);

    // Alice gets tokens NOW
    _tokenERC20Votes.mint(_alice, 50_000 * 1e18);
    vm.prank(_alice);
    _tokenERC20Votes.delegate(_alice);

    // Try to propose immediately - should FAIL (hasn't held long enough)
    vm.startPrank(_alice);
    vm.expectRevert("Tokens not held long enough");
    signals.proposeInitiative("My Proposal", "Description");

    // Roll forward 10 blocks
    vm.roll(block.number + 10);

    // Now should SUCCEED
    signals.proposeInitiative("My Proposal", "Description");
    vm.stopPrank();
}
```

## Token Comparison

### MockERC20 (_tokenERC20)
- **Use Case**: Standard ERC20, no checkpoints
- **Supports**: MinBalance requirements
- **Does NOT Support**: MinBalanceAndDuration

### MockERC20Votes (_tokenERC20Votes)
- **Use Case**: Governance/voting tokens
- **Supports**: MinBalance AND MinBalanceAndDuration requirements
- **Features**: Checkpoints, delegation, historical queries

## Checkpoint Mechanics

### Key Concepts

1. **Delegation Required** - Users must call `delegate(self)` to activate checkpoints
2. **Block-Based** - Checkpoints are per block, not timestamp
3. **getPastVotes()** - Query PAST block only (not current)
4. **Voting Power** - Equals balance only after delegation

### Example Timeline

```
Block 0: Alice mints 1000 tokens
         Alice.delegate(alice)
         ✅ getVotes(alice) = 1000

Block 5: Alice transfers 300 to Bob
         ✅ getVotes(alice) = 700
         ❌ getVotes(bob) = 0 (hasn't delegated)

Block 6: Bob.delegate(bob)
         ✅ getVotes(bob) = 300

Block 10: Query historical votes
          ✅ getPastVotes(alice, 0) = 1000
          ✅ getPastVotes(alice, 5) = 700
          ✅ getPastVotes(bob, 5) = 0
          ✅ getPastVotes(bob, 6) = 300
```

## Testing Best Practices

### ✅ DO

```solidity
// Mint AND delegate
_tokenERC20Votes.mint(alice, 1000 ether);
vm.prank(alice);
_tokenERC20Votes.delegate(alice);

// Query past blocks (not current)
vm.roll(block.number + 1);
uint256 pastVotes = _tokenERC20Votes.getPastVotes(alice, block.number - 1);
```

### ❌ DON'T

```solidity
// Don't forget to delegate
_tokenERC20Votes.mint(alice, 1000 ether);
// ❌ getVotes(alice) = 0 (not delegated!)

// Don't query current block
uint256 votes = _tokenERC20Votes.getPastVotes(alice, block.number);
// ❌ Reverts with ERC5805FutureLookup
```

## Integration with Signals

When implementing MinBalanceAndDuration requirements in Signals:

```solidity
// In Signals.sol
modifier meetsProposalRequirements() {
    if (reqs.requirementType == ProposalRequirementType.MinBalanceAndDuration) {
        // Try to check historical balance
        try IVotes(underlyingToken).getPastVotes(
            msg.sender,
            block.number - reqs.minHoldingDuration
        ) returns (uint256 pastBalance) {
            require(pastBalance >= reqs.minBalance, "Not held long enough");
        } catch {
            revert("Token doesn't support checkpoints");
        }
    }
    _;
}
```

## References

- [OpenZeppelin ERC20Votes](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes)
- [EIP-5805: Voting with delegation](https://eips.ethereum.org/EIPS/eip-5805)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/governance)
