# Distributions Feature - Product Requirements Document

**Version:** 1.0
**Date:** 2025-10-09
**Status:** Draft

---

## Executive Summary

The Distributions feature rewards supporters of successful initiatives based on when they added their support, incentivizing early participation and improving signal quality in the Signals protocol. This mechanism complements the existing Contributions (formerly Incentives) system by providing board-wide participation rewards rather than initiative-specific bounties.

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

| Feature | Bounties | Distributions (NEW) |
|---------|----------|---------------------|
| **Funding Source** | External entities, sponsors | DAO treasury |
| **Scope** | Specific initiatives | Board-wide (all accepted initiatives) |
| **Token Support** | Multiple tokens per initiative | Single token per board |
| **Purpose** | Sponsored bounties for initiatives | General participation rewards |
| **Distribution** | Split: protocol/voters/treasury | 100% to supporters based on time |

### Key Terminology

- **Board**: A Signals governance instance (e.g., "Season 1")
- **Initiative**: A proposal within a board
- **Lock Position**: ERC721 token representing locked governance tokens supporting an initiative
- **Supporter**: Address that has locked tokens in support of an initiative
- **Distribution Pool**: Board-wide reward pool funded by DAO

---

## Distributions Feature Specification

### Core Mechanism

When a board owner accepts an initiative, the Distributions contract:

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
  - `0` = initiative creation time
  - `1` = initiative acceptance time
- `k` = decay rate parameter (e.g., 0.05, 0.08, 0.12, 0.15)
- `lockAmount` = tokens locked by supporter

**Example:**

Given an initiative accepted after 10 days with k=0.12:

| Supporter | Lock Amount | Lock Day | Time (t) | Weight Calculation | Final Weight |
|-----------|-------------|----------|----------|-------------------|--------------|
| Alice | 100 tokens | Day 0 | 0.0 | 100 * (1 - 0.12 * 0.0) | 100.0 |
| Bob | 100 tokens | Day 5 | 0.5 | 100 * (1 - 0.12 * 0.5) | 94.0 |
| Charlie | 100 tokens | Day 9 | 0.9 | 100 * (1 - 0.12 * 0.9) | 89.2 |
| **Total** | | | | | **283.2** |

If the distribution pool has 1,000 tokens:
- Alice receives: (100.0 / 283.2) * 1,000 = **353.1 tokens**
- Bob receives: (94.0 / 283.2) * 1,000 = **331.9 tokens**
- Charlie receives: (89.2 / 283.2) * 1,000 = **315.0 tokens**

---

## Technical Architecture

### Smart Contracts

#### 1. Distributions.sol (NEW)

Core contract managing the board-wide distribution pool and reward calculations.

**Key Data Structures:**
```solidity
struct DistributionPool {
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
- `initializePool()` - Setup distribution pool with token, amount, decay rate
- `addToPool()` - Add more tokens to existing pool
- `calculateDistributions()` - Calculate rewards when initiative accepted
- `claimRewards()` - Supporters claim their allocated rewards
- `previewRewards()` - View potential rewards before claiming

#### 2. IDistributions.sol (NEW)

Interface defining the Distributions contract API.

#### 3. Signals.sol (MODIFIED)

Integration points:
- Add optional `distributions` reference (similar to existing `incentives` pattern)
- Call `distributions.calculateDistributions(initiativeId)` in `acceptInitiative()`
- Emit events when distributions are triggered

#### 4. Bounties.sol (RENAMED from Incentives.sol)

Renamed to better distinguish from Distributions:
- `Incentives.sol` → `Bounties.sol`
- `IIncentives.sol` → `IBounties.sol`
- Updated all references throughout codebase

---

## User Flows

### Flow 1: DAO Sets Up Distribution Pool

1. Board owner deploys Distributions contract
2. Owner calls `initializePool(rewardToken, 1000000e18, 0.12e18)`
3. Owner approves and transfers reward tokens to contract
4. Pool is now active for all future accepted initiatives

### Flow 2: Supporter Earns Rewards

1. Alice locks 100 tokens supporting Initiative #1 on Day 0
2. Bob locks 100 tokens supporting Initiative #1 on Day 5
3. Board owner accepts Initiative #1 on Day 10
4. Signals contract calls `distributions.calculateDistributions(1)`
5. Distributions contract:
   - Calculates time weights for Alice (100.0) and Bob (94.0)
   - Allocates proportional shares from pool
   - Marks rewards as claimable
6. Alice calls `claimRewards(1)` → receives 353.1 reward tokens
7. Bob calls `claimRewards(1)` → receives 331.9 reward tokens

### Flow 3: Handling Multiple Lock Positions

1. Alice locks 50 tokens on Day 0
2. Alice locks another 50 tokens on Day 3
3. Initiative accepted on Day 10
4. Distributions calculates:
   - Lock 1: 50 * (1 - 0.12 * 0.0) = 50.0
   - Lock 2: 50 * (1 - 0.12 * 0.3) = 48.2
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
**Rationale:** Boards can operate without distributions, doesn't block core functionality

### 5. Linear Decay (Start Simple) ✅
**Decision:** Use linear decay curve initially, not exponential
**Rationale:** Simpler implementation, easier to reason about, can extend later

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

2. **Decay Rate Selection:** Which k values work best in practice?
   - Suggestion: A/B test with 0.08, 0.12, 0.15 in pilot boards

3. **Multiple Initiatives:** How to allocate pool across multiple accepted initiatives?
   - Current: Equal weight per initiative
   - Alternative: Proportional to total support received

4. **Expiration:** Should unclaimed rewards expire?
   - Current: No expiration
   - Alternative: 90-day claim window, then returned to treasury

---

## Appendix

### A. Related Systems

- **Bounties (formerly Incentives):** External bounties on specific initiatives
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
