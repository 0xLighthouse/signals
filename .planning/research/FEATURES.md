# Features Research — v3.0 Sweep Engine & Extended Analysis

**Domain:** Parameter sweep engine, Monte Carlo allocation, extended governance analysis
**Researched:** 2026-02-27
**Confidence:** HIGH (existing codebase read directly; scipy capabilities verified)

---

## Feature Categories

### 1. Parameter Sweep Engine

**Table Stakes:**
- Grid search over discrete axes (curve type, lock profile, allocation strategy)
- Cartesian product enumeration via `itertools.product`
- Per-cell independent pipeline execution
- Progress reporting (tqdm)
- Results collection into summary DataFrame

**Differentiators:**
- Latin Hypercube Sampling for continuous axes (alpha, beta params) via `scipy.stats.qmc.LatinHypercube`
- cadCAD-once / metrics-N-times optimization (sweep curve_type at metrics level, not re-simulation)
- Process-based parallelism (`concurrent.futures.ProcessPoolExecutor`)

**Anti-features (avoid):**
- Bayesian optimization (overkill for ~200 cell grids)
- cadCAD M-parameter sweep for the outer grid (unreliable with 4+ axes)

**Dependencies on existing:** `run_pipeline()` or inner stages (`generate_scenario`, `run_backtest`, `build_results_dataframe`, `compute_*`)

**Critical gap:** `curve_type` is NOT currently a `generate_scenario()` parameter — it's hardcoded to `'sqrt'` deep in metrics computation. Threading it through is the most impactful prerequisite for the sweep.

---

### 2. Monte Carlo Allocation Modeling

**Table Stakes:**
- Replace fixed allocation strategies with `rng.beta(a, b)` distribution draws
- Three existing strategies map to Beta distribution presets:
  - `uniform_fraction` → Beta(2, 5), mean≈0.29
  - `conviction_weighted` → Beta(α, β) where α scales with lock duration
  - `aggressive` → Beta(5, 2), mean≈0.71
- `beta_a` and `beta_b` become continuous sweep axes
- Seed-based reproducibility (extend existing `seed` param)

**Differentiators:**
- Per-proposal timing variation via `rng.dirichlet()` (vary early/mid/late fractions per proposal)
- Quasi-Monte Carlo via `scipy.stats.qmc` for variance reduction at same sample count
- Convergence diagnostics: running mean/std over MC samples to detect when N is sufficient

**Anti-features (avoid):**
- Agent-based behavioral modeling (explodes complexity — already in Out of Scope)
- Markov chain Monte Carlo (no posterior inference needed; plain MC is correct)

**Dependencies on existing:** `_compute_allocation_fraction()` in factory.py, `_generate_vote_timing()` (currently `early_frac`/`mid_frac` not exposed through `generate_scenario()`)

---

### 3. Heatmap Report Bundle

**Table Stakes:**
- 2D heatmaps: `pivot_table` sweep DataFrame on two param axes → `seaborn.heatmap(ax=ax)` or `ax.imshow()`
- Three core heatmaps: flip_rate, gini_delta, nakamoto_delta
- CSV export of full sweep results table
- JSON export of summary metrics (with NaN sanitization)

**Differentiators:**
- Multi-panel composite figure combining heatmaps + flip breakdown + timing scatter
- Per-config detail plots for best/worst N configurations
- Annotated heatmaps showing cell values + color encoding

**Anti-features (avoid):**
- Interactive HTML dashboards (Streamlit/Dash — already in Out of Scope)
- 3D surface plots (hard to read, no publication advantage over 2D heatmaps)

**Dependencies on existing:** `plots.py` OO API conventions, `pipeline.py` `_nan_to_none()` sanitizer

---

### 4. Extended Governance Analysis

**Table Stakes:**
- **Flip breakdown by margin class:** Classify proposals by legacy margin (tight <10%, moderate 10-30%, decisive >30%), count flips per class. Answers: "Does Signals flip close races or also change blowouts?"
- **Address-level influence analysis:** Per-voter `(legacy_share, signals_share, delta)` across all their votes. Surfaces which voter archetypes (whale/retail/mid) gain or lose power.
- **Timing sensitivity:** Correlation between allocation strategy / lock-in timing and governance outcomes.

**Differentiators:**
- Statistical significance tests (Mann-Whitney U) on influence distribution differences
- Bootstrap confidence intervals on aggregate metrics across MC runs
- Voter archetype classification (whale/medium/retail by stake quantile)

**Anti-features (avoid):**
- Causal inference claims (counterfactual only, not causal)
- Shapley value computation (O(2^n) infeasible — already in Out of Scope)

**Dependencies on existing:** `compute_flip_rate()`, `compute_gini()`, `build_results_dataframe()`, voter address mapping in events

---

## Complexity Assessment

| Feature | Complexity | Notes |
|---------|-----------|-------|
| Grid sweep runner | Medium | Main work: threading `curve_type` through the stack |
| MC allocation (Beta distributions) | Low | Replace `rng.uniform()` with `rng.beta()` in factory |
| MC timing variation | Low | Expose existing `early_frac`/`mid_frac` in `generate_scenario()` |
| cadCAD-once optimization | Medium | Requires separating data generation from metrics computation in sweep loop |
| Flip margin breakdown | Low | `pandas.cut()` + groupby on existing results |
| Address influence | Medium | Per-voter share computation across all proposals |
| Timing sensitivity | Low | Pearson r between sweep params and metrics |
| Heatmap plots | Low | seaborn.heatmap with existing OO API conventions |
| Report bundle | Medium | Orchestration of all above into structured output directory |

---

## No New Dependencies

All features implementable with existing stack: scipy 1.17.1, numpy 1.26.4, seaborn 0.13.2, pandas 2.3.3, matplotlib 3.10.8, stdlib (itertools, concurrent.futures, json).

---

*Features research for: Signals v3.0 — Sweep Engine & Extended Analysis*
*Researched: 2026-02-27*
