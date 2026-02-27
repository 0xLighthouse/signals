---
phase: 03-foundation
plan: 01
subsystem: data-schema
tags: [pydantic, pydantic-v2, numpy, backtesting, governor, weighting, pure-functions, protocol]

# Dependency graph
requires: []
provides:
  - "Pydantic v2 Governor event schema (ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent)"
  - "EventType and VoteSupport enums with Governor Bravo field names"
  - "GovernorDataLoader runtime-checkable Protocol"
  - "lock_curve() pure function with sqrt/linear/log/exp shapes, floor/cap normalization"
  - "compute_signals_weight() pure function (W = stake * f(lock_duration))"
  - "compute_legacy_weight() identity function for baseline comparison"
  - "Test suite: 81 tests covering DATA-01, DATA-06, WGHT-01 through WGHT-04"
affects: [03-02, 04-cadcad, 05-analysis]

# Tech tracking
tech-stack:
  added: [pydantic>=2.0.0, scipy>=1.13.0]
  patterns:
    - "Pydantic v2 BaseModel with @field_validator and @model_validator(mode='after') — NOT v1 @validator"
    - "runtime_checkable Protocol for structural typing — no inheritance required for data loader"
    - "Pure function module: no cadCAD, no pandas, no side effects — independently testable"
    - "Union type A | B syntax (Python 3.10+) for GovernorEvent discriminated union"
    - "lock_curve floor+scale normalization: f = floor + (1-floor)*raw ensures [floor, 1.0] range"

key-files:
  created:
    - apps/simulations/src/backtesting/__init__.py
    - apps/simulations/src/backtesting/data/__init__.py
    - apps/simulations/src/backtesting/data/schema.py
    - apps/simulations/src/backtesting/weighting/__init__.py
    - apps/simulations/src/backtesting/weighting/signals.py
    - apps/simulations/tests/test_schema.py
    - apps/simulations/tests/test_weighting.py
  modified:
    - apps/simulations/pyproject.toml

key-decisions:
  - "lock_duration_days embedded on VoteCastEvent (not separate table) — self-contained events for cadCAD event-replay"
  - "GovernorDataLoader uses typing.Protocol + @runtime_checkable — no inheritance needed for real data loaders"
  - "lock_curve floor=0.1 default — uncommitted voters get minimal weight, not silenced completely"
  - "cadcad import check in test uses line-by-line import scan, not substring match (avoids false positives from docstring mentions)"

patterns-established:
  - "Pattern 1: Pydantic v2 validators — @field_validator with @classmethod for single-field; @model_validator(mode='after') for cross-field"
  - "Pattern 2: Pure function module isolation — weighting functions have zero external dependencies beyond numpy"
  - "Pattern 3: GovernorDataLoader Protocol — structural typing enables zero-cost swap between synthetic and real data"
  - "Pattern 4: Lock curve normalization — floor + (1-floor)*raw ensures output is always in [floor, 1.0]"

requirements-completed: [DATA-01, DATA-06, WGHT-01, WGHT-02, WGHT-03, WGHT-04]

# Metrics
duration: 4min
completed: 2026-02-27
---

# Phase 3 Plan 01: Foundation — Schema and Weighting Summary

**Pydantic v2 Governor event schema (3 models, 2 enums, runtime-checkable Protocol) and pure weighting functions (lock_curve with 4 shapes, compute_signals_weight = stake * f(L), compute_legacy_weight = identity) with 81 passing tests**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-02-27T15:45:27Z
- **Completed:** 2026-02-27T15:49:14Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Established the Governor-compatible event schema with Pydantic v2 models for PROPOSAL_CREATED, VOTE_CAST, and PROPOSAL_FINALIZED using Governor Bravo field names — Pydantic rejects malformed events at construction time
- Implemented pure weighting functions (`lock_curve`, `compute_signals_weight`, `compute_legacy_weight`) isolated from cadCAD — the core scientific claim W = stake * f(lock_duration) is independently testable
- Created 81-test suite covering DATA-01, DATA-06 (schema validation), and WGHT-01 through WGHT-04 (weighting functions) — all tests green

## Task Commits

Each task was committed atomically:

1. **Task 1: Package structure, schema, and weighting modules** - `7f038f6` (feat)
2. **Task 2: Test suite for schema and weighting** - `839f819` (feat)

**Plan metadata:** (docs commit — recorded after state updates)

## Files Created/Modified

- `apps/simulations/src/backtesting/__init__.py` — Package init with version
- `apps/simulations/src/backtesting/data/__init__.py` — Re-exports all schema types
- `apps/simulations/src/backtesting/data/schema.py` — EventType, VoteSupport enums; ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent Pydantic v2 models; GovernorEvent union type; GovernorDataLoader runtime-checkable Protocol
- `apps/simulations/src/backtesting/weighting/__init__.py` — Re-exports all weighting functions
- `apps/simulations/src/backtesting/weighting/signals.py` — lock_curve() (4 curve types), compute_signals_weight(), compute_legacy_weight() — no cadCAD/pandas imports
- `apps/simulations/tests/test_schema.py` — 31 tests: enum values, model construction, 6 ValidationError rejection cases, defaults, Protocol isinstance, model_dump()
- `apps/simulations/tests/test_weighting.py` — 50 tests: no-cadCAD check, all 4 curve types (floor/cap/range/monotonic), diminishing returns, signals formula, weight<=stake invariant, legacy identity, custom floor/lmax
- `apps/simulations/pyproject.toml` — Added `src/backtesting` to hatch wheel build targets

## Decisions Made

- lock_duration_days embedded directly on VoteCastEvent (not a separate locks table) — keeps events self-contained for cadCAD event-replay where each timestep reads one dict without joins
- GovernorDataLoader Protocol uses `@runtime_checkable` structural typing — real data loaders don't need to inherit, enabling zero-architecture-change swap from synthetic to real Governor data
- lock_curve floor=0.1 confirmed as the default — uncommitted voters (L=0) receive 10% weight rather than being silenced
- cadcad import check in test_weighting.py scans import/from lines only (not full source substring) to avoid false positives from docstring comments mentioning "no cadCAD"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed over-broad cadcad import detection in test**
- **Found during:** Task 2 (test suite creation)
- **Issue:** The test `'cadcad' not in source.lower()` matched the docstring comment "no cadcad" in signals.py, causing a false positive test failure
- **Fix:** Changed test to scan only lines starting with `import` or `from` — checks actual Python import statements, not docstring prose
- **Files modified:** `apps/simulations/tests/test_weighting.py`
- **Verification:** `uv run pytest tests/test_weighting.py::TestNoCadCADImport -v` passes
- **Committed in:** `839f819` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in test logic)
**Impact on plan:** Minimal — the fix makes the test semantically correct. signals.py has zero cadCAD imports as required.

## Issues Encountered

- The plan spec says "compute deltas at 30, 60, 90, 180 days" for diminishing returns. These are not sequential 30-day windows — comparing delta(0→30) vs delta(90→180) would fail because the 90-day span naturally accumulates more than a 30-day span. The test was written to use sequential 30-day steps (0→30, 30→60, 60→90, 90→120) which correctly verifies sqrt concavity as documented in RESEARCH.md. This matches the research-verified deltas: 0.107, 0.082, 0.069.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Schema and weighting layer complete — ready for Phase 3 Plan 02 (synthetic data factory and loader)
- `GovernorDataLoader` Protocol defined — factory and parquet loader will implement it in 03-02
- `lock_curve()` and `compute_signals_weight()` available for cadCAD policy integration in Phase 4
- All 6 requirements (DATA-01, DATA-06, WGHT-01 through WGHT-04) satisfied and tested

## Self-Check: PASSED

All files found and commits verified:
- FOUND: apps/simulations/src/backtesting/__init__.py
- FOUND: apps/simulations/src/backtesting/data/__init__.py
- FOUND: apps/simulations/src/backtesting/data/schema.py
- FOUND: apps/simulations/src/backtesting/weighting/__init__.py
- FOUND: apps/simulations/src/backtesting/weighting/signals.py
- FOUND: apps/simulations/tests/test_schema.py
- FOUND: apps/simulations/tests/test_weighting.py
- FOUND: .planning/phases/03-foundation/03-01-SUMMARY.md
- COMMIT 7f038f6: feat(03-01): Add backtesting package with Governor event schema and pure weighting functions
- COMMIT 839f819: feat(03-01): Add test suite for schema (DATA-01, DATA-06) and weighting (WGHT-01 through WGHT-04)

---
*Phase: 03-foundation*
*Completed: 2026-02-27*
