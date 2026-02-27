# Roadmap: Signals

## Milestones

- ✅ **v1.0 Poetry to uv Migration** — Phases 1-2 (shipped 2026-02-27)
- 🚧 **v2.0 Backtesting & Simulation** — Phases 3-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 Poetry to uv Migration (Phases 1-2) — SHIPPED 2026-02-27</summary>

- [x] Phase 1: Migrate (1/1 plans) — completed 2026-02-27
- [ ] Phase 2: Verify (skipped) — verification requirements deferred

</details>

### 🚧 v2.0 Backtesting & Simulation (In Progress)

**Milestone Goal:** Build a complete simulation + analysis pipeline: synthetic data → cadCAD replay → Signals weighting → metrics → publication-grade plots.

- [x] **Phase 3: Foundation** - Governor-compatible event schema, synthetic data factory, and Signals weight functions (completed 2026-02-27)
- [x] **Phase 4: cadCAD Integration** - Event-replay state machine, dual-tally simulation, and results DataFrame (completed 2026-02-27)
- [x] **Phase 5: Metrics** - Complete metrics suite as pure functions on results DataFrame (completed 2026-02-27)
- [x] **Phase 6: Plots** - Publication-grade matplotlib plotting suite for all metrics (completed 2026-02-27)
- [ ] **Phase 7: Pipeline** - Single orchestrating entry point tying all layers together

## Phase Details

### Phase 3: Foundation
**Goal**: A testable data and weighting layer exists that can be exercised without cadCAD
**Depends on**: Nothing (first v2.0 phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06, DATA-07, DATA-08, DATA-09, WGHT-01, WGHT-02, WGHT-03, WGHT-04
**Success Criteria** (what must be TRUE):
  1. A valid Governor-compatible event stream (PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED) can be generated with configurable voter counts, proposal counts, and participation rates
  2. Generated stake distribution has Gini >= 0.65 (validated by test), and vote timing follows tri-modal distribution
  3. Pydantic v2 rejects malformed events at construction time (double votes, out-of-window votes, missing fields)
  4. Signals weight W = stake × f(lock_duration) and legacy weight W = stake are computable as pure functions with no cadCAD import
  5. Data loader interface accepts both synthetic and real Governor data through the same API
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — Pydantic v2 event schema, enums, Protocol, and pure weighting functions (lock curve + signals/legacy weight)
- [ ] 03-02-PLAN.md — Synthetic event stream factory with configurable profiles and data loader with fail-fast validation

### Phase 4: cadCAD Integration
**Goal**: A working end-to-end simulation consumes the event stream and produces both tallies in a single pass
**Depends on**: Phase 3
**Requirements**: SIM-01, SIM-02, SIM-03, SIM-04, SIM-05, SIM-06, SIM-07, SIM-08
**Success Criteria** (what must be TRUE):
  1. cadCAD state machine consumes a pre-sorted event list one event per timestep without raising errors
  2. Each proposal carries both a legacy (stake) tally and a Signals (W_signals) tally simultaneously in state after simulation completes
  3. State update functions return new copies — never mutate in-place — confirmed by identity assertion in tests
  4. Simulation outputs a flat results DataFrame with one row per event covering both tally regimes
**Plans**: 2 plans

Plans:
- [ ] 04-01-PLAN.md — cadCAD policy + SUF modules and SIM unit tests (SIM-02 through SIM-07)
- [ ] 04-02-PLAN.md — runner.py wiring cadCAD Configuration, results DataFrame builder, and SIM integration tests (SIM-01, SIM-08)

### Phase 5: Metrics
**Goal**: Every required metric is computable as a pure function on the results DataFrame
**Depends on**: Phase 4
**Requirements**: METR-01, METR-02, METR-03, METR-04, METR-05, METR-06, METR-07, METR-08, METR-09, METR-10
**Success Criteria** (what must be TRUE):
  1. Flip rate, Gini, participation rate, ENP, Nakamoto coefficient, and margin shift are each computable from the results DataFrame alone with no cadCAD import
  2. Outcome transition matrix correctly classifies all four proposal outcome combinations (Pass→Pass, Pass→Fail, Fail→Pass, Fail→Fail)
  3. Late-vote share and lock-in timing metrics correctly identify time-sensitive voting behavior per proposal
  4. Top-k concentration is computable for top-1, top-5, and top-10 voters under both tally regimes
**Plans**: 2 plans

Plans:
- [ ] 05-01-PLAN.md — metrics.py implementation: all 10 governance metric pure functions with frozen dataclass return types
- [ ] 05-02-PLAN.md — test_metrics.py: 10 requirement-traced tests + conftest metrics fixtures

### Phase 6: Plots
**Goal**: Every metric has a corresponding publication-grade matplotlib figure
**Depends on**: Phase 5
**Requirements**: PLOT-01, PLOT-02, PLOT-03, PLOT-04, PLOT-05, PLOT-06, PLOT-07, PLOT-08, PLOT-09, PLOT-10, PLOT-11, PLOT-12
**Success Criteria** (what must be TRUE):
  1. All 11 chart types render to file without error using matplotlib OO API exclusively (no pyplot state)
  2. Legacy vs Signals comparison is visually present in every dual-regime chart (margins, Gini, ENP, top-k, late-vote share, Lorenz curve)
  3. Proposal story plots show time evolution of net margin and voter power composition for a selected proposal
  4. All plots share consistent publication-grade rcParams set once at module import
**Plans**: 2 plans

Plans:
- [ ] 06-01-PLAN.md — plots.py: all 11 publication-grade plot functions with module-level rcParams (PLOT-01 through PLOT-12)
- [ ] 06-02-PLAN.md — test_plots.py: 12 requirement-traced tests verifying Figure returns and OO API compliance

### Phase 7: Pipeline
**Goal**: The complete data → simulation → metrics → plots workflow runs from a single command
**Depends on**: Phase 6
**Requirements**: PIPE-01, PIPE-02, PIPE-03
**Success Criteria** (what must be TRUE):
  1. Running `python -m backtesting.pipeline` (or equivalent CLI) executes the full pipeline end-to-end without manual steps
  2. All plot files and metric outputs are written to a user-specified output directory
  3. The pipeline can be imported as a Python module and invoked programmatically with the same behavior as CLI
**Plans**: TBD

Plans:
- [ ] 07-01: Pipeline orchestration (PIPE-01 through PIPE-03)

## Progress

**Execution Order:**
Phases execute in numeric order: 3 → 4 → 5 → 6 → 7

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Migrate | v1.0 | 1/1 | Complete | 2026-02-27 |
| 2. Verify | v1.0 | 0/1 | Skipped | - |
| 3. Foundation | 2/2 | Complete   | 2026-02-27 | - |
| 4. cadCAD Integration | 2/2 | Complete   | 2026-02-27 | - |
| 5. Metrics | 2/2 | Complete   | 2026-02-27 | - |
| 6. Plots | 2/2 | Complete   | 2026-02-27 | - |
| 7. Pipeline | v2.0 | 0/1 | Not started | - |
