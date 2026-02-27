# Pitfalls Research — v3.0 Sweep Engine & Extended Analysis

**Domain:** Parameter sweep engine, Monte Carlo allocation, extended governance analysis
**Researched:** 2026-02-27
**Confidence:** HIGH (all pitfalls derived from direct codebase analysis)

---

## Critical Pitfalls

### P1: Memory Accumulation in Sweep Loops (Sweep Runner)

**Risk:** HIGH — `run_backtest()` creates cadCAD `Configuration` + `Executor` per call. At 100+ configs × 1000 events, raw in-memory size exceeds 500MB if results aren't released.

**Prevention:** Compute metrics immediately after each config, then `del raw; gc.collect()` before the next config.

**Phase:** Sweep Runner (must be built in from day one)

---

### P2: Monte Carlo Seed Contamination (Allocation Modeling)

**Risk:** HIGH — Calling `np.random.default_rng(42)` N times produces N identical generators. All Monte Carlo samples will be identical.

**Prevention:** Use `np.random.SeedSequence(base_seed).spawn(n_samples)` to get independent child generators per sample.

**Phase:** Monte Carlo allocation (first implementation decision — cannot be retrofitted)

---

### P3: cadCAD M Parameter Is Not Factorial (Sweep Runner)

**Risk:** HIGH — `config_sim()` zips parameter lists element-wise, not as cartesian product. A 3×3×2 grid would only produce 3 runs, not 18.

**Prevention:** Build cartesian product manually with `itertools.product`, call inner stages once per config.

**Phase:** Sweep Runner

---

### P4: Pre-existing Metric Bugs Exposed by Sweeps

**Risk:** HIGH — Two bugs hidden in single-run analysis that corrupt sweep heatmaps:
- `_gini()` returns `0.0` for zero-sum arrays instead of `np.nan` (implies "perfect equality" when there's actually no data)
- `_enp()` returns `0.0` for zero-weight arrays instead of `np.nan` (ENP=0 is outside valid range [1, n_voters])

Edge-case parameter combinations in sweeps will produce zero-participation proposals, triggering these.

**Prevention:** Fix both to return `np.nan` for degenerate inputs before sweep work begins.

**Phase:** Budget/lock formalization (fix early)

---

## Moderate Pitfalls

### P5: Heatmap Visualization Triple-Trap (Heatmaps)

Three simultaneous traps:
1. `imshow` default `origin='upper'` inverts y-axis — high parameter values appear at bottom
2. Sequential colormap (viridis) applied to signed delta metrics makes zero-change invisible
3. Per-slice color normalization makes cross-heatmap comparison meaningless

**Prevention:** Use `origin='lower'`, diverging colormap (RdYlGn) for signed metrics, global vmin/vmax across comparison plots. Build into a shared `plot_sweep_heatmap()` function.

**Phase:** Heatmap/Report

---

### P6: Insufficient MC Samples for Stable Flip Rate (Monte Carlo)

With 30 proposals per scenario, a single run's flip rate has resolution of 1/30 ≈ 3.3% and 95% CI spanning ±10pp. Publishable CI widths require N≥50 independent MC samples.

**Prevention:** Document minimum sample sizes. Add convergence diagnostic (running mean/std over samples).

**Phase:** Monte Carlo allocation

---

### P7: "Fairness" Has Multiple Non-Equivalent Definitions (Extended Analysis)

Gini of voting power, ENP, Nakamoto coefficient, and share-change can produce contradictory results on the same dataset. A simulation can show Signals as both "fairer" and "less fair" depending on which metric.

**Prevention:** Every metric must have an operational definition in its docstring. Report all metrics, don't cherry-pick.

**Phase:** Extended analysis

---

### P8: Address Influence Baseline Is Circular (Extended Analysis)

Per-voter influence delta measured against raw legacy weight is circular — by construction, above-median lockers always show positive influence change.

**Prevention:** Use counterfactual baseline (median lock duration) instead of legacy weight.

**Phase:** Extended analysis

---

### P9: Timing Conflation (Extended Analysis)

Timing sensitivity analysis easily conflates vote block position with lock duration. These are independent variables in the model but look correlated in aggregate.

**Prevention:** 2D timing-quantile × lock-quantile heatmap to separate the effects.

**Phase:** Extended analysis

---

### P10: matplotlib Memory in Long Sweep Loops (All Phases)

matplotlib Figure objects hold large internal buffers. Creating 100+ figures without closing them leaks ~50MB+ per figure.

**Prevention:** `fig.savefig(...)` then `plt.close(fig)` (or for OO API: ensure no references remain after save).

**Phase:** All phases with plotting

---

## Phase-Pitfall Mapping

| Phase | Pitfalls to Address |
|-------|---------------------|
| Budget/Lock Formalization | P4 (Gini/ENP nan fix) |
| Monte Carlo Allocation | P2 (seed contamination), P6 (sample size) |
| Sweep Runner | P1 (memory), P3 (M param), P10 (matplotlib memory) |
| Heatmap/Report | P5 (visualization traps), P10 (matplotlib memory) |
| Extended Analysis | P7 (fairness definition), P8 (influence baseline), P9 (timing conflation) |

---

## Open Questions

- Whether N=50 MC samples per sweep config is feasible within target runtime — depends on single-config runtime
- `iterrows` loop in `_compute_lockin_fraction` may bottleneck at sweep scale (100+ proposals × 500+ voters) — needs profiling

---

*Pitfalls research for: Signals v3.0 — Sweep Engine & Extended Analysis*
*Researched: 2026-02-27*
