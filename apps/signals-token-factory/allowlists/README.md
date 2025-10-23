# Allowlist Format

`ExperimentToken` contracts verify Edge City residency using a Merkle tree. The allowlist data consumed by the Next.js API must follow this schema:

```json
{
  "root": "0x...",
  "proofs": {
    "5461": ["0x...", "0x..."],
    "7021": ["0x..."]
  }
}
```

- `root` is the Merkle root configured on-chain (see `ExperimentToken.setMerkleRoot`).
- Keys inside `proofs` are Edge City participant IDs as strings.
- Proof arrays contain sibling hashes (left/right ordering must match the hashing used when the root was computed, e.g. `keccak256(abi.encodePacked(id))` with pairwise sorting).

Expose the data to the interface by setting one of the following environment variables:

1. `EDGE_CITY_ALLOWLIST_PATH` — absolute or repo-relative path to a JSON file matching the schema above.
2. `EDGE_CITY_ALLOWLIST_JSON` — direct JSON string with the same shape (useful for small test sets).

Never commit real participant data. Generate environment-specific files (e.g. `edge-city.dev.json`) and ensure they are gitignored.

## Tooling

- `apps/signals-token-factory/scripts/sample-merkle.ts` demonstrates how to hash identifiers, construct the tree, and emit proof JSON. Run it with `pnpm dlx tsx apps/signals-token-factory/scripts/sample-merkle.ts` to regenerate `sample-edge-city.json`.
