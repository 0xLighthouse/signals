# Board Incentives

**Board Incentives** reward supporters of accepted initiatives, with earlier participation receiving a larger share.

## Overview

Incentives are board-wide reward pools funded by a DAO or board owner. They complement initiative-specific bounties by rewarding participation across all accepted initiatives on a board.

| Feature | Bounties | Incentives |
|---------|----------|------------|
| **Funding Source** | External contributors | DAO/board owner |
| **Scope** | Per-initiative | Board-wide |
| **Token Support** | Multiple tokens | Single reward token |
| **Distribution** | Proportional to lock amount | Time-weighted by lock timing |
| **Claiming** | Manual (not implemented yet) | Auto-claimed on redemption |

## How It Works

- A DAO deploys and funds an `IncentivesPool`.
- The pool owner approves boards with a budget and per-initiative cap.
- The board owner calls `setIncentivesPool` **before** `boardOpenAt`.
- When supporters lock tokens, Signals credits the pool using time buckets.
- When supporters redeem after acceptance, rewards are claimed automatically.

## Weighting Model

Incentives use a bucketed time-weighted model:

- Lock credits are grouped into time buckets starting from `boardOpenAt`.
- `incentiveParametersWAD` defines a curve that is interpolated into bucket multipliers.
- Earlier buckets receive higher multipliers, so early supporters earn more.

**Note:** `Exponential` incentives are not implemented yet; `Linear` is the only supported curve type.

## Practical Notes

- Incentives are non-blocking; initiatives can be accepted even if the pool is depleted.
- Rewards are paid from the board’s remaining budget in the pool.
- Claims are handled during redemption to avoid extra transactions for supporters.

## Related Docs

- [Incentives Configuration Reference](/reference/incentives-configuration)
- [Bounties Feature](/features/bounties)
- [Lock Positions](/reference/locked-token-nfts)
