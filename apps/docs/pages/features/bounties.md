# Bounties

**Bounties** let external contributors add ERC20 rewards to specific initiatives.

## How Bounties Work

- Tokens must be allowlisted via TokenRegistry.
- Contributors approve and add bounties with optional expiration/conditions.
- Splits are configured by the Bounties owner (protocol/supporters/treasury) and versioned.
- Intended behavior: distribution occurs on acceptance; expired bounties are excluded.

## Integration Status

Signals does not currently invoke the Bounties contract on acceptance or expiration. Distribution, reward claiming, and refunds are not triggered on-chain yet.

## Token Whitelisting

Only allowlisted ERC20 tokens can be used for bounties. TokenRegistry owner actions manage which tokens are allowed.

## Limitations

- Claim/withdraw functions are not implemented; balances are tracked only.
- `previewRewards` currently returns 0.
- `getBounties` is a view-only aggregation and may be expensive for large lists.

## References

- [Initiative Interactions Reference](/reference/initiative-interactions#adding-bounties)
- [addBounty Function Reference](/reference/initiative-functions/add-bounty)
