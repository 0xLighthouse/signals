# Board Incentives

**Board Incentives** reward supporters of successful initiatives based on when they add their support, incentivizing early participation and improving signal quality in the Signals protocol.

## Overview

Board Incentives complement the existing Bounties system by providing **board-wide participation rewards** (managed by the DAO) rather than initiative-specific bounties (added by external sponsors).

### Bounties vs. Incentives

| Feature | Bounties | Incentives |
|---------|----------|------------|
| **Funding Source** | External entities, sponsors | DAO treasury |
| **Scope** | Specific initiatives | Board-wide (all accepted initiatives) |
| **Token Support** | Multiple tokens per initiative | Single token per board |
| **Purpose** | Sponsored bounties for initiatives | General participation rewards |
| **Distribution** | Split: protocol/voters/treasury | 100% to supporters based on time |
| **Management** | Anyone can add | Owner-controlled |

## Architecture: 1-to-Many Pool Design

The Incentives system uses a **1:M (one-to-many)** architecture where a single `IncentivesPool` can fund multiple boards.

### Benefits

**For DAOs:**
- **Quarterly bulk funding**: Pool once per quarter instead of per board
- **Better treasury management**: Reduced gas costs and operational overhead
- **Single pool funds entire season**: Simplified accounting

**For Community Leads:**
- **Create boards without funding approval**: Just need pool owner to approve their board
- **Empowered with existing pool resources**: Reduces friction for smaller initiatives
- **Faster board deployment**: No waiting for DAO treasury operations

### Security Model

Two-way handshake ensures safety:

1. **Board side**: Owner must call `setIncentivesPool()` before board opens (ensures fair configuration)
2. **Pool side**: Pool owner must call `approveBoard()` to whitelist the board (prevents unauthorized draining)

### Example Usage

```solidity
// DAO creates quarterly pool
IncentivesPool pool = new IncentivesPool();
pool.initializePool(rewardToken, 10_000_000 * 1e18, 10_000 * 1e18);

// Season 1 - Lead creates board
Signals season1 = new Signals();
season1.initialize(config);
season1.setIncentivesPool(address(pool)); // Must be before board opens

// DAO approves the board
pool.approveBoard(address(season1));

// Season 2 - Different lead, same pool
Signals season2 = new Signals();
season2.initialize(config);
season2.setIncentivesPool(address(pool));
pool.approveBoard(address(season2));

// Both boards now draw from same quarterly pool!
```

## Core Mechanism

When a board owner accepts an initiative, the IncentivesPool contract:

1. Calculates time-weighted reward shares for each supporter
2. Allocates proportional rewards from the pool (up to `maxRewardPerInitiative`)
3. Makes rewards claimable for supporters
4. Auto-claims rewards when supporters redeem their lock positions

## Reward Formula: Linear Decay

Early supporters earn more rewards using a linear decay function:

```
weight(t) = lockAmount * (1 - k * t)
```

**Where:**
- `t` = normalized time (0 to 1)
  - `0` = **board open time** (not initiative creation time)
  - `1` = initiative acceptance time
- `k` = decay rate parameter (e.g., 0.05, 0.08, 0.12, 0.15)
- `lockAmount` = tokens locked by supporter

**Important:** Time is measured from the **board open time**, not individual initiative creation times. This ensures fair participation and prevents gaming.

### Example

Given a board that opens on Day 0, and an initiative accepted on Day 10 with k=0.12:

| Supporter | Lock Amount | Lock Time | Time (t) | Weight Calculation | Final Weight |
|-----------|-------------|-----------|----------|-------------------|--------------|
| Alice | 100 tokens | Day 0 | 0.0 | 100 * (1 - 0.12 * 0.0) | 100.0 |
| Bob | 100 tokens | Day 5 | 0.5 | 100 * (1 - 0.12 * 0.5) | 94.0 |
| Charlie | 100 tokens | Day 9 | 0.9 | 100 * (1 - 0.12 * 0.9) | 89.2 |
| **Total** | | | | | **283.2** |

If the pool allocates 1,000 tokens for this initiative:
- Alice receives: (100.0 / 283.2) * 1,000 = **353.1 tokens**
- Bob receives: (94.0 / 283.2) * 1,000 = **331.9 tokens**
- Charlie receives: (89.2 / 283.2) * 1,000 = **315.0 tokens**

## Fair Launch: Board Open Time

To prevent gaming and ensure equitable participation, boards have a scheduled **opening time** configured via `boardOpensAt`:

### The Problem Without Board Open Time
- Bots/insiders can front-run proposals and lock tokens immediately
- Timezone disadvantages for global community
- Rewards speed/infrastructure over genuine participation
- Gaming incentivized over quality signal

### The Solution

```solidity
struct BoardConfig {
    // ... existing fields
    uint256 boardOpensAt;  // Timestamp when board opens for participation
}
```

**How It Works:**
1. Board owner announces: "Board opens on Jan 15, 2025 @ 12:00 PM UTC"
2. Community has time to prepare and discuss potential initiatives
3. At exactly 12:00 PM UTC, board opens - proposals can be submitted
4. All locks are measured from the board open time, not individual proposal times
5. This ensures everyone has fair opportunity regardless of timezone or speed

**Implementation:**
- `proposeInitiative()` and `supportInitiative()` require `block.timestamp >= boardOpensAt`
- Incentives calculation uses `boardOpensAt` as `t=0`, not initiative creation time
- Before board opens, contract reverts with `BoardNotYetOpen()` error

## Smart Contracts

### IncentivesPool.sol

Core contract managing board-wide incentives pool and reward calculations.

**Key State Variables:**

```solidity
// Pool configuration
struct PoolConfig {
    address token;                    // Reward token address
    uint256 totalAmount;              // Total tokens in pool
    uint256 allocated;                // Amount already allocated
    uint256 maxRewardPerInitiative;   // Max tokens per initiative
    bool enabled;                     // Pool active/inactive
}

// Approved boards (1:M relationship)
mapping(address => bool) public approvedBoards;
address[] public boardList;

// Storage: board => initiativeId => supporter => reward amount
mapping(address => mapping(uint256 => mapping(address => uint256))) public supporterRewards;

// Storage: board => initiativeId => calculated flag
mapping(address => mapping(uint256 => bool)) public distributionsCalculated;

// Storage: board => initiativeId => total weight
mapping(address => mapping(uint256 => uint256)) public initiativeTotalWeight;
```

**Key Functions:**

#### Owner Functions

```solidity
// Initialize pool (can only be called once)
function initializePool(
    address token,
    uint256 amount,
    uint256 maxRewardPerInitiative
) external onlyOwner;

// Approve a board to use this pool
function approveBoard(address board) external onlyOwner;

// Revoke board approval
function revokeBoard(address board) external onlyOwner;

// Add more tokens to pool
function addToPool(uint256 amount) external onlyOwner;

// Update max reward per initiative
function setMaxRewardPerInitiative(uint256 maxRewardPerInitiative) external onlyOwner;
```

#### Board Functions

```solidity
// Called by approved board when initiative is accepted
// Calculates time-weighted rewards for all supporters
function calculateIncentives(
    uint256 initiativeId,
    uint256 boardOpensAt,
    uint256 acceptanceTimestamp
) external onlyApprovedBoard returns (uint256 rewardAmount);
```

#### Supporter Functions

```solidity
// Claim allocated rewards (or auto-claimed on redeem)
function claimRewards(
    address board,
    uint256 initiativeId,
    address supporter
) external nonReentrant;

// Preview rewards for a supporter
function previewRewards(
    address board,
    uint256 initiativeId,
    address supporter
) external view returns (uint256);

// Get allocated rewards (0 if already claimed)
function getSupporterRewards(
    address board,
    uint256 initiativeId,
    address supporter
) external view returns (uint256);
```

#### View Functions

```solidity
// Get pool configuration
function getPoolConfig() external view returns (PoolConfig memory);

// Get available balance (total - allocated)
function getAvailablePoolBalance() external view returns (uint256);

// Check if distributions calculated for initiative
function isDistributionCalculated(
    address board,
    uint256 initiativeId
) external view returns (bool);

// Get total weight for initiative
function getInitiativeTotalWeight(
    address board,
    uint256 initiativeId
) external view returns (uint256);

// Get all approved boards
function getApprovedBoards() external view returns (address[] memory);

// Check if board is approved
function isBoardApproved(address board) external view returns (bool);
```

### Signals.sol Integration

The Signals contract integrates with IncentivesPool:

**Configuration:**

```solidity
struct BoardIncentives {
    bool enabled;              // Whether incentives active for this board
    uint256 curveType;         // Type of curve (0 = linear, 1 = exponential)
    uint256[] curveParameters; // Parameters for curve (e.g., [k] for linear)
}

struct BoardConfig {
    // ... existing fields
    uint256 boardOpensAt;              // When board opens
    BoardIncentives boardIncentives;   // Incentive configuration
}
```

**Integration Points:**

```solidity
// Owner sets incentives pool (must be before board opens)
function setIncentivesPool(address _incentivesPool) external onlyOwner;

// When accepting initiative, calculate incentives (non-blocking)
function acceptInitiative(uint256 initiativeId) external payable {
    // ... existing acceptance logic

    if (address(incentivesPool) != address(0)) {
        try incentivesPool.calculateIncentives(
            initiativeId,
            boardOpensAt,
            block.timestamp
        ) {} catch {
            // Silently continue - pool contract will emit events
        }
    }
}

// When redeeming, auto-claim rewards if available
function redeem(uint256 tokenId) public {
    // ... existing redemption logic

    if (address(incentivesPool) != address(0) && initiative.state == Accepted) {
        uint256 pendingRewards = incentivesPool.getSupporterRewards(
            address(this),
            lock.initiativeId,
            msg.sender
        );
        if (pendingRewards > 0) {
            incentivesPool.claimRewards(
                address(this),
                lock.initiativeId,
                msg.sender
            );
        }
    }
}
```

## User Flows

### Flow 1: DAO Sets Up Quarterly Pool

1. DAO creates IncentivesPool contract
2. DAO calls `initializePool(rewardToken, 10_000_000e18, 10_000e18)`
3. DAO approves and transfers reward tokens to pool
4. Pool is ready to support multiple boards throughout the quarter

### Flow 2: Board Lead Creates New Board

1. Lead creates board with `boardOpensAt` set to future date
2. Lead announces: "Season 2 board opens Jan 15, 2025 @ 12:00 PM UTC"
3. Lead calls `signals.setIncentivesPool(poolAddress)` (before board opens)
4. Lead requests DAO approval by submitting board address
5. DAO reviews and calls `pool.approveBoard(boardAddress)`
6. Board is now funded and ready to distribute incentives

### Flow 3: Supporter Earns Rewards

1. **Before Board Opens** - Users cannot propose or support
2. **Day 0, 12:00 PM UTC** - Board opens
3. Day 0, 12:05 PM - Alice creates Initiative #1, locks 100 tokens
4. Day 0, 12:10 PM - Bob locks 100 tokens supporting Initiative #1
5. Day 5, 3:00 PM - Charlie locks 100 tokens supporting Initiative #1
6. Day 10 - Board owner accepts Initiative #1
7. Signals calls `incentivesPool.calculateIncentives(1, boardOpensAt, now)`
8. IncentivesPool:
   - Calculates time weights from board open time
   - Alice & Bob: ~100 weight (both supported immediately)
   - Charlie: 94 weight (supported at t=0.5)
   - Allocates proportional shares from pool
9. Alice redeems her lock → auto-receives ~346 reward tokens
10. Bob redeems his lock → auto-receives ~346 reward tokens
11. Charlie redeems his lock → auto-receives ~308 reward tokens

### Flow 4: Multiple Lock Positions

1. Alice locks 50 tokens on Day 0
2. Alice locks another 50 tokens on Day 3
3. Initiative accepted on Day 10
4. IncentivesPool calculates:
   - Lock 1: 50 * (1 - 0.12 * 0.0) = 50.0
   - Lock 2: 50 * (1 - 0.12 * 0.3) = 48.2
   - Total Alice weight: 98.2
5. Alice redeems any lock → receives full combined rewards

## Design Decisions

### 1. Single Token per Pool ✅
**Decision:** Pool holds one reward token
**Rationale:** Simplifies DAO treasury management, reduces gas costs, clearer accounting

### 2. Multiple Locks Weighted Independently ✅
**Decision:** Each lock position evaluated separately based on creation time
**Rationale:** Accurately rewards early vs. late support, no gaming incentive

### 3. Optional Pool (Non-Blocking) ✅
**Decision:** Empty/disabled pool doesn't affect initiative acceptance
**Rationale:** Boards can operate without incentives, doesn't block core functionality

### 4. Board Open Time (Fair Launch) ✅
**Decision:** All time calculations from `boardOpensAt`, not initiative creation time
**Rationale:** Prevents gaming, ensures fair participation across timezones

### 5. Linear Decay (Start Simple) ✅
**Decision:** Use linear decay curve initially, extensible for exponential later
**Rationale:** Simpler implementation, easier to reason about

### 6. Auto-Claim on Redeem ✅
**Decision:** Automatically claim rewards when redeeming lock positions
**Rationale:** Better UX, one transaction instead of two, guaranteed reward distribution

### 7. 1:M Pool Architecture ✅
**Decision:** One pool can fund multiple boards
**Rationale:** Reduces DAO ops, empowers community leads, better capital efficiency

## Security Considerations

### Access Control
- Only pool owner can initialize pool, approve boards, and manage configuration
- Only approved boards can call `calculateIncentives()`
- Only authorized callers can trigger `claimRewards()` for supporters

### Reentrancy Protection
- `ReentrancyGuard` on `claimRewards()`
- Follows checks-effects-interactions pattern

### Edge Cases Handled
- Initiatives accepted immediately (t=0) → equal weight for all supporters
- Empty pool → returns 0, doesn't block acceptance
- Withdrawn lock positions → excluded from reward calculations
- Double-claiming → rewards marked as 0 after first claim
- Pool depletion → allocates remaining balance, continues accepting initiatives

### Front-Running Protection
- Reward calculation happens at acceptance time (not claim time)
- No advantage to claiming before/after others
- Board open time prevents front-running of proposals

## Events

```solidity
// Pool management
event PoolInitialized(address indexed token, uint256 amount, uint256 maxRewardPerInitiative);
event PoolConfigUpdated(uint256 maxRewardPerInitiative);
event PoolFunded(uint256 amount);
event BoardApproved(address indexed board);
event BoardRevoked(address indexed board);

// Reward distribution
event IncentivesCalculated(
    address indexed board,
    uint256 indexed initiativeId,
    uint256 totalWeight,
    uint256 rewardAmount,
    uint256 supporterCount
);
event RewardsClaimed(
    address indexed board,
    uint256 indexed initiativeId,
    address indexed supporter,
    uint256 amount
);
```

## Error Handling

```solidity
error PoolAlreadyInitialized();
error PoolNotInitialized();
error NotApprovedBoard();
error BoardAlreadyApproved();
error BoardNotApproved();
error NotAuthorized();
error AlreadyCalculated();
error NotCalculated();
error NoRewardsAvailable();
error InvalidConfiguration();
```

## Best Practices

### For DAOs

1. **Pool Sizing**: Start with 1-2% of total treasury per quarter
2. **Announcement Window**: Announce board opening minimum 7 days in advance
3. **Decay Rate Selection**: Test with k=0.08, 0.12, 0.15 to find optimal rate
4. **Board Approval**: Review board configuration before approving for pool access
5. **Monitoring**: Track pool depletion and top up quarterly

### For Board Owners

1. **Set Pool Before Opening**: Call `setIncentivesPool()` before `boardOpensAt`
2. **Clear Communication**: Announce board opening time with timezone
3. **Fair Configuration**: Use reasonable `boardOpensAt` to give community time
4. **Monitor Pool Balance**: Check pool has sufficient funds before accepting initiatives

### For Supporters

1. **Early Participation**: Support initiatives early for higher rewards
2. **Auto-Claim**: Rewards automatically claimed when you redeem
3. **Manual Claim**: Can manually claim anytime after acceptance if preferred
4. **Multiple Locks**: Each lock position weighted independently by time

## Future Enhancements

### Potential Features

1. **Multiple Decay Curves**: Add exponential decay, custom curve implementations
2. **Dynamic Pool Management**: Auto-replenish from treasury, budget forecasting
3. **Vesting Schedules**: Lock claimed rewards for alignment
4. **Reward Boosters**: Multipliers for specific behaviors, streak bonuses
5. **Cross-Board Rewards**: Loyalty rewards for repeat participants

## FAQ

**Q: Can a board use multiple incentive pools?**
A: No, each board can reference one pool, but one pool can fund many boards.

**Q: What happens if the pool runs out of funds?**
A: Acceptance continues normally, but 0 rewards allocated. Non-blocking design.

**Q: Can supporters lose rewards if they wait to claim?**
A: No, rewards are allocated at acceptance time and don't expire.

**Q: How does this differ from Bounties?**
A: Bounties are external/sponsor-funded per-initiative. Incentives are DAO-funded board-wide.

**Q: Can boards operate without incentives?**
A: Yes, incentives are optional. Boards work normally without a pool configured.

**Q: What prevents gaming with multiple lock positions?**
A: Each lock weighted by creation time. Later locks get proportionally less reward.

**Q: How do I know if a board has incentives?**
A: Check `signals.boardIncentives().enabled` and `signals.incentivesPool()` address.

## Related Documentation

- [Bounties Feature](./bounties.md)
- [Board Configuration](../configuration/board-config.md)
- [Lock Positions](./lock-positions.md)
