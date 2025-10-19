# Bounties

**Bounties** are external rewards that anyone can contribute towards a specific initiatives to incentivize support and successful outcomes.

Please note: Bounties are NOT the same as Board Incentives. [more here](#TODO).

## How a bounty work

```sh

- Any one can add an allowlisted token as a bounty
- Based on the a ratio the bounty will be split towards (initative/supporters/protocol)
- Bounties have a special feature where it can explire if the initiative does not happen within a nominted window

eg. I will contributed 100k if this Initative is actioned in the next 24hrs.

- If the initative is accepted the Bounty is sent based on the terms
- If the terms elaspe (say its now 34 hrs and it not accepted the user who proposed the bounty can withdraw 100% of their funds)
```

### 1. Adding a Bounty

Anyone can add a bounty to an initiative by:

1. Choosing an initiative to sponsor
2. Selecting a whitelisted ERC20 token
3. Setting the bounty amount
4. Optionally setting expiration timestamp
5. Optionally adding conditions (e.g., "must be accepted by date X")
6. Transferring tokens to the Bounties contract

**Example:**

```solidity
// Sponsor adds 10,000 USDC bounty to initiative #5
// Expires in 30 days, no special conditions
bounties.addBounty(
    5,                                    // initiativeId
    address(usdcToken),                   // token address
    10_000 * 1e6,                         // amount (10k USDC)
    block.timestamp + 30 days,            // expiresAt
    IBounties.Conditions.NONE             // terms
);
```

### 2. Distribution When Initiative is Accepted

When a board owner accepts an initiative, the Bounties contract automatically distributes all non-expired bounties according to the configured splits:

**Default Split:**

- **Protocol Fee**: 10% → Protocol treasury
- **Voter Rewards**: 70% → Supporters proportionally by lock amount
- **Board Treasury**: 20% → Board owner's treasury

The split percentages and receiver addresses are configurable by the Bounties contract owner.

### 3. Claiming Rewards

Supporters can:

- **Preview rewards**: Check how much they'd receive from an initiative's bounties
- **Claim via balances**: Rewards accumulate in the supporter's balance within the Bounties contract
- **Withdraw**: Transfer accumulated rewards to their wallet

## Smart Contract Architecture

### Bounties.sol

Core contract managing bounty contributions and distributions.

**Key Data Structures:**

```solidity
struct Bounty {
    uint256 initiativeId;      // Initiative this bounty is for
    IERC20 token;              // Token address for bounty
    uint256 amount;            // Total bounty amount
    uint256 paid;              // Amount already paid out
    uint256 refunded;          // Amount refunded to contributor
    uint256 expiresAt;         // Expiration timestamp (0 = no expiry)
    address contributor;       // Who added this bounty
    Conditions terms;          // Special conditions for payout
}

enum Conditions {
    NONE,                                  // No special conditions
    ACCEPTED_ON_OR_BEFORE_TIMESTAMP       // Must be accepted by deadline
}
```

**State Variables:**

```solidity
// Reference to Signals contract
ISignals public signalsContract;

// Token registry for whitelisted tokens
TokenRegistry public registry;

// Distribution splits: [protocol, voters, treasury]
mapping(uint256 => uint256[3]) public allocations;  // version => splits
mapping(uint256 => address[3]) public receivers;    // version => addresses

// All bounties
mapping(uint256 => Bounty) public bounties;

// Bounties by initiative
mapping(uint256 => uint256[]) public bountiesByInitiative;

// Supporter balances: supporter => token => amount
mapping(address => mapping(address => uint256)) public balances;

// Current version of splits configuration
uint256 public version;

// Total number of bounties created
uint256 public bountyCount;
```

### Key Functions

#### Adding Bounties

```solidity
/**
 * @notice Add a bounty to an initiative
 * @dev Token must be whitelisted in TokenRegistry
 * @dev Transfers tokens from sender to contract immediately
 *
 * @param _initiativeId The initiative to sponsor
 * @param _token ERC20 token address (must be whitelisted)
 * @param _amount Amount of tokens to contribute
 * @param _expiresAt Optional expiration timestamp (0 for no expiry)
 * @param _terms Conditions for payout (NONE or ACCEPTED_ON_OR_BEFORE_TIMESTAMP)
 */
function addBounty(
    uint256 _initiativeId,
    address _token,
    uint256 _amount,
    uint256 _expiresAt,
    Conditions _terms
) external payable;
```

**Requirements:**

- Initiative must exist
- Token must be whitelisted in registry
- Caller must have sufficient balance and allowance
- Tokens transferred immediately upon adding bounty

#### Viewing Bounties

```solidity
/**
 * @notice Get aggregated bounties for an initiative
 * @dev Sums bounties by token address, excludes expired
 * @dev Note: This is not gas-efficient, for view-only use
 *
 * @param _initiativeId The initiative to query
 * @return tokens Array of token addresses with bounties
 * @return amounts Array of total amounts per token
 * @return expiredCount Number of expired bounties
 */
function getBounties(uint256 _initiativeId)
    external
    view
    returns (
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 expiredCount
    );
```

#### Previewing Rewards

```solidity
/**
 * @notice Calculate potential voter rewards for a lock position
 * @dev Shows how much a supporter would earn from bounties
 * @dev Note: Simplified calculation, mixes token denominations
 *
 * @param _initiativeId The initiative to check
 * @param _tokenId The lock position NFT ID
 * @return Estimated reward amount (across all bounty tokens)
 */
function previewRewards(
    uint256 _initiativeId,
    uint256 _tokenId
) external view returns (uint256);
```

**Calculation:**

```
voterShare = lockAmount / totalLocked
voterRewards = totalBounties * voterAllocation% * voterShare
```

#### Owner Functions

```solidity
/**
 * @notice Update distribution splits and receiver addresses
 * @dev Only callable by contract owner
 * @dev Creates new version, doesn't affect existing distributions
 *
 * @param _allocations [protocolFee, voterRewards, treasuryShare] (must sum to 100)
 * @param _receivers [protocolAddress, voterPoolAddress, treasuryAddress]
 */
function updateSplits(
    uint256[3] memory _allocations,
    address[3] memory _receivers
) external onlyOwner;

/**
 * @notice Get configuration for a specific version
 *
 * @param _version Version number to query
 * @return version Current version number
 * @return allocations Split percentages for that version
 * @return receivers Receiver addresses for that version
 */
function config(uint256 _version)
    external
    view
    returns (
        uint256 version,
        uint256[3] memory allocations,
        address[3] memory receivers
    );
```

#### Internal Distribution

```solidity
/**
 * @notice Distribute bounties when initiative is accepted
 * @dev Called automatically by Signals contract
 * @dev Splits bounties according to current version config
 * @dev Only non-expired bounties are distributed
 *
 * @param _initiativeId The accepted initiative
 */
function handleInitiativeAccepted(uint256 _initiativeId) external;

/**
 * @notice Handle initiative expiration
 * @dev Called automatically by Signals contract
 * @dev Flags expired bounties for refund
 *
 * @param _initiativeId The expired initiative
 */
function handleInitiativeExpired(uint256 _initiativeId) external;
```

## Integration with Signals

The Signals contract notifies the Bounties contract about initiative lifecycle events:

```solidity
// In Signals.sol
function acceptInitiative(uint256 initiativeId) external {
    // ... acceptance logic

    // Notify bounties contract to distribute rewards
    if (address(bounties) != address(0)) {
        try bounties.handleInitiativeAccepted(initiativeId) {
            // Bounties distributed
        } catch {
            // Non-blocking: continue even if bounty distribution fails
        }
    }
}
```

## User Flows

### Flow 1: Sponsor Adds Bounty

1. Sponsor identifies an initiative they want to support (e.g., Initiative #42)
2. Sponsor checks if their preferred token is whitelisted
3. Sponsor approves Bounties contract to spend tokens
4. Sponsor calls `addBounty(42, tokenAddress, 10000e18, expiryTime, Conditions.NONE)`
5. Tokens are transferred to contract immediately
6. `BountyAdded` event emitted
7. Initiative page now shows increased bounty total

### Flow 2: Initiative Gets Accepted with Bounties

1. Initiative #42 has accumulated bounties:
   - 10,000 USDC from Sponsor A
   - 5,000 DAI from Sponsor B
   - 1 ETH from Sponsor C
2. Board owner accepts Initiative #42
3. Signals contract calls `bounties.handleInitiativeAccepted(42)`
4. Bounties contract:
   - Calculates total bounty value per token
   - Applies splits (10% protocol, 70% voters, 20% treasury)
   - Updates balances for protocol, voter pool, and treasury
5. `BountyPaidOut` event emitted for each bounty
6. Supporters can now see their claimable balances

### Flow 3: Supporter Claims Rewards

1. Alice supported Initiative #42 with 100 tokens (10% of total support)
2. Initiative was accepted with 10,000 USDC in bounties
3. Alice checks her potential rewards: `previewRewards(42, aliceTokenId)`
4. Result: 700 USDC (10% of 70% voter share)
5. On acceptance, Alice's balance automatically updated:
   - `balances[alice][USDC] += 700e6`
6. Alice withdraws: transfers from her balance to her wallet
7. `RewardClaimed` event emitted

### Flow 4: Bounty Expires Before Acceptance

1. Sponsor adds bounty with `expiresAt = now + 30 days`
2. 35 days pass, initiative still pending
3. Board owner tries to accept initiative
4. Bounties contract:
   - Identifies expired bounty
   - Excludes from distribution
   - Marks for refund to contributor
5. Sponsor can call refund function to reclaim tokens
6. `BountyRefunded` event emitted

## Distribution Splits

### Default Configuration

```solidity
// Default split percentages (adjustable by owner)
allocations[1] = [10, 70, 20];  // [protocol, voters, treasury]

// Example with 10,000 token bounty:
// - Protocol receives: 1,000 tokens (10%)
// - Voters share: 7,000 tokens (70%) - split proportionally
// - Treasury receives: 2,000 tokens (20%)
```

### Versioned Configuration

The Bounties contract uses versioned configuration:

- Each `updateSplits()` call creates a new version
- Existing distributions use their creation version
- New bounties use the latest version
- Prevents retroactive changes to agreed-upon terms

**Example:**

```solidity
// Version 1: [10, 70, 20]
bounties.addBounty(1, token, 1000, 0, NONE);  // Uses v1

// Owner updates splits
bounties.updateSplits([5, 80, 15], receivers);  // Creates v2

// Version 2: [5, 80, 15]
bounties.addBounty(2, token, 1000, 0, NONE);  // Uses v2

// Initiative 1 accepted → distributes with v1 splits
// Initiative 2 accepted → distributes with v2 splits
```

## Token Whitelisting

Only tokens whitelisted in the `TokenRegistry` can be used for bounties. This prevents:

- Spam tokens flooding the system
- Malicious tokens with hooks
- Incompatible token standards
- Unbounded gas costs in distribution

**Adding Whitelisted Tokens:**

```solidity
// TokenRegistry.sol (owner only)
tokenRegistry.addToken(address(usdcToken));
tokenRegistry.addToken(address(daiToken));
```

### Edge Cases

#### Multiple Bounties Same Token

Bounties in the same token are aggregated:

```solidity
// Initiative #1
addBounty(1, USDC, 1000, ...);  // Bounty A
addBounty(1, USDC, 2000, ...);  // Bounty B
// Total USDC bounty: 3000
```

#### Expired Bounties

Expired bounties are:

- Excluded from `getBounties()` totals
- Not distributed on acceptance
- Flagged for refund to contributor

#### Withdrawn Lock Positions

Lock positions that have been redeemed:

- Are excluded from reward calculations
- Don't receive any bounty share
- Verified via `bond.withdrawn` flag

#### Empty Bounties

Initiatives with no bounties:

- Acceptance proceeds normally
- No distribution attempted
- Non-blocking design

### Precision and Rounding

```solidity
// Integer division may cause dust amounts
protocolAmount = (amount * allocation[0]) / 100;
voterAmount = (amount * allocation[1]) / 100;
treasuryAmount = (amount * allocation[2]) / 100;

// Potential dust: (amount - protocolAmount - voterAmount - treasuryAmount)
// Remains in contract, considered negligible
```

## Best Practices

### For Sponsors

1. **Check Token Whitelist**: Ensure your token is whitelisted before adding bounty
2. **Set Reasonable Expiry**: Give initiative enough time to be considered and accepted
3. **Use Conditions Wisely**: `ACCEPTED_ON_OR_BEFORE_TIMESTAMP` ensures time-sensitive outcomes
4. **Approve Sufficient Amount**: Approve exact bounty amount to Bounties contract
5. **Monitor Initiative**: Track progress and decide if you want to add more bounties

### For Board Owners

1. **Accept Promptly**: Don't let bounties expire unnecessarily
2. **Communicate Deadlines**: Let community know when initiatives will be reviewed
3. **Consider Bounty Amounts**: Larger bounties might indicate community priorities
4. **Configure Splits Fairly**: Balance protocol sustainability, voter rewards, and treasury needs

### For Supporters

1. **Check Bounties Before Supporting**: Higher bounties mean higher potential rewards
2. **Support Early**: Earlier support means larger share of the total locked amount
3. **Preview Rewards**: Use `previewRewards()` to estimate your potential earnings
4. **Claim Promptly**: While rewards don't expire, claiming frees up contract storage

### For Protocol Operators

1. **Whitelist Carefully**: Only add trusted, liquid tokens
2. **Update Splits Gradually**: Sudden changes can affect expectations
3. **Monitor Distribution**: Ensure distributions complete successfully
4. **Handle Expiries**: Implement efficient refund mechanisms for expired bounties

## Known Limitations

### Mixed Token Denominations

The `previewRewards()` function currently sums rewards across different token denominations:

```solidity
// Simplified calculation mixing USDC, DAI, ETH
totalRewards = usdcAmount + daiAmount + ethAmount
// This is only a rough estimate!
```

**Workaround**: Query bounties by token and calculate rewards per token separately.

### Gas Costs with Many Bounties

The `getBounties()` function is not gas-optimized:

```solidity
// O(n*m) complexity where n = bounties, m = unique tokens
// For view functions only, not meant for on-chain calls
```

**Workaround**: Use off-chain indexing for bounty aggregation in production UIs.

### Refund Mechanism (TODO)

Current implementation flags expired bounties but doesn't automatically refund:

```solidity
// TODO: Implement automatic refund for expired bounties
function handleInitiativeExpired(uint256 _initiativeId) external view {
    // Additional logic needed
}
```

**Future Enhancement**: Add `claimRefund()` function for contributors to reclaim expired bounty tokens.

## Future Enhancements

### Planned Features

1. **Milestone-Based Bounties**: Release bounties in stages as initiative progresses
2. **Conditional Payouts**: More sophisticated conditions (e.g., "if support > X", "if accepted + implemented")
3. **Bounty Pools**: Multiple sponsors contribute to a shared pool for an initiative
4. **Auto-Refunds**: Automatic return of tokens for expired bounties
5. **Per-Token Splits**: Different distribution splits for different token types
6. **Vesting Schedules**: Lock voter rewards for period to encourage long-term alignment
7. **Bounty Matching**: Protocol or DAO matches external bounty contributions

### Potential Improvements

1. **Gas Optimization**: Optimize `getBounties()` for on-chain calls
2. **Better Preview**: Per-token reward preview instead of mixed calculation
3. **Batch Operations**: Add multiple bounties in single transaction
4. **Bounty Transfer**: Allow bounty contributors to transfer their contribution to different initiative
5. **Clawback Mechanism**: Allow contributor to cancel bounty before acceptance under certain conditions

## FAQ

**Q: Can I add bounties to an already-accepted initiative?**
A: No, bounties can only be added to pending initiatives. Once accepted, no new bounties can be added.

**Q: What happens if my bounty expires?**
A: The bounty is excluded from distribution and flagged for refund. You can reclaim your tokens (refund mechanism coming soon).

**Q: Can I use any ERC20 token for bounties?**
A: No, only tokens whitelisted in the TokenRegistry can be used. This prevents spam and malicious tokens.

**Q: How are rewards split among supporters?**
A: Proportionally by the amount of tokens locked. If you locked 10% of total support, you receive 10% of the voter rewards pool.

**Q: What if the initiative is rejected?**
A: Currently, rejected initiatives don't trigger automatic refunds. Expiry mechanism and manual refund needed (enhancement planned).

**Q: Can splits be changed after I add a bounty?**
A: The splits are versioned. Your bounty uses the version active when it was added, so future changes don't affect it.

**Q: How do I claim my bounty rewards?**
A: Rewards are automatically added to your balance in the Bounties contract. You then withdraw from your balance to your wallet.

**Q: What prevents someone from adding a bounty with a malicious token?**
A: Only whitelisted tokens can be used, preventing malicious token contracts from being added.

## Related Documentation

- [Board Incentives](./incentives.md) - DAO-funded board-wide participation rewards
- [Lock Positions](../reference/locked-token-nfts.mdx) - How token locking works
- [Initiative Lifecycle](#TODO) - From proposal to acceptance
