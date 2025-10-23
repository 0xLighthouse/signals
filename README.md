# 📡 Signals

A protocol for surfacing and prioritizing community objectives

> We will be at the `d/acc` [residency](https://x.com/LighthouseGov/status/1973754291744886846) in Patagonia! 🏔️hosted by [Protocol Labs](https://github.com/protocol) and running some field tests. Please reach out if you will be there!

## Intoduction

Signals is a new coordination protocol for decentralized communities.
It enables participants to lock governance tokens behind initiatives they believe in, surfacing real-time sentiment and collective intent before formal governance or funding decisions take place.

Signals lets communities explore ideas fluidly, observe where alignment emerges, and experiment with incentive-aligned decision discovery.

You can learn more about the mechanics here:

- Initial Idea, <https://mirror.xyz/lighthousegov.eth/M2MQV8O-AOoLW9RAK3zpsRSHZ2vsp9CRlaOPgUbpyHQ>
- Primer, <https://mirror.xyz/lighthousegov.eth/yOY3vgiiE5HfPbUNLSbYUpjICDA3SrcJkQVEjTPiQR4>
- Incentive Design, <https://mirror.xyz/lighthousegov.eth/mEZhb9Nwav_ZpwrvOAKCxzmJFbsez-jow9t2b4mjc2k>

**Original demo** → <https://www.youtube.com/watch?v=JKchm2MFXWA>

## Why Signals?

Existing on-chain governance systems are slow, intimidating, and dominated by whales.

Signals was designed to address these challenges:

- **Continuous discovery** — surface ideas early, before proposal lock-in
- **Conviction signaling** — longer token locks carry more weight
- **Fairness** — small holders can match whale influence through time commitment
- **Pre-vote feedback** — measure support dynamics before governance execution
- **Optional incentives** — allow sponsors to reward aligned participation

Signals helps communities listen to themselves — revealing which directions have genuine collective energy.

---

## Contributor Guide

Review the [Repository Guidelines](AGENTS.md) before proposing changes.

---

### Edge City Claim (optional)

To enable the Edge City residency claim flow in the interface:

- `NEXT_PUBLIC_EDGE_CITY=true`
- `NEXT_PUBLIC_EDGE_CITY_TOKEN_ADDRESS=0x...` (token supporting `faucet` or `claim`)
- `NEXT_PUBLIC_EDGE_CITY_CLAIM_FUNCTION=claim` (set to `faucet` only when interacting with legacy faucet tokens)
- `NEXT_PUBLIC_EDGE_CITY_MERKLE_ROOT=0x...` (must match the deployed `ExperimentToken` allowlist)
- `NEXT_PUBLIC_EDGE_CITY_REQUIRED_POPUPS=2,7` (optional list of qualifying popup IDs)
- `EDGE_OS_API_KEY=...` and optionally `EDGE_OS_BASE_URL=https://api-citizen-portal.simplefi.tech`
- `EDGE_CITY_ALLOWLIST_PATH=apps/signals-token-factory/allowlists/edge-city.json` (or `EDGE_CITY_ALLOWLIST_JSON='{"root":"0x..","proofs":{...}}'`)

Allowlist files must expose a Merkle root plus `proofs` mapping `{ "5461": ["0xabc…"] }` hashed with `keccak256(abi.encodePacked(participantId))`. Define these variables before starting the dev server so authentication, proof retrieval, and claims succeed. Each participant ID may claim exactly once; admins can additionally distribute custom airdrops with the `ExperimentToken.batchMint` function and a descriptive `reason`.

---

## ⚙️ How It Works

1. **Deploy a Board**
   - Any community can deploy a board via the Signals factory.
   - Configure parameters:
     - Governance token (ERC20)
     - Max initiatives & duration
     - Acceptance threshold
     - Minimum tokens to propose
     - Decay style (linear / exponential)

2. **Propose Initiatives**
   - Participants propose initiatives (drafts, ideas, or full proposals).
   - Each includes metadata (title, markdown body, optional attachments).

3. **Signal Support**
   - Members lock tokens in support of initiatives.
   - Weight = amount × lock duration × decay factor.
   - Locks cannot be withdrawn until expiration or acceptance.

4. **Acceptance & Refunds**
   - Once support passes the threshold, the initiative is accepted.
   - Supporters are refunded their tokens automatically.

5. **Incentives (Optional)**
   - Anyone can escrow rewards (e.g., USDC) for an initiative.
   - If the initiative is accepted, rewards distribute proportionally to supporters.

---

## Glossary

<!-- TODO move to docs -->

| Concept | Description |
|---------|-------------|
| **Board** | A configured governance surface for a token community |
| **Initiative** | A proposed idea or draft to gauge support |
| **Lock** | Time-bound commitment of tokens in favor of an initiative |
| **Decay** | Reduction in bonus weight over time (ensures timeliness) |
| **Threshold** | Minimum aggregate support for acceptance |
| **Sponsorship** | Token-backed endorsement by peers or delegates |
| **Reward Pool** | Optional escrow that pays out upon acceptance |

---

## 🚀 Getting Started

### Local Development

```shell
# tty0 – Local chain
anvil --block-time 5

# tty1 – Setup local environment (contracts, mocks, etc.)
bash scripts/dev.sh

# tty2 – Start indexer
cd apps/indexers
pnpm dev
```
