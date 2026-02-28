# Sim F: Bimodal Stakes with Conviction-Weighted Allocation

**Status:** Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes

---

## Research Question

With bimodal stake distribution (10% whales, 90% retail), does conviction_weighted
allocation force whales to spread thin across proposals?

---

## Experiment Design

Sweep allocation strategies against bimodal stake distribution:

- `stake_profile`: 'bimodal' (10% of voters hold 90% of supply)
- `allocation_strategies`: ['conviction_weighted', 'uniform_fraction'] (control)
- Cross with: `curve_types`, `lock_profiles`

---

## Infrastructure Status

**This sim can run TODAY with no code changes.** All required infrastructure exists.
See [../../THESIS_GUIDE.md](../../THESIS_GUIDE.md) for expected TOML configuration.

**Priority:** 3 (can run while Sim D is being developed; best to use Sim C's recommended curve)
