---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Backtesting & Simulation
status: unknown
last_updated: "2026-02-27T16:21:45.268Z"
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 4
  completed_plans: 3
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** Phase 4 — CadCAD Integration (event-replay simulation)

## Current Position

Phase: 4 of 7 (CadCAD Integration)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-27 — Completed 04-01 (cadCAD simulation subpackage — policies and SUFs)

Progress: [███░░░░░░░] 30%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 6.7 min
- Total execution time: 20 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 03-foundation | 2/2 | 12 min | 6 min |
| 04-cadcad-integration | 1/2 | 8 min | 8 min |

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

### Pending Todos

None.

### Blockers/Concerns

- [Research flag] cadCAD 0.5.x `Experiment.append_model()` behavior not fully confirmed — validate before Phase 4 implementation
- [Research flag] Lock curve alpha parameter has no empirically-grounded default — validate against veToken data during Phase 5 or 6

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 04-01-PLAN.md (cadCAD simulation subpackage)
Resume file: .planning/phases/04-cadcad-integration
Resume action: Execute 04-02-PLAN.md (cadCAD runner, Configuration, build_results_dataframe)
