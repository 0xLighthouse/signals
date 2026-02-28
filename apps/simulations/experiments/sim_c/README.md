# Sim C: Curve Sensitivity

**Status:** Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes

---

## Research Question

Which lock curve shape best amplifies small holders while maintaining whale accountability?

---

## Experiment Design

Sweep across all four curve types (sqrt, linear, log, exp) and multiple floor values
to determine which configuration produces the best Gini reduction and ENP improvement
relative to legacy governance.

- `curve_types`: [sqrt, linear, log, exp]
- `floors`: [0.0, 0.1, 0.3]
- Fixed: pareto stake, independent locks, n_voters=200

---

## Infrastructure Status

Small factory/sweep code changes required before this sim can run.
See [../../THESIS_GUIDE.md](../../THESIS_GUIDE.md) for specific required changes.

**Priority:** 1 (blocking — Sims D, F, G depend on its output)
