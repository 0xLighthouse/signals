# Sim E: Participation Incentive Effect

**Status:** Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes

---

## Research Question

Does vote timing matter for fairness? Do late-voting whales get dampened by any
time-based mechanism? What is the correlation between vote timing and stake rank?

---

## Experiment Design

Two paths depending on research intent:

**Path A (Low complexity, mostly ready):** Sweep vote_timings configs (early-heavy
vs. late-heavy) and use `timing_sensitivity()` to correlate stake rank with timing
patterns. Requires only TOML config — no code changes.

**Path B (High complexity):** Implement a new timing decay mechanism to actively
penalize late votes. Requires new decay function in weighting/signals.py.

---

## Infrastructure Status

Path A is immediately executable via TOML sweep configuration.
Path B requires new timing decay mechanism design and implementation.
See [../../THESIS_GUIDE.md](../../THESIS_GUIDE.md) for details.

**Priority:** 4 (independent of Sims C/D/F/G)
