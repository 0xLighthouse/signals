# Allowlist Format

`ExperimentToken` contracts verify Edge City residency using a Merkle tree. The allowlist data consumed by the Next.js API must follow this schema:

```json
{
  "root": "0x...",
  "proofs": {
    "5461": ["0x...", "0x..."],
    "7021": ["0x..."]
  },
  "meta": [
    {
      "participantId": "5461",
      "label": "participant-a",
      "weight": 1.0
    }
  ]
}
```

- `root` is the Merkle root configured on-chain (see `ExperimentToken.setMerkleRoot`).
- Keys inside `proofs` are **Edge City participant IDs as decimal strings** (e.g. `"5461"`, not `"0x..."`).
- Proof arrays contain sibling hashes following OpenZeppelin's StandardMerkleTree convention.
- Each leaf is computed as `keccak256(abi.encodePacked(uint256(participantId)))` to match the on-chain verification.
- The optional `meta` array provides human-readable context (labels, weights) that doesn't affect the tree structure.

## Environment Configuration

Expose the allowlist data to the interface by setting one of:

1. **`EDGE_CITY_ALLOWLIST_PATH`** — absolute or repo-relative path to a JSON file (recommended for development)
2. **`EDGE_CITY_ALLOWLIST_JSON`** — inline JSON string (useful for small test sets or CI environments)

Example:
```bash
EDGE_CITY_ALLOWLIST_PATH=apps/signals-token-factory/allowlists/edge-city.json
```

**Security:** Never commit real participant data to version control. Generate environment-specific files (e.g. `edge-city.dev.json`) and ensure they are gitignored.

## Tooling

The Merkle tree generation now uses battle-tested utilities from `packages/shared/merkle`:

- **`buildMerkleTree(participants)`** — constructs a tree using OpenZeppelin's `StandardMerkleTree`
- **`verifyProof(participantId, proof, root)`** — validates proofs without rebuilding the tree
- **`hashParticipantId(id)`** — produces leaves matching Solidity's `keccak256(abi.encodePacked(uint256))`

### Generating Allowlists

Run the sample generator to see the tooling in action:
```bash
pnpm dlx tsx apps/signals-token-factory/scripts/sample-merkle.ts
```

This regenerates `sample-edge-city.json` with:
- Proofs keyed by **decimal participant IDs**
- Automatic proof verification before writing
- Metadata showing labels and weights

For production allowlists, adapt the script to:
1. Load real Edge City participant IDs from your source of truth
2. Optionally include weights/labels in the `meta` section
3. Run verification checks before deployment
4. Store the resulting JSON securely and reference it via `EDGE_CITY_ALLOWLIST_PATH`

## Migration Notes

Older allowlist files may have used hex-encoded keys (e.g. `"0xb8d6..."`). The interface loader includes a fallback for backward compatibility, but new files should use decimal strings for consistency with the Edge City API.
