# Sim G: Scale Sensitivity

**Status:** Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes

---

## Research Question

Does the Signals Protocol advantage hold at different voter population sizes?

---

## Experiment Design

Test the protocol at multiple voter population sizes to confirm scale-invariance:

- `n_voters`: [50, 200, 500, 2000]
- Fixed: pareto stake, independent locks, best curve_type from Sim C

Two implementation approaches:

**Approach A (No code):** Run 4 separate TOML sweeps, one per n_voters value.
**Approach B (Small code change):** Add `n_voters_list` as a cartesian sweep axis.

---

## Infrastructure Status

Requires Sim C output to determine the fixed curve_type parameter.
n_voters is currently in the `base` dict, not a cartesian sweep axis.
See [../../THESIS_GUIDE.md](../../THESIS_GUIDE.md) for required changes and performance notes.

**Priority:** 5 (depends on Sim C results)
