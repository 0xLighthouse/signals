---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Backtesting & Simulation
status: unknown
last_updated: "2026-02-27T16:26:52.067Z"
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** Phase 4 — CadCAD Integration (complete)

## Current Position

Phase: 4 of 7 (CadCAD Integration)
Plan: 2 of 2 in current phase (complete)
Status: Phase 4 complete
Last activity: 2026-02-27 — Completed 04-02 (cadCAD runner, build_results_dataframe, all 8 SIM tests green)

Progress: [████░░░░░░] 40%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 5.8 min
- Total execution time: 23 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 03-foundation | 2/2 | 12 min | 6 min |
| 04-cadcad-integration | 2/2 | 11 min | 5.5 min |
| Phase 04-cadcad-integration P02 | 3 | 2 tasks | 4 files |

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

### Pending Todos

None.

### Blockers/Concerns

- [Resolved] cadCAD 0.5.x Executor.execute() pattern validated — Configuration + Executor approach works correctly, no Experiment.append_model() needed
- [Research flag] Lock curve alpha parameter has no empirically-grounded default — validate against veToken data during Phase 5 or 6

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 04-02-PLAN.md (cadCAD runner, build_results_dataframe, all 8 SIM tests)
Resume file: .planning/phases/04-cadcad-integration
Resume action: Phase 4 complete — begin Phase 5 (metrics analysis)
