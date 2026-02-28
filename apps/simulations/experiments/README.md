# Signals Simulation Experiments

This directory contains simulation scripts for the Signals Protocol research project.
Each simulation tests a distinct research question about commitment-weighted governance.

See [THESIS_GUIDE.md](../THESIS_GUIDE.md) for infrastructure status, dependency map,
and required code changes for each planned simulation.

---

## Simulations Overview

| Sim | Name | Research Question | Status |
|-----|------|-------------------|--------|
| A | Whale-dominated DAO | Does commitment-weighting reduce plutocracy? | Implemented |
| B | Heterogeneous Returns | When whales hold short locks and retail holds long locks, does Signals amplify small holders? | Implemented |
| C | Curve Sensitivity | Which lock curve shape best amplifies small holders while maintaining whale accountability? | Planned |
| D | Sybil Splitting Attack | Does splitting stake into many wallets game the sqrt curve? | Planned |
| E | Participation Incentive Effect | Does vote timing matter for fairness? | Planned |
| F | Bimodal Stakes with Conviction-Weighted Allocation | With bimodal stake distribution, does conviction_weighted allocation force whales to spread thin? | Planned |
| G | Scale Sensitivity | Does the Signals Protocol advantage hold at different voter population sizes? | Planned |

---

## Running Implemented Simulations

All sims run from the `apps/simulations/` working directory:

```bash
cd apps/simulations
uv run python experiments/sim_a/sim_a.py
uv run python experiments/sim_b/sim_b.py
```

Output images are saved to `apps/simulations/output/`.

---

## Dependency Order

Sim C must run first — its output (which curve type dominates) determines the
fixed `curve_type` parameter used in Sims D, F, and G.

```
Sim C (Curve Sensitivity) --> Sim D (Sybil), Sim F (Bimodal), Sim G (Scale)
Sim E (Participation/Timing) -- Independent
```

---

## Infrastructure Status

See [THESIS_GUIDE.md](../THESIS_GUIDE.md) for detailed infrastructure inventory,
gap analysis, and required code changes for Sims C through G.
