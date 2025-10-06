# 📡 Signals

A protocol for surfacing and prioritizing community objectives

## Intoduction

Signals is a new coordination primitive for decentralized communities.
It enables participants to lock governance tokens behind initiatives they believe in, surfacing real-time sentiment and collective intent before formal governance or funding decisions take place.

Unlike rigid proposal-vote systems, Signals lets communities explore ideas fluidly, observe where alignment emerges, and experiment with incentive-aligned decision discovery.

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
yarn dev
```

---

## 🌐 Deployments

- **Testnet**: <https://signals.testnet.lighthouse.cx>
- **Network**: Arbitrum Sepolia (default)
- **Contracts**: See `/apps/signals/deployments` for addresses

---

## 🪞 Learn More

- [Whitepaper (draft)](WHITEPAPER.md)
- [Signals Documentation](apps/signals/README.md)
- [Interface Documentation](apps/interface/README.md)
