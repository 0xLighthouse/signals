---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Backtesting & Simulation
status: unknown
last_updated: "2026-02-27T16:57:12Z"
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 5
  completed_plans: 5
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** Phase 5 — Metrics (plan 1 of 2 complete)

## Current Position

Phase: 5 of 7 (Metrics)
Plan: 1 of 2 in current phase (complete)
Status: Phase 5 in progress
Last activity: 2026-02-27 — Completed 05-01 (10 governance metric pure functions, frozen dataclasses, smoke test green)

Progress: [█████░░░░░] 50%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 5.4 min
- Total execution time: 27 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 03-foundation | 2/2 | 12 min | 6 min |
| 04-cadcad-integration | 2/2 | 11 min | 5.5 min |
| 05-metrics | 1/2 | 4 min | 4 min |

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

### Pending Todos

None.

### Blockers/Concerns

- [Resolved] cadCAD 0.5.x Executor.execute() pattern validated — Configuration + Executor approach works correctly, no Experiment.append_model() needed
- [Research flag] Lock curve alpha parameter has no empirically-grounded default — validate against veToken data during Phase 5 or 6

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 05-01-PLAN.md (10 governance metric pure functions, frozen dataclasses, smoke test)
Resume file: .planning/phases/05-metrics
Resume action: Plan 05-01 complete — begin 05-02 (metrics test suite)
