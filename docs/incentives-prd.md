# Incentives Feature - Product Requirements Document

**Version:** 1.0
**Date:** 2025-10-09
**Status:** Draft

---

## Executive Summary

The Incentives feature rewards supporters of successful initiatives based on when they added their support, incentivizing early participation and improving signal quality in the Signals protocol. This mechanism complements the existing Bounties system by providing board-wide participation rewards (managed by the board owner) rather than initiative-specific bounties (added by external sponsors).

---

## Background

### Problem Statement

Current Web3 governance systems face challenges with participation:

- Token holders lack motivation to participate beyond core passionate users
- Last-minute voting creates no room for discussion or amendment
- Early signal carries reputational risk, discouraging timely participation
- DAOs spend $1M+ annually on delegate programs with limited results

### Objectives

1. **Encourage Early Support**: Reward supporters who add their signal early in an initiative's lifecycle
2. **Improve Signal Quality**: Make the Signals system more effective at surfacing genuine community sentiment
3. **Simplify DAO Operations**: Single reward pool per board (season) rather than managing multiple pools
4. **Increase Participation**: Make the effort-reward ratio more favorable for general token holders

---

## System Overview

### Two Reward Mechanisms

| Feature | Bounties | Incentives (NEW) |
|---------|----------|------------------|
| **Funding Source** | External entities, sponsors | DAO treasury (board owner) |
| **Scope** | Specific initiatives | Board-wide (all accepted initiatives) |
| **Token Support** | Multiple tokens per initiative | Single token per board |
| **Purpose** | Sponsored bounties for initiatives | General participation rewards |
| **Distribution** | Split: protocol/voters/treasury | 100% to supporters based on time |
| **Management** | Anyone can add | Owner-controlled |

### Key Terminology

- **Board**: A Signals governance instance (e.g., "Season 1")
- **Board Open Time**: Scheduled timestamp when the board opens for participation
- **Initiative**: A proposal within a board
- **Lock Position**: ERC721 token representing locked governance tokens supporting an initiative
- **Supporter**: Address that has locked tokens in support of an initiative
- **Incentives Pool**: Board-wide reward pool funded and managed by board owner

---

## Incentives Feature Specification

### Core Mechanism

When a board owner accepts an initiative, the Incentives contract:

1. Calculates time-weighted reward shares for each supporter
2. Allocates proportional rewards from the board's distribution pool
3. Allows supporters to claim their rewards

### Reward Curve: Linear Decay

Early supporters earn more rewards using a linear decay function:

```
rewardWeight(t) = lockAmount * (1 - k * t)
```

**Where:**

- `t` = normalized time (0 to 1)
  - `0` = **board open time** (not initiative creation time)
  - `1` = initiative acceptance time
- `k` = decay rate parameter (e.g., 0.05, 0.08, 0.12, 0.15)
- `lockAmount` = tokens locked by supporter

**Important:** Time is measured from the **board open time**, not individual initiative creation times. This ensures fair participation and prevents gaming by early proposal submitters.

**Example:**

Given a board that opens on Day 0, and an initiative accepted on Day 10 with k=0.12:

| Supporter | Lock Amount | Lock Time | Time Since Board Open | Time (t) | Weight Calculation | Final Weight |
|-----------|-------------|-----------|----------------------|----------|-------------------|--------------|
| Alice | 100 tokens | Day 0 @ 12:00 PM | 0 days | 0.0 | 100 *(1 - 0.12* 0.0) | 100.0 |
| Bob | 100 tokens | Day 5 @ 12:00 PM | 5 days | 0.5 | 100 *(1 - 0.12* 0.5) | 94.0 |
| Charlie | 100 tokens | Day 9 @ 12:00 PM | 9 days | 0.9 | 100 *(1 - 0.12* 0.9) | 89.2 |
| **Total** | | | | | | **283.2** |

If the incentives pool has 1,000 tokens:

- Alice receives: (100.0 / 283.2) * 1,000 = **353.1 tokens**
- Bob receives: (94.0 / 283.2) * 1,000 = **331.9 tokens**
- Charlie receives: (89.2 / 283.2) * 1,000 = **315.0 tokens**

**Note:** All times measured from board open time (Day 0, 12:00 PM), ensuring fair participation.

---

## Technical Architecture

### Fair Launch Mechanism

To prevent gaming and ensure equitable participation, boards have a scheduled **opening time**:

**The Problem Without Board Open Time:**

- Bots/insiders can front-run proposals and lock tokens immediately
- Timezone disadvantages for global community
- Rewards speed/infrastructure over genuine participation
- Gaming incentivized over quality signal

**The Solution:**

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

### Smart Contracts

#### 1. Incentives.sol (NEW)

Core contract managing the board-wide incentives pool and reward calculations.

**Key Data Structures:**

```solidity
struct IncentivesPool {
    address token;              // reward token address
    uint256 totalAmount;        // total tokens in pool
    uint256 distributed;        // amount already distributed
    uint256 k;                  // decay rate (scaled by 1e18)
    bool enabled;               // pool active/inactive
}

// Per-initiative, per-supporter reward allocation
mapping(uint256 => mapping(address => uint256)) public supporterRewards;

// Track if distributions calculated for initiative
mapping(uint256 => bool) public distributionsCalculated;

// Total weight for each initiative (for proportional calculation)
mapping(uint256 => uint256) public initiativeTotalWeight;
```

**Key Functions:**

- `initializePool()` - Owner sets up incentives pool with token, amount, decay rate
- `addToPool()` - Owner adds more tokens to existing pool
- `calculateIncentives()` - Calculate rewards when initiative accepted
- `claimRewards()` - Supporters claim their allocated rewards
- `previewRewards()` - View potential rewards before claiming

#### 2. IIncentives.sol (NEW)

Interface defining the Incentives contract API.

#### 3. Signals.sol (MODIFIED)

Integration points:

- Add `boardOpensAt` to `BoardConfig`
- Add modifier to check board has opened before allowing proposals/support
- Add optional `incentives` reference (separate from `bounties`)
- Call `incentives.calculateIncentives(initiativeId)` in `acceptInitiative()`
- Pass `boardOpensAt` to incentives for reward calculation
- Emit events when incentives are calculated

**New Error:**

```solidity
error BoardNotYetOpen();
```

**Modified Modifier:**

```solidity
modifier isOpen() {
    if (block.timestamp < boardOpensAt) revert BoardNotYetOpen();
    if (boardState == BoardState.Closed) revert BoardClosedError();
    _;
}
```

#### 4. Bounties.sol (EXISTING - formerly named Incentives.sol)

Already renamed to distinguish from new Incentives feature:

- Handles external sponsor contributions to specific initiatives
- Supports multiple tokens per initiative
- Split distribution model (protocol/voters/treasury)

---

## User Flows

### Flow 1: Board Owner Sets Up Incentives Pool

1. Board owner creates board with `boardOpensAt` set to future date
2. Owner announces: "Season 2 board opens Jan 15, 2025 @ 12:00 PM UTC"
3. Owner deploys Incentives contract
4. Owner calls `initializePool(rewardToken, 1000000e18, 0.12e18)`
5. Owner approves and transfers reward tokens to contract
6. Pool is now active for all future accepted initiatives after board opens
7. Community can prepare and discuss potential initiatives before opening

### Flow 2: Supporter Earns Rewards

1. **Before Board Opens** - Users cannot propose or support (reverts with `BoardNotYetOpen()`)
2. **Day 0, 12:00 PM UTC** - Board opens
3. Day 0, 12:05 PM - Alice creates Initiative #1 and locks 100 tokens
4. Day 0, 12:10 PM - Bob locks 100 tokens supporting Initiative #1
5. Day 5, 3:00 PM - Charlie locks 100 tokens supporting Initiative #1
6. Day 10 - Board owner accepts Initiative #1
7. Signals contract calls `incentives.calculateIncentives(1, boardOpensAt)`
8. Incentives contract:
   - Calculates time weights from board open time:
     - Alice: locked 5 min after open → t ≈ 0.0003 → weight ≈ 100.0
     - Bob: locked 10 min after open → t ≈ 0.0007 → weight ≈ 99.99
     - Charlie: locked 5 days after open → t = 0.5 → weight = 94.0
   - Allocates proportional shares from pool
   - Marks rewards as claimable
9. Alice calls `claimRewards(1)` → receives ~340 reward tokens
10. Bob calls `claimRewards(1)` → receives ~340 reward tokens
11. Charlie calls `claimRewards(1)` → receives ~320 reward tokens

**Key Point:** Alice and Bob have nearly identical weights because they both supported soon after board opened, demonstrating fair launch.

### Flow 3: Handling Multiple Lock Positions

1. Alice locks 50 tokens on Day 0
2. Alice locks another 50 tokens on Day 3
3. Initiative accepted on Day 10
4. Distributions calculates:
   - Lock 1: 50 *(1 - 0.12* 0.0) = 50.0
   - Lock 2: 50 *(1 - 0.12* 0.3) = 48.2
   - Total Alice weight: 98.2
5. Alice claims once for all her positions combined

---

## Design Decisions

### 1. Single Token per Board ✅

**Decision:** Distribution pool holds one reward token (e.g., governance token)
**Rationale:** Simplifies DAO treasury management, reduces gas costs, clearer accounting

### 2. Multiple Locks Weighted Independently ✅

**Decision:** Each lock position evaluated separately based on creation time
**Rationale:** Accurately rewards early vs. late support from same user, no gaming incentive

### 3. Participation Threshold ✅

**Decision:** Reuse existing `BoardConfig.participantRequirements`
**Rationale:** No new threshold needed - supporters already qualified to lock tokens

### 4. Optional Pool (No Impact) ✅

**Decision:** Empty/disabled pool doesn't affect initiative acceptance
**Rationale:** Boards can operate without incentives, doesn't block core functionality

### 6. Board Open Time (Fair Launch) ✅

**Decision:** All time calculations measured from `boardOpensAt`, not initiative creation time
**Rationale:** Prevents gaming, ensures fair participation across timezones, rewards genuine engagement over speed

### 5. Linear Decay (Start Simple) ✅

**Decision:** Use linear decay curve initially, not exponential
**Rationale:** Simpler implementation, easier to reason about, can extend later

### 7. Board Open Time in Reward Formula ✅

**Decision:** Calculate lock weights as: `t = (lockTime - boardOpensAt) / (acceptTime - boardOpensAt)`
**Rationale:** Ensures all supporters are measured fairly from same starting point

### 6. Claim-Based Distribution ✅

**Decision:** Supporters must claim rewards (not auto-sent)
**Rationale:** Gas efficient, gives users control over timing, standard pattern

---

## Security Considerations

### 1. Reentrancy Protection

- Use `ReentrancyGuard` on `claimRewards()`
- Follow checks-effects-interactions pattern

### 2. Integer Overflow/Underflow

- Use Solidity 0.8+ built-in overflow checks
- Scale decay rate by 1e18 for precision

### 3. Access Control

- Only Signals contract can call `calculateDistributions()`
- Only pool owner can initialize/add to pool
- Only supporters can claim their own rewards

### 4. Edge Cases

- Handle initiatives accepted immediately (t=0)
- Prevent double-claiming rewards
- Handle withdrawn lock positions (exclude from rewards)
- Gracefully handle empty pool

### 5. Front-Running

- Reward calculation happens at acceptance time (not claim time)
- No advantage to claiming before/after others

---

## Testing Strategy

### Unit Tests

**Distributions.sol:**

- Pool initialization and configuration
- Linear decay calculation accuracy
- Single supporter reward calculation
- Multiple supporters reward distribution
- Multiple locks per supporter
- Edge cases (empty pool, zero duration, withdrawn locks)

**Integration Tests:**

- Full flow: propose → support → accept → calculate → claim
- Multiple initiatives in sequence
- Pool depletion scenarios
- Signals + Distributions interaction

**Gas Optimization Tests:**

- Calculate distributions for 1, 10, 50, 100 supporters
- Claim rewards gas costs
- Compare vs. Contributions mechanism

---

## Success Metrics

### Phase 1: Implementation (Weeks 1-2)

- [ ] Contracts deployed and tested
- [ ] Integration with Signals complete
- [ ] Test coverage >90%

### Phase 2: Launch (Month 1)

- [ ] First board uses distributions
- [ ] 3+ initiatives accepted with distributions
- [ ] Zero security incidents

### Phase 3: Adoption (Months 2-3)

- **Participation Increase:** 50%+ more unique supporters vs. boards without distributions
- **Early Support:** 40%+ of support added in first 50% of initiative lifecycle
- **Reward Claims:** 80%+ of allocated rewards claimed within 30 days

---

## Future Enhancements

### Phase 2 Features (Future Consideration)

1. **Multiple Decay Curves**
   - Add exponential decay option
   - Custom curve implementations
   - Per-board curve selection

2. **Dynamic Pool Management**
   - Auto-replenish from treasury
   - Pool analytics dashboard
   - Budget forecasting tools

3. **Vesting Schedules**
   - Lock claimed rewards for X period
   - Encourage long-term alignment

4. **Reward Boosters**
   - Multipliers for specific behaviors
   - Streak bonuses for consistent participation

5. **Cross-Board Distributions**
   - Rewards across multiple seasons
   - Loyalty rewards for repeat participants

---

## Open Questions

1. **Pool Sizing:** How should DAOs determine optimal pool size for a board?
   - Suggestion: Start with 1-2% of total treasury per season

2. **Board Open Time Announcement:** How far in advance should boards announce opening?
   - Suggestion: Minimum 7 days for community preparation and awareness

3. **Decay Rate Selection:** Which k values work best in practice?
   - Suggestion: A/B test with 0.08, 0.12, 0.15 in pilot boards

4. **Multiple Initiatives:** How to allocate pool across multiple accepted initiatives?
   - Current: Equal weight per initiative
   - Alternative: Proportional to total support received

5. **Expiration:** Should unclaimed rewards expire?
   - Current: No expiration
   - Alternative: 90-day claim window, then returned to treasury

---

## Appendix

### A. Related Systems

- **Bounties:** External bounties on specific initiatives (multi-token, sponsor-funded)
- **Incentives:** Board-wide participation rewards (single-token, owner-managed)
- **Signals Core:** Time-locked token positions supporting initiatives
- **Board Configuration:** Governance parameters per season

### B. References

- Original article: "Paid Incentives in Signals"
- Reward curve visualization: [See attached image]
- Signals technical design: [Previous documentation]

### C. Glossary

- **k parameter:** Decay rate controlling how quickly rewards decrease over time
- **Time-weighting:** Allocating more rewards to earlier actions
- **Lock position:** ERC721 NFT representing locked governance tokens
- **Board:** A governance instance/season in Signals protocol

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-09 | Initial PRD based on design discussions |

---

**Document Status:** Ready for Review
**Next Steps:**

1. Refactor Incentives → Contributions
2. Implement Distributions contracts
3. Write comprehensive tests
