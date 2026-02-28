# Roadmap: Signals

## Milestones

- ✅ **v1.0 Poetry to uv Migration** — Phases 1-2 (shipped 2026-02-27)
- ✅ **v2.0 Backtesting & Simulation** — Phases 3-7 (shipped 2026-02-27)
- 🚧 **v3.0 Sweep Engine & Extended Analysis** — Phases 8-12 (in progress)

## Phases

<details>
<summary>✅ v1.0 Poetry to uv Migration (Phases 1-2) — SHIPPED 2026-02-27</summary>

- [x] Phase 1: Migrate (1/1 plans) — completed 2026-02-27
- [ ] Phase 2: Verify (skipped) — verification requirements deferred

</details>

<details>
<summary>✅ v2.0 Backtesting & Simulation (Phases 3-7) — SHIPPED 2026-02-27</summary>

- [x] Phase 3: Foundation (2/2 plans) — completed 2026-02-27
- [x] Phase 4: cadCAD Integration (2/2 plans) — completed 2026-02-27
- [x] Phase 5: Metrics (2/2 plans) — completed 2026-02-27
- [x] Phase 6: Plots (2/2 plans) — completed 2026-02-27
- [x] Phase 7: Pipeline (1/1 plan) — completed 2026-02-27

</details>

### 🚧 v3.0 Sweep Engine & Extended Analysis (In Progress)

**Milestone Goal:** Build a dedicated parameter sweep engine with Monte Carlo allocation modeling, formalize budget/lock mechanics, and produce deep governance analysis with a structured heatmap report bundle.

- [x] **Phase 8: Foundation Fixes & Budget Promotion** - Fix NaN bugs, promote budget module, thread curve_type (completed 2026-02-28)
- [x] **Phase 9: Monte Carlo Allocation Modeling** - Replace fixed allocations with Beta distribution draws (completed 2026-02-28)
- [x] **Phase 10: Sweep Runner** - Cartesian grid sweep engine with parallelism and memory management (completed 2026-02-28)
- [x] **Phase 10.1: Integration Wiring Fixes** - Fix NaN handling, wire mc_dist through sweep/pipeline, re-export VoteTimingConfig (completed 2026-02-28)
- [x] **Phase 11: Extended Analysis** - Flip breakdown, address influence, timing sensitivity, statistical tests (completed 2026-02-28)
- [x] **Phase 11.1: Wire vote_timing Through Sweep** - Add vote_timing to SweepCell/SweepConfig, pass through _run_cell() (completed 2026-02-28)
- [ ] **Phase 12: Report Bundle** - Heatmaps, exports, multi-panel figures, orchestrating report.py

## Phase Details

### Phase 8: Foundation Fixes & Budget Promotion
**Goal**: The codebase is clean and correctly instrumented for sweep work — bugs that would silently corrupt heatmaps are eliminated, and the budget/lock constraint system is a properly testable public module with curve_type as a first-class parameter
**Depends on**: Phase 7 (v2.0 pipeline complete)
**Requirements**: BUDG-01, BUDG-02, BUDG-03, BUDG-04, BUDG-05, BUDG-06
**Success Criteria** (what must be TRUE):
  1. `_gini()` returns `np.nan` (not `0.0`) when called with a zero-sum array
  2. `_enp()` returns `np.nan` (not `0.0`) when called with a zero-weight array
  3. `generate_scenario(curve_type='log')` runs without error and produces metrics using the log curve (not hardcoded sqrt)
  4. `budget.py` module exists with public `VoterLedger`, `AllocationDistribution`, and `compute_allocation_fraction` — importable and unit-testable independently of the factory
  5. All 147 existing tests pass after the refactor
**Plans**: TBD

### Phase 9: Monte Carlo Allocation Modeling
**Goal**: Allocation fractions are drawn from configurable probability distributions rather than fixed values, with seed-safe independent generators per sample, enabling MC allocation as a continuous sweep axis
**Depends on**: Phase 8
**Requirements**: MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-05
**Success Criteria** (what must be TRUE):
  1. Calling `generate_scenario(mc_dist=AllocationDistribution(type='beta', a=2, b=5))` produces allocation fractions drawn from Beta(2,5) — not uniform random
  2. Running 50 MC samples with the same base seed produces 50 distinct allocation sequences (not 50 identical sequences)
  3. `generate_scenario()` called without `mc_dist` behaves identically to v2.0 (backward-compatible)
  4. `early_frac` and `mid_frac` vote-timing parameters are accepted by `generate_scenario()` and alter the timing distribution of votes
**Plans**: 2 plans
- [ ] 09-01-PLAN.md — Extend generate_scenario() with mc_dist + VoteTimingConfig
- [ ] 09-02-PLAN.md — Build MC runner module (backtesting/mc.py)

### Phase 10: Sweep Runner
**Goal**: A dedicated sweep engine enumerates a cartesian parameter grid, runs cadCAD once per simulation config, computes metrics across the full curve_type/alpha axis without re-simulation, and collects results in a single `SweepResult` with bounded memory use
**Depends on**: Phase 9
**Requirements**: SWEP-01, SWEP-02, SWEP-03, SWEP-04, SWEP-05, SWEP-06, SWEP-07
**Success Criteria** (what must be TRUE):
  1. A `SweepConfig` with 2 curve types, 3 alpha values, and 2 allocation strategies produces exactly 12 result rows in `SweepResult.summary_df` (cartesian product, not zip)
  2. Memory usage does not accumulate unboundedly — raw cadCAD results are released after each config's metrics are computed
  3. Sweep execution shows a tqdm progress bar indicating cells completed out of total
  4. Sweep grid parameters (curve types, alpha values, lock profiles) are configurable via TOML without code changes
**Plans**: 2 plans
- [ ] 10-01-PLAN.md — SweepConfig/SweepCell/SweepResult dataclasses, cartesian grid enumeration, TOML config loading
- [ ] 10-02-PLAN.md — run_sweep() with ProcessPoolExecutor parallelism, tqdm progress, memory management

### Phase 10.1: Integration Wiring Fixes
**Goal**: Cross-phase integration issues in completed phases 8-10 are resolved — _nakamoto() follows the NaN-for-degenerate convention, mc_dist is reachable from the sweep grid and pipeline, and VoteTimingConfig is properly exported
**Depends on**: Phase 10
**Requirements**: Closes INT-01, INT-02, INT-03, INT-04
**Gap Closure:** Closes integration gaps from v3.0 audit
**Success Criteria** (what must be TRUE):
  1. `_nakamoto()` returns `np.nan` (not `0`) when called with zero-weight arrays
  2. `sweep.py` uses `np.nanmean` for all metric aggregation (not `np.mean`)
  3. `SweepConfig` accepts `mc_dists` axis and `_run_cell()` passes `mc_dist` to `generate_scenario()`
  4. `run_pipeline()` accepts and passes through `mc_dist` and `vote_timing` parameters
  5. `VoteTimingConfig` is importable from `backtesting.data`
**Plans**: 1 plan
- [ ] 10.1-01-PLAN.md — Fix _nakamoto() NaN convention, wire mc_dist through sweep/pipeline, re-export VoteTimingConfig

### Phase 11: Extended Analysis
**Goal**: The simulation produces deep governance statistics — proposal flip breakdowns by margin class, per-voter influence shifts with a proper counterfactual baseline, 2D timing sensitivity, voter archetypes, and statistical significance tests — all operating on `SweepResult` output
**Depends on**: Phase 10
**Requirements**: ANAL-01, ANAL-02, ANAL-03, ANAL-04, ANAL-05, ANAL-06, ANAL-07
**Success Criteria** (what must be TRUE):
  1. `margin_class_breakdown()` returns flip counts in three classes (tight <10%, moderate 10–30%, decisive >30%) for a given results DataFrame
  2. `address_influence()` returns per-voter (legacy_share, signals_share, delta) using median lock duration as the counterfactual baseline — not raw legacy weight
  3. `timing_sensitivity()` produces a 2D heatmap matrix indexed by timing quantile and lock quantile (not a single aggregated number)
  4. Voters are classified into whale / medium / retail archetypes by stake quantile, and these labels are present in the analysis output
  5. Mann-Whitney U p-values and bootstrap confidence intervals are computed on influence distribution differences across configurations
**Plans**: 2 plans
- [ ] 11-01-PLAN.md — Create analysis.py with margin_class_breakdown, voter_archetypes, module structure (ANAL-01, ANAL-04, ANAL-07)
- [ ] 11-02-PLAN.md — Add address_influence, timing_sensitivity, influence_significance, bootstrap_ci (ANAL-02, ANAL-03, ANAL-05, ANAL-06)

### Phase 11.1: Wire vote_timing Through Sweep
**Goal**: vote_timing is a first-class sweep axis — SweepConfig accepts vote_timings, SweepCell carries vote_timing, and _run_cell() passes it to generate_scenario(), enabling cartesian sweep across timing distributions
**Depends on**: Phase 11
**Requirements**: MCAL-05 (sweep coverage)
**Gap Closure:** Closes GAP-1 (vote_timing not wired through sweep) and Flow "VoteTimingConfig sweep axis" from v3.0 audit
**Success Criteria** (what must be TRUE):
  1. `SweepCell` has a `vote_timing` field (optional `VoteTimingConfig`)
  2. `_run_cell()` passes `vote_timing` to `generate_scenario()` when present
  3. `SweepConfig` accepts a `vote_timings` axis for cartesian enumeration
  4. A sweep with 2 vote_timing configs produces distinct results per timing config
**Plans**: 1 plan
- [ ] 11.1-01-PLAN.md — Wire vote_timing through SweepConfig, SweepCell, _enumerate_cells, _run_cell, load_sweep_config + tests

### Phase 12: Report Bundle
**Goal**: A single `generate_sweep_report()` call produces a fully structured output directory with heatmaps, per-config detail plots, timing sensitivity figures, CSV/JSON exports, and a multi-panel composite figure — all visualization using correct orientation and colormaps
**Depends on**: Phase 11
**Requirements**: REPT-01, REPT-02, REPT-03, REPT-04, REPT-05, REPT-06, REPT-07, REPT-08
**Success Criteria** (what must be TRUE):
  1. `generate_sweep_report(sweep_result)` creates an output directory with `heatmaps/`, `detail/`, and `timing_sensitivity/` subdirectories populated with plot files
  2. Heatmaps use `origin='lower'` and a diverging colormap (RdYlGn) for signed delta metrics — y-axis is not inverted
  3. Full sweep results are exported as both `results.csv` (all rows, all metric columns) and `summary.json` (NaN-safe, no float NaN in JSON output)
  4. A multi-panel composite figure combining heatmaps, flip breakdown, and timing sensitivity exists as a single saved file
  5. Per-config detail plots are generated for the best and worst N configurations by a configurable metric
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Migrate | v1.0 | 1/1 | Complete | 2026-02-27 |
| 2. Verify | v1.0 | 0/1 | Skipped | - |
| 3. Foundation | v2.0 | 2/2 | Complete | 2026-02-27 |
| 4. cadCAD Integration | v2.0 | 2/2 | Complete | 2026-02-27 |
| 5. Metrics | v2.0 | 2/2 | Complete | 2026-02-27 |
| 6. Plots | v2.0 | 2/2 | Complete | 2026-02-27 |
| 7. Pipeline | v2.0 | 1/1 | Complete | 2026-02-27 |
| 8. Foundation Fixes & Budget Promotion | 3/3 | Complete   | 2026-02-28 | - |
| 9. Monte Carlo Allocation Modeling | 2/2 | Complete   | 2026-02-28 | - |
| 10. Sweep Runner | 2/2 | Complete    | 2026-02-28 | - |
| 10.1 Integration Wiring Fixes | 1/1 | Complete    | 2026-02-28 | - |
| 11. Extended Analysis | 2/2 | Complete    | 2026-02-28 | - |
| 11.1 Wire vote_timing Through Sweep | 1/1 | Complete    | 2026-02-28 | - |
| 12. Report Bundle | v3.0 | 0/TBD | Not started | - |
