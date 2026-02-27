---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Signals Backtesting & Simulation
status: ready_to_plan
last_updated: "2026-02-27"
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 6
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** Phase 3 — Foundation (schema, data factory, weighting)

## Current Position

Phase: 3 of 7 (Foundation)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-27 — Completed 03-01 (schema and weighting foundation)

Progress: [█░░░░░░░░░] 10%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 4 min
- Total execution time: 4 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 03-foundation | 1/2 | 4 min | 4 min |

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

### Pending Todos

None.

### Blockers/Concerns

- [Research flag] cadCAD 0.5.x `Experiment.append_model()` behavior not fully confirmed — validate before Phase 4 implementation
- [Research flag] Lock curve alpha parameter has no empirically-grounded default — validate against veToken data during Phase 5 or 6

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 03-01-PLAN.md — schema and weighting foundation done
Resume file: None
