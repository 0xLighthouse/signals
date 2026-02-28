# Requirements: Signals Simulations

**Defined:** 2026-02-27
**Core Value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes — publishable results that DAOs can act on.

## v3.0 Requirements

Requirements for v3.0 Sweep Engine & Extended Analysis. Each maps to roadmap phases.
Research annotations (italicized) justify decisions for future reference.

### Budget & Lock Mechanics

- [x] **BUDG-01**: Promote `_VoterLedger` and `_compute_allocation_fraction` to public `backtesting/data/budget.py` module *(Research: private internals in factory.py block testability and MC parameterization — ARCHITECTURE.md)*
- [x] **BUDG-02**: Fix `_gini()` to return `np.nan` for zero-sum arrays instead of `0.0` *(Research: P4 — returns false "perfect equality" for zero-participation proposals, corrupts sweep heatmaps — PITFALLS.md)*
- [x] **BUDG-03**: Fix `_enp()` to return `np.nan` for zero-weight arrays instead of `0.0` *(Research: P4 — ENP=0 is outside valid range [1, n_voters], corrupts sweep edge cases — PITFALLS.md)*
- [x] **BUDG-04**: Thread `curve_type` as a parameter through `generate_scenario()` → metrics computation *(Research: currently hardcoded to 'sqrt' — FEATURES.md critical gap; prerequisite for sweep)*
- [x] **BUDG-05**: Add `AllocationDistribution` dataclass to `budget.py` supporting Beta/truncnorm/uniform parameterization *(Research: enables MC allocation as continuous sweep axis — ARCHITECTURE.md)*
- [x] **BUDG-06**: All existing tests pass after budget promotion refactor

### Monte Carlo Allocation

- [ ] **MCAL-01**: Replace fixed allocation strategies with `rng.beta(a, b)` distribution draws parameterized by `AllocationDistribution` *(Research: Beta distribution bounded [0,1], shape-tunable — STACK.md)*
- [ ] **MCAL-02**: Use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent MC generators *(Research: P2 — calling default_rng(seed) N times produces N identical sequences — PITFALLS.md)*
- [ ] **MCAL-03**: `generate_scenario()` accepts optional `mc_dist` parameter for allocation distribution (backward compatible)
- [ ] **MCAL-04**: MC runner produces N independent samples per configuration with distinct seeds
- [ ] **MCAL-05**: Expose `early_frac`/`mid_frac` vote-timing parameters through `generate_scenario()` *(Research: currently hidden in `_generate_vote_timing` — FEATURES.md)*

> **v3.1 expansion notes:** QMC via `scipy.stats.qmc.Sobol`/`Halton` for variance reduction at same sample count; convergence diagnostics (running mean/std to detect when N is sufficient); per-proposal timing variation via `rng.dirichlet()`.

### Parameter Sweep Engine

- [ ] **SWEP-01**: `SweepConfig` dataclass defining grid axes: curve_type, alpha, lock_profile, allocation_strategy
- [ ] **SWEP-02**: Dedicated `sweep.py` runner using `itertools.product` for cartesian grid enumeration *(Research: cadCAD M-param zips element-wise, not factorial — PITFALLS.md P3)*
- [ ] **SWEP-03**: `ProcessPoolExecutor` parallelism across sweep cells *(Research: ~192 cells, stdlib sufficient — STACK.md)*
- [ ] **SWEP-04**: Memory management: compute metrics per-cell and release cadCAD raw results *(Research: P1 — 500MB+ accumulation without cleanup — PITFALLS.md)*
- [ ] **SWEP-05**: `SweepResult` with summary DataFrame (one row per config, columns = metrics)
- [ ] **SWEP-06**: tqdm progress reporting during sweep execution
- [ ] **SWEP-07**: TOML configuration for sweep grid parameters

### Extended Analysis

- [ ] **ANAL-01**: Flip breakdown by margin class: tight (<10%), moderate (10-30%), decisive (>30%) *(Research: pd.cut + groupby on existing results — FEATURES.md)*
- [ ] **ANAL-02**: Address-level influence analysis: per-voter (legacy_share, signals_share, delta) with counterfactual baseline *(Research: P8 — must use median-lock baseline, not raw legacy weight — PITFALLS.md)*
- [ ] **ANAL-03**: Timing sensitivity analysis with 2D timing-quantile × lock-quantile heatmap *(Research: P9 — separates conflated variables — PITFALLS.md)*
- [ ] **ANAL-04**: Voter archetype classification (whale/medium/retail by stake quantile)
- [ ] **ANAL-05**: Statistical significance tests (Mann-Whitney U) on influence distribution differences
- [ ] **ANAL-06**: Bootstrap confidence intervals on aggregate metrics across MC runs *(Research: scipy.stats.bootstrap available since 1.7 — STACK.md)*
- [ ] **ANAL-07**: Cross-run analysis module (`analysis.py`) operating on `SweepResult.summary_df`

### Report Bundle

- [ ] **REPT-01**: Heatmap plots per metric across parameter grid with correct orientation and diverging colormaps *(Research: P5 — origin='lower', RdYlGn for signed metrics — PITFALLS.md)*
- [ ] **REPT-02**: CSV export of full sweep results table
- [ ] **REPT-03**: JSON export of summary metrics with NaN sanitization
- [ ] **REPT-04**: Structured output directory (`heatmaps/`, `detail/`, `timing_sensitivity/`)
- [ ] **REPT-05**: Multi-panel composite figure combining heatmaps + flip breakdown + timing
- [ ] **REPT-06**: Per-config detail plots for best/worst N configurations
- [ ] **REPT-07**: Annotated heatmaps showing cell values + color encoding
- [ ] **REPT-08**: `generate_sweep_report()` orchestrator in `report.py`

## Future Requirements (v3.1+)

### Monte Carlo Enhancements

- **MCAL-F01**: Quasi-Monte Carlo via `scipy.stats.qmc.Sobol`/`Halton` for variance reduction
- **MCAL-F02**: Convergence diagnostics: running mean/std over MC samples to detect when N is sufficient
- **MCAL-F03**: Per-proposal timing variation via `rng.dirichlet()` (vary early/mid/late fractions per proposal)

### Sweep Enhancements

- **SWEP-F01**: Latin Hypercube Sampling for continuous axes (alpha, beta params)
- **SWEP-F02**: cadCAD-once / metrics-N-times optimization (sweep curve_type at metrics level without re-simulation)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Agent-based behavioral modeling | Explodes complexity beyond replay scope (PROJECT.md) |
| Bayesian optimization for sweep | Overkill for ~200 cell grids (FEATURES.md) |
| Interactive HTML dashboards | Static publication figures are the deliverable (PROJECT.md) |
| Causal inference claims | Simulation is counterfactual only, not causal |
| Shapley value computation | O(2^n) infeasible at realistic voter counts (PROJECT.md) |
| MCMC sampling | No posterior inference needed; plain MC is correct (FEATURES.md) |
| 3D surface plots | Hard to read, no publication advantage over 2D heatmaps (FEATURES.md) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUDG-01 | Phase 8 | Complete |
| BUDG-02 | Phase 8 | Complete |
| BUDG-03 | Phase 8 | Complete |
| BUDG-04 | Phase 8 | Complete |
| BUDG-05 | Phase 8 | Complete |
| BUDG-06 | Phase 8 | Complete |
| MCAL-01 | Phase 9 | Pending |
| MCAL-02 | Phase 9 | Pending |
| MCAL-03 | Phase 9 | Pending |
| MCAL-04 | Phase 9 | Pending |
| MCAL-05 | Phase 9 | Pending |
| SWEP-01 | Phase 10 | Pending |
| SWEP-02 | Phase 10 | Pending |
| SWEP-03 | Phase 10 | Pending |
| SWEP-04 | Phase 10 | Pending |
| SWEP-05 | Phase 10 | Pending |
| SWEP-06 | Phase 10 | Pending |
| SWEP-07 | Phase 10 | Pending |
| ANAL-01 | Phase 11 | Pending |
| ANAL-02 | Phase 11 | Pending |
| ANAL-03 | Phase 11 | Pending |
| ANAL-04 | Phase 11 | Pending |
| ANAL-05 | Phase 11 | Pending |
| ANAL-06 | Phase 11 | Pending |
| ANAL-07 | Phase 11 | Pending |
| REPT-01 | Phase 12 | Pending |
| REPT-02 | Phase 12 | Pending |
| REPT-03 | Phase 12 | Pending |
| REPT-04 | Phase 12 | Pending |
| REPT-05 | Phase 12 | Pending |
| REPT-06 | Phase 12 | Pending |
| REPT-07 | Phase 12 | Pending |
| REPT-08 | Phase 12 | Pending |

**Coverage:**
- v3.0 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 — traceability updated after roadmap creation*
