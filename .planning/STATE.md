---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Backtesting & Simulation
status: unknown
last_updated: "2026-02-27T17:34:50.761Z"
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 8
  completed_plans: 8
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** Phase 7 — Pipeline (Phase 6 complete)

## Current Position

Phase: 6 of 7 (Plots) — COMPLETE
Plan: 2 of 2 in phase 6 (complete)
Status: Phase 6 complete — Phase 7 ready to begin
Last activity: 2026-02-27 — Completed 06-02 (12 requirement-traced plot tests, PLOT-01..12 all passing)

Progress: [████████░░] 80%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 5.0 min
- Total execution time: 30 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 03-foundation | 2/2 | 12 min | 6 min |
| 04-cadcad-integration | 2/2 | 11 min | 5.5 min |
| 05-metrics | 2/2 | 7 min | 3.5 min |
| Phase 06-plots P01 | 2 | 1 tasks | 1 files |
| Phase 06-plots P02 | 2 | 1 tasks | 1 files |

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

- Fresh start for v2.0 — old simulation code can be replaced
- Governor-compatible event schema enables zero-cost swap from synthetic to real DAO data
- Weighting pure functions isolated from cadCAD — independently testable
- cadCAD phase isolated (Phase 4) — failures are immediately attributable, not mixed with metrics
- lock_duration_days embedded on VoteCastEvent (not separate table) — self-contained events for cadCAD event-replay
- GovernorDataLoader uses typing.Protocol + @runtime_checkable — no inheritance needed for real data loaders
- lock_curve floor=0.1 default — uncommitted voters get minimal weight, not silenced
- cadcad import check in tests uses line-by-line import scan to avoid docstring false positives
- [Phase 03-foundation]: Gini test uses full stake distribution not vote sample — subsample of participating voters underrepresents inequality
- [Phase 03-foundation]: Factory clamps vote blocks to window to guarantee synthetic data passes validation without errors
- [Phase 04-cadcad-integration]: No cadCAD imports in policies.py or sufs.py — pure Python, cadCAD wired only in runner.py (Plan 02)
- [Phase 04-cadcad-integration]: suf_tallies deepcopies tallies as first operation — guarantees SIM-07 identity check passes for all event types
- [Phase 04-cadcad-integration]: PSUBS defined in sufs.py alongside SUFs for cohesion — runner.py imports PSUBS as single wiring point
- [Phase 04-cadcad-integration]: tuple(event_records) for M param in cadCAD Configuration — prevents sweep, treats stream as single parameter
- [Phase 04-cadcad-integration]: build_results_dataframe skips raw_result[0] (initial state) and aligns by position — deterministic, no key lookups
- [Phase 04-cadcad-integration]: All 6 tally columns explicitly cast to float64 after DataFrame construction — handles None values from non-tally events
- [Phase 04-cadcad-integration]: Consolidated minimal_event_records to conftest fixture — single source of truth for all 8 SIM tests
- [Phase 04-cadcad-integration]: tuple(event_records) for M param in cadCAD Configuration — prevents sweep, treats stream as single parameter
- [Phase 04-cadcad-integration]: build_results_dataframe skips raw_result[0] (initial state), aligns by position — deterministic, no key lookups
- [Phase 04-cadcad-integration]: All 6 tally columns explicitly cast to float64 after DataFrame construction — handles None values from non-tally events
- [Phase 05-metrics]: Renamed compute_signals_weight import to _compute_signals_weight — keeps exactly 10 public compute_ names in module namespace for verification
- [Phase 05-metrics]: runner.py _to_dict() normalises Pydantic factory objects and dicts — both test fixtures and smoke test pass without changes to either
- [Phase 05-metrics]: dict[str, T] not pd.Series in frozen dataclasses — avoids Series equality conflict with frozen fields
- [Phase 05-metrics 05-02]: metrics_results_df uses sample_events (seed=42) — consistent 50-voter 5-proposal base for all 10 metric tests
- [Phase 05-metrics 05-02]: test_tie_is_fail uses inline synthetic DataFrame — edge case cleanly isolated without fixture dependency
- [Phase 05-metrics 05-02]: isnan guards on timing metrics (METR-08, METR-09) — NaN is valid return when no lock-in occurs
- [Phase 06-plots]: compute_signals_weight imported as _cw inside plot_lorenz_curve and plot_lock_duration_histogram function bodies — avoids circular import at module level
- [Phase 06-plots]: Test file sets matplotlib.use('Agg') before any Figure import in test_plots.py — ensures headless CI compatibility
- [Phase 06-plots]: PLOT-12 test deletes backtesting.plots from sys.modules, clears pyplot, reimports, asserts pyplot still absent — catches lazy imports too

### Pending Todos

None.

### Blockers/Concerns

- [Resolved] cadCAD 0.5.x Executor.execute() pattern validated — Configuration + Executor approach works correctly, no Experiment.append_model() needed
- [Research flag] Lock curve alpha parameter has no empirically-grounded default — validate against veToken data during Phase 5 or 6

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 06-02-PLAN.md (12 requirement-traced plot tests, PLOT-01..12 covered)
Resume file: .planning/phases/06-plots
Resume action: Phase 6 complete — begin Phase 7 (pipeline)
