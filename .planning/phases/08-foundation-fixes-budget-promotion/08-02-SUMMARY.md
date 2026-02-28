---
phase: 08-foundation-fixes-budget-promotion
plan: "02"
subsystem: simulations
tags: [python, budget, monte-carlo, dataclass, abc, scipy]

# Dependency graph
requires: []
provides:
  - backtesting.data.budget — public leaf module with VoterLedger, LockEntry, compute_allocation_fraction, AllocationStrategy
  - AllocationDistribution ABC hierarchy: BetaDistribution, UniformDistribution, TruncnormDistribution
  - budget.py exports via backtesting.data __init__.py
affects:
  - 09-monte-carlo-sweep
  - any plan importing from backtesting.data

# Tech tracking
tech-stack:
  added: [scipy.stats.truncnorm]
  patterns:
    - Leaf module pattern: budget.py imports only numpy/stdlib/scipy.stats, no backtesting internals
    - ABC + dataclass pattern for pluggable distribution sampling (AllocationDistribution hierarchy)
    - __post_init__ validation for fail-fast construction-time checks

key-files:
  created:
    - apps/simulations/src/backtesting/data/budget.py
  modified:
    - apps/simulations/src/backtesting/data/factory.py
    - apps/simulations/src/backtesting/data/__init__.py
    - apps/simulations/tests/test_factory.py

key-decisions:
  - "budget.py is a leaf module: imports only numpy, stdlib, scipy.stats — enables Phase 9 to import it without circular dependency"
  - "AllocationStrategy type alias moved to budget.py; factory.py re-exports it via import (backward compat)"
  - "BLOCKS_PER_DAY stays in factory.py — simulation constant, not a budget concept"
  - "AllocationDistribution subclasses use dataclass + __post_init__ for validated construction"

patterns-established:
  - "Leaf module promotion: private _Class -> public Class in budget.py, factory.py delegates via import"
  - "Distribution ABC: sample(rng, size) -> ndarray interface for MC pluggability"

requirements-completed: [BUDG-01, BUDG-05]

# Metrics
duration: 2min
completed: 2026-02-28
---

# Phase 08 Plan 02: Budget Promotion Summary

**Public budget.py leaf module with VoterLedger, LockEntry, compute_allocation_fraction, and AllocationDistribution hierarchy (Beta/Uniform/Truncnorm) promoted from factory.py internals**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-28T00:19:08Z
- **Completed:** 2026-02-28T00:21:09Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- Created `backtesting/data/budget.py` as a pure leaf module (no backtesting internal imports) with fully public VoterLedger, LockEntry, AllocationStrategy, and compute_allocation_fraction — identical logic to former private counterparts
- Added AllocationDistribution ABC with three concrete subclasses (BetaDistribution, UniformDistribution, TruncnormDistribution), each with validated construction via `__post_init__`
- Updated factory.py to import from budget.py (no private duplicates), updated __init__.py to re-export all budget.py names, and updated test_factory.py to import public VoterLedger from budget

## Task Commits

Each task was committed atomically:

1. **Task 1: Create budget.py leaf module** - `24158b9` (feat)
2. **Task 2: Update factory.py, __init__.py, test_factory.py** - `13d492c` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/data/budget.py` — New leaf module: LockEntry, VoterLedger, AllocationStrategy, compute_allocation_fraction, AllocationDistribution hierarchy
- `apps/simulations/src/backtesting/data/factory.py` — Removed private _LockEntry, _VoterLedger, _compute_allocation_fraction, AllocationStrategy; imports from budget.py
- `apps/simulations/src/backtesting/data/__init__.py` — Added budget.py imports and exports to __all__
- `apps/simulations/tests/test_factory.py` — Updated import from `_VoterLedger` (factory) to `VoterLedger` (budget)

## Decisions Made

- budget.py is a strict leaf module to prevent circular imports when Phase 9 imports it alongside factory.py
- BLOCKS_PER_DAY remains in factory.py — it is a simulation timing constant, not a budget/allocation concept
- AllocationStrategy type alias lives in budget.py; factory.py gets it via its import statement (backward compatible)
- AllocationDistribution subclasses use dataclass + __post_init__ for fail-fast construction-time parameter validation per CONTEXT.md decision

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 9 (MC sweep) can now import VoterLedger and AllocationDistribution from `backtesting.data.budget` without circular dependency risk
- AllocationDistribution hierarchy is ready for MC parameterization (pass BetaDistribution/UniformDistribution/TruncnormDistribution as config)
- All 16 test_factory.py tests pass — no regressions

---
*Phase: 08-foundation-fixes-budget-promotion*
*Completed: 2026-02-28*
