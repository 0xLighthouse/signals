# Project Research Summary

**Project:** Signals v3.0 — Sweep Engine & Extended Analysis
**Domain:** Parameter sweep engine, Monte Carlo allocation, extended governance simulation analysis
**Researched:** 2026-02-27
**Confidence:** HIGH

## Executive Summary

Signals v3.0 extends the existing cadCAD-based governance simulation with a parameter sweep engine, Monte Carlo allocation modeling, heatmap report bundles, and extended statistical analysis. Research confirms the entire feature set is achievable with zero new runtime dependencies — the locked stack (cadCAD 0.5.3, scipy 1.17.1, numpy 1.26.4, seaborn 0.13.2, pandas 2.3.3, matplotlib 3.10.8) provides every capability needed. The only pyproject.toml change is pinning `tqdm` as a direct dependency. This substantially de-risks delivery: there are no dependency resolution unknowns, no API mismatches to discover, and no new library learning curves.

The recommended architecture introduces five new or modified modules under `backtesting/`: a promoted `budget.py` for allocation mechanics, a `sweep.py` runner, a cross-run `analysis.py`, heatmap functions added to `plots.py`, and an orchestrating `report.py`. The single most impactful prerequisite is threading `curve_type` through the existing call stack — it is currently hardcoded to `'sqrt'` deep in metrics computation, and the entire sweep grid depends on it being a first-class parameter. A critical performance decision must be built in from day one: cadCAD runs once per (stake_profile, lock_profile, allocation_strategy, seed); metric computation sweeps curve_type and alpha without re-running simulation. Retrofitting this later requires significant rework.

The top risks are memory-related (cadCAD results accumulate at sweep scale; matplotlib figures must be explicitly closed) and correctness-related (two pre-existing metric bugs — `_gini()` and `_enp()` returning `0.0` for degenerate inputs — will silently corrupt heatmaps for edge-case configs). Both are straightforward to prevent if addressed before sweep work begins. Monte Carlo seed management via `SeedSequence.spawn()` is a one-time decision that cannot be safely retrofitted. Overall, this is well-mapped territory with concrete implementation paths — the main risk is sequencing, not feasibility.

---

## Key Findings

### Recommended Stack

The existing locked stack handles all v3.0 requirements. No new packages are required. The stdlib provides `itertools.product` for cartesian sweep enumeration and `concurrent.futures.ProcessPoolExecutor` for parallelism — adding joblib, dask, or ray would add complexity without benefit for a ~192-cell grid. `scipy.stats.qmc.LatinHypercube` (available since scipy 1.7, locked at 1.17.1) enables variance reduction for continuous Monte Carlo axes without additional packages.

**Core technologies:**
- `cadCAD 0.5.3`: simulation backbone — locked, do not change
- `scipy 1.17.1`: Mann-Whitney U, KS test, bootstrap CI, QMC sampling — all capabilities confirmed at this version
- `numpy 1.26.4`: RNG via `default_rng()` and `SeedSequence.spawn()`, Beta/LogNormal/truncnorm distributions
- `pandas 2.3.3`: sweep result accumulation, pivot_table for heatmap inputs, CSV export
- `seaborn 0.13.2`: `heatmap(ax=ax)` OO API for sweep visualization
- `matplotlib 3.10.8`: figure management for multi-panel reports
- `itertools` + `concurrent.futures` (stdlib): cartesian product + process parallelism — no new deps needed
- `tqdm 4.67.3`: progress reporting — pin as direct dep (currently transitive only via cadCAD)

### Expected Features

**Must have (table stakes):**
- Grid search over (curve_type, lock_profile, allocation_strategy) with `itertools.product` cartesian enumeration
- cadCAD-once / metrics-N-times optimization baked into sweep runner from day one
- Monte Carlo allocation fractions via `rng.beta(a, b)` replacing fixed allocation strategies
- Seed-based reproducibility via `SeedSequence.spawn()` for independent per-sample generators
- Flip breakdown by margin class (tight <10%, moderate 10-30%, decisive >30%)
- Address-level influence analysis (legacy share vs. signals share per voter)
- Three core heatmaps: flip_rate, gini_delta, nakamoto_delta
- CSV + JSON export of full sweep results

**Should have (competitive differentiators):**
- Latin Hypercube Sampling for continuous axes (alpha, beta_a, beta_b) via `scipy.stats.qmc`
- Per-proposal timing variation via `rng.dirichlet()` (early/mid/late allocation per proposal)
- Convergence diagnostics: running mean/std over MC samples
- Bootstrap confidence intervals on aggregate metrics (`scipy.stats.bootstrap`)
- Mann-Whitney U significance testing on influence distribution differences
- Multi-panel composite figure combining heatmaps, flip breakdown, timing scatter
- Per-config detail plots for best/worst N configurations

**Defer (v4+):**
- Interactive HTML dashboards (Streamlit/Dash)
- Agent-based behavioral modeling
- Bayesian optimization for sweep grid
- 3D surface plots
- Shapley value computation (O(2^n) infeasible)
- Causal inference claims

### Architecture Approach

The sweep runner lives in a new `backtesting/sweep.py` and calls inner pipeline stages directly (`generate_scenario` -> `run_backtest` -> `build_results_dataframe` -> `compute_*`) rather than wrapping `run_pipeline()`, which has per-run I/O side effects that are harmful inside a sweep loop. Extended analysis splits into two tiers: per-run functions added to `metrics.py` (margin class flips, address influence), and cross-run sweep analysis in a new `backtesting/analysis.py` consuming `SweepResult.summary_df`. A new `backtesting/report.py` orchestrates everything into a structured output directory. `backtesting/pipeline.py` is unchanged — single-config runs remain fully functional.

**Major components:**
1. `backtesting/data/budget.py` (NEW) — promoted `_VoterLedger`, `AllocationDistribution` dataclass, MC sampling; backward-compatible `mc_dist` param added to `generate_scenario()`
2. `backtesting/sweep.py` (NEW) — `SweepConfig`, `SweepRunner`, `SweepResult`; cadCAD-once/metrics-N-times loop with `ProcessPoolExecutor`; explicit `del raw; gc.collect()` after each config
3. `backtesting/metrics.py` (MODIFY) — add `margin_class_breakdown()`, `address_influence()` with counterfactual baseline
4. `backtesting/analysis.py` (NEW) — cross-run: `pivot_heatmap()`, `timing_sensitivity()`, `margin_class_summary()`
5. `backtesting/plots.py` (MODIFY) — add `plot_sweep_heatmap()` with `origin='lower'`, diverging colormap for signed metrics, global vmin/vmax
6. `backtesting/report.py` (NEW) — `generate_sweep_report()` orchestrator; outputs to `output/sweep_{timestamp}/`
7. `backtesting/pipeline.py` (UNCHANGED) — single-config runs remain fully functional

### Critical Pitfalls

1. **cadCAD M parameter is not factorial (P3)** — `config_sim()` zips lists element-wise, not cartesian product; a 3x3x2 grid would produce 3 runs, not 18. Prevention: always use `itertools.product` manually for sweep enumeration; assert expected vs. actual combination count at sweep start.

2. **Monte Carlo seed contamination (P2)** — calling `np.random.default_rng(42)` N times produces N identical generators, making all MC samples identical. Prevention: use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent child generators. This is a first-implementation decision that cannot be retrofitted.

3. **Pre-existing metric bugs exposed by sweeps (P4)** — `_gini()` returns `0.0` for zero-sum arrays (implies "perfect equality" when there's no data); `_enp()` returns `0.0` for zero-weight arrays (outside valid range [1, n]). Edge-case sweep configs will trigger these and silently corrupt heatmaps. Prevention: fix both to return `np.nan` for degenerate inputs before any sweep work begins.

4. **Memory accumulation in sweep loops (P1)** — cadCAD `Configuration` + `Executor` per call; at 100+ configs x 1000 events, memory exceeds 500MB without explicit cleanup. Prevention: `del raw; gc.collect()` immediately after metrics computation per config. Must be built in from day one.

5. **Heatmap visualization triple-trap (P5)** — `imshow` default `origin='upper'` inverts y-axis; sequential colormap (viridis) makes zero invisible on signed delta metrics; per-slice normalization breaks cross-heatmap comparison. Prevention: `origin='lower'`, diverging colormap (RdYlGn) for signed metrics, global vmin/vmax — enforce via shared `plot_sweep_heatmap()` helper.

---

## Implications for Roadmap

The build order is driven by two hard constraints: (1) the metric bugs must be fixed before any sweep work or heatmaps will be silently corrupted, and (2) `budget.py` and extended metrics are independent and can develop in parallel, but `sweep.py` depends on both. The cadCAD-once optimization must be designed into the sweep runner from day one — it cannot be added later without significant rework.

### Phase 1: Foundation Fixes & Budget Promotion

**Rationale:** Two pre-existing bugs (`_gini()`, `_enp()` returning `0.0` for degenerate inputs) will silently corrupt sweep heatmaps. These must be fixed before sweep work begins. Simultaneously, promoting `_VoterLedger` and `_compute_allocation_fraction` to a public `budget.py` module is a prerequisite for Monte Carlo allocation. Neither fix touches the other — they can develop in parallel within the phase.

**Delivers:** Corrected `_gini()` and `_enp()` returning `np.nan` for degenerate inputs; `budget.py` with `AllocationDistribution(Beta/truncnorm/uniform)` dataclass; `mc_dist` parameter wired into `generate_scenario()` (backward-compatible); `tqdm` pinned as direct dependency; `SeedSequence.spawn()` seed architecture established.

**Addresses:** Prerequisite foundation for all sweep and Monte Carlo features.

**Avoids:** P4 (metric nan fix prevents silent heatmap corruption), P2 (seed architecture established at first implementation point)

---

### Phase 2: Monte Carlo Allocation Modeling

**Rationale:** With `budget.py` in place, replacing fixed allocation strategies with Beta distribution draws is straightforward. This phase also establishes convergence diagnostics needed to validate that MC sample counts are sufficient before sweep scale-out.

**Delivers:** `rng.beta(a, b)` allocation replacing `rng.uniform()`; `beta_a`/`beta_b` as continuous sweep axes; per-proposal timing variation via `rng.dirichlet()`; quasi-Monte Carlo via `scipy.stats.qmc.LatinHypercube`; convergence diagnostics (running mean/std over samples); N>=50 sample minimum documented.

**Addresses:** MC allocation (all table stakes + QMC differentiator)

**Avoids:** P2 (SeedSequence already established in Phase 1), P6 (convergence diagnostics built in, not retrofitted)

---

### Phase 3: Sweep Runner

**Rationale:** Depends on `budget.py` (Phase 1) and the extended per-run metrics (Phase 1 parallel track). The cadCAD-once / metrics-N-times optimization must be built in here — it cannot be added later without rework. Threading `curve_type` through the call stack is the gating prerequisite and must happen at phase start.

**Delivers:** `sweep.py` with `SweepConfig`, `SweepRunner`, `SweepResult`; cadCAD-once loop with `ProcessPoolExecutor`; `itertools.product` cartesian enumeration (not cadCAD M-param); `del raw; gc.collect()` memory management per config; progress via `tqdm`.

**Addresses:** Grid sweep (all table stakes); process parallelism (differentiator)

**Avoids:** P1 (explicit memory cleanup per config), P3 (itertools.product not cadCAD M-param), P10 (plt.close(fig) pattern enforced in sweep plotting)

---

### Phase 4: Extended Statistical Analysis

**Rationale:** Depends on `SweepResult` shape from Phase 3. Per-run metric extensions (`margin_class_breakdown`, `address_influence`) can begin development in parallel with Phase 3, but cross-run analysis (`analysis.py`) requires the `SweepResult` contract to be finalized first. The counterfactual baseline for address influence must be established here — not raw legacy weight.

**Delivers:** `margin_class_breakdown()` (tight/moderate/decisive flip counts via `pandas.cut`); `address_influence()` with counterfactual baseline (median lock duration, not raw legacy weight); `analysis.py` with `pivot_heatmap()`, `timing_sensitivity()` as 2D heatmap separating timing from lock-duration effects; Mann-Whitney U + bootstrap CI; voter archetype classification (whale/medium/retail by stake quantile).

**Addresses:** Extended governance analysis (all table stakes + statistical differentiators)

**Avoids:** P7 (all fairness metrics reported, none cherry-picked; operational definitions in docstrings), P8 (counterfactual baseline enforced), P9 (2D timing-quantile x lock-quantile heatmap isolates the two effects)

---

### Phase 5: Heatmap Report Bundle

**Rationale:** Terminal integration phase. Depends on sweep runner output (Phase 3) and analysis functions (Phase 4). Orchestrates all prior work into a structured, self-contained output directory. The shared `plot_sweep_heatmap()` helper is the single enforcement point for all visualization correctness.

**Delivers:** `report.py` with `generate_sweep_report()`; `plot_sweep_heatmap()` helper in `plots.py` with `origin='lower'`, RdYlGn diverging colormap for signed metrics, global vmin/vmax across comparison plots; multi-panel composite figure; per-config detail plots (best/worst N configurations); CSV + JSON export; output directory structure `output/sweep_{timestamp}/heatmaps/detail/timing_sensitivity/`.

**Addresses:** Heatmap report bundle (all table stakes + multi-panel differentiator)

**Avoids:** P5 (all three visualization traps handled by shared helper), P10 (plt.close(fig) enforced throughout sweep report generation)

---

### Phase Ordering Rationale

- Phase 1 must come first because metric bugs silently corrupt all downstream heatmap output, and `budget.py` is a hard prerequisite for Monte Carlo allocation
- Within Phase 1, the metric fixes track and the `budget.py` track are fully independent and can develop in parallel
- Phase 2 (MC allocation) depends only on Phase 1's `budget.py` track and can begin immediately after
- Phase 3 (sweep runner) depends on both Phase 1 tracks being complete; threading `curve_type` through the stack is the single gating prerequisite and must happen at phase start
- Phase 4 (extended analysis) per-run metrics can begin in parallel with Phase 3, but `analysis.py` depends on `SweepResult` contract being finalized
- Phase 5 (report bundle) always comes last — it is a pure consumer of Phases 3 and 4 outputs

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (Extended Analysis):** Counterfactual baseline selection for address influence is methodology-sensitive — "median lock duration" as counterfactual may need empirical grounding or literature citation. The definition of "fairness" as an operational metric (P7) needs explicit consensus before implementation begins. Flag for targeted research-phase.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation Fixes & Budget):** All patterns are established in the existing codebase; no external API ambiguity
- **Phase 2 (Monte Carlo Allocation):** scipy and numpy RNG APIs are comprehensively documented; Beta/truncnorm distributions are standard
- **Phase 3 (Sweep Runner):** `itertools.product` + `ProcessPoolExecutor` are stdlib with no surprises; cadCAD inner-stage calling pattern verified in existing code
- **Phase 5 (Report Bundle):** seaborn/matplotlib OO API well-documented; output directory structure is straightforward

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions read directly from uv.lock; no new dependencies needed; zero ambiguity |
| Features | HIGH | Derived from direct codebase read; all integration points verified; complexity estimates are conservative and based on actual code paths |
| Architecture | HIGH | Module boundaries verified against existing code; cadCAD-once optimization confirmed viable from v2.0 weight storage pattern |
| Pitfalls | HIGH | All pitfalls derived from direct codebase analysis; P4 metric bugs confirmed present in source code |

**Overall confidence:** HIGH

### Gaps to Address

- **MC sample count vs. runtime tradeoff:** Whether N=50 MC samples per sweep config is feasible within acceptable wall-clock runtime is unknown without profiling a single-config run. Address in Phase 2 by profiling before committing to convergence diagnostic defaults.
- **`iterrows` performance at sweep scale:** `_compute_lockin_fraction` uses an `iterrows` loop that may bottleneck at 100+ proposals x 500+ voters inside a sweep context. Profile during Phase 3 and vectorize if needed.
- **Sweep CLI interface:** Whether sweep execution should be a new `__main__` entry point in `sweep.py` or integrated into the existing pipeline CLI is an open design decision. Resolve during Phase 3 planning.
- **Detail plot selection:** Which best/worst N configurations are most analytically useful for the report bundle needs explicit decisions. Resolve during Phase 5 planning.
- **MC distribution parameters for realistic DAO behavior:** Beta(2,5) and Beta(5,2) are reasonable priors but lack empirical grounding in DAO-specific data. Flag for literature review or empirical validation during Phase 2 planning.

---

## Sources

### Primary (HIGH confidence)
- `apps/simulations/uv.lock` — exact resolved versions for all locked packages (read directly)
- `apps/simulations/pyproject.toml` — direct dependency declarations (read directly)
- `apps/simulations/src/backtesting/` (factory.py, metrics.py, pipeline.py, plots.py) — existing module code read directly; integration points and bugs verified
- scipy 1.17.1 API — `qmc.LatinHypercube`, `stats.mannwhitneyu`, `stats.ks_2samp`, `stats.bootstrap` confirmed available (added in scipy 1.7)
- numpy 1.26.4 API — `random.SeedSequence.spawn()`, `random.default_rng()` confirmed

### Secondary (MEDIUM confidence)
- cadCAD M-parameter element-wise zip behavior (not cartesian) — confirmed from existing simulation run patterns in codebase and PITFALLS analysis
- Beta distribution parameter recommendations (Beta(2,5) mean≈0.29, Beta(5,2) mean≈0.71) — statistically grounded but lack DAO-specific empirical validation

### Tertiary (LOW confidence — validate during implementation)
- N=50 minimum MC samples for publishable CI widths — derived from 1/30 flip rate resolution (~3.3% granularity); needs runtime profiling to confirm feasibility at sweep scale
- Counterfactual baseline ("median lock duration") for address influence — reasonable methodology choice, not empirically validated against actual DAO datasets

---

*Research completed: 2026-02-27*
*Ready for roadmap: yes*
