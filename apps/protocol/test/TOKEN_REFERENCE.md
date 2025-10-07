# Test Token Reference

## Available Tokens in SignalsHarness

### Primary Tokens (for Signals boards)

#### `_tokenERC20` - Standard ERC20
- **Type**: `MockERC20`
- **Symbol**: `STD`
- **Decimals**: 18
- **Features**: Standard ERC20
- **Checkpoints**: ❌ No
- **Use Case**: Testing with regular ERC20 tokens, MinBalance requirements

#### `_tokenERC20Votes` - Governance Token
- **Type**: `MockERC20Votes` (extends ERC20Votes)
- **Symbol**: `vGOV`
- **Decimals**: 18
- **Features**: ERC20Votes, delegation, checkpoints
- **Checkpoints**: ✅ Yes
- **Use Case**: Testing with Governor-style tokens, MinBalanceAndDuration requirements
- **Methods**:
  - `getVotes(address)` - Current voting power
  - `getPastVotes(address, uint256 blockNumber)` - Historical voting power
  - `delegate(address)` - Delegate voting power
  - `getPastTotalSupply(uint256 blockNumber)` - Historical supply

### Incentive Tokens

#### `_usdc`
- **Type**: `MockERC20`
- **Symbol**: `USDC`
- **Decimals**: 6
- **Use Case**: Testing incentive payments

#### `_dai`
- **Type**: `MockERC20`
- **Symbol**: `DAI`
- **Decimals**: 18
- **Use Case**: Testing incentive payments


## Helper Functions

### For Standard ERC20

```solidity
// Deal tokens to test users
_dealDefaultTokens();

// Deal specific token
_dealToken(_tokenERC20);
```

### For ERC20Votes

```solidity
// Deal AND delegate (required for checkpoints)
_dealAndDelegateERC20Votes();

// Get config using ERC20Votes
ISignals.SignalsConfig memory config = getERC20VotesConfig();
```

## Usage Guidelines

### ✅ Use `_tokenERC20Votes` when:
- Testing MinBalanceAndDuration requirements
- Testing historical balance queries
- Testing governance integrations
- Testing checkpoint functionality

### ✅ Use `_tokenERC20` when:
- Testing standard ERC20 behavior
- Testing MinBalance requirements (no duration)
- Testing basic functionality
- Most general purpose tests

### ✅ Use `_usdc` / `_dai` when:
- Testing incentive payments
- Testing multi-token scenarios
- Testing different decimal places

## Example: New Test with Clear Token Type

```solidity
contract MyNewTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {
        // Use ERC20Votes for this test suite
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        signals = new Signals();
        signals.initialize(config);
        _dealAndDelegateERC20Votes();
    }

    function test_Something_WithCheckpoints() public {
        vm.roll(block.number + 10);
        uint256 pastVotes = _tokenERC20Votes.getPastVotes(_alice, block.number - 5);
        // ... test logic
    }
}
```

## Migration Plan

Existing tests continue using `_token` (aliased to `_tokenERC20`). New tests should use explicit naming:
- `_tokenERC20` for standard ERC20
- `_tokenERC20Votes` for governance tokens

This makes test intent crystal clear! 🎯
