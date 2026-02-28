---
phase: 08-foundation-fixes-budget-promotion
verified: 2026-02-28T00:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 8: Foundation Fixes & Budget Promotion Verification Report

**Phase Goal:** The codebase is clean and correctly instrumented for sweep work — bugs that would silently corrupt heatmaps are eliminated, and the budget/lock constraint system is a properly testable public module with curve_type as a first-class parameter
**Verified:** 2026-02-28
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from Phase Success Criteria)

| #   | Truth                                                                                              | Status     | Evidence                                                                              |
| --- | -------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------- |
| 1   | `_gini()` returns `np.nan` (not `0.0`) when called with a zero-sum array                          | VERIFIED | `_gini(np.array([0.0, 0.0, 0.0]))` returns `nan`, `math.isnan()` confirms; `metrics.py` line 38-39 |
| 2   | `_enp()` returns `np.nan` (not `0.0`) when called with a zero-weight array                        | VERIFIED | `_enp(np.array([0.0, 0.0, 0.0]))` returns `nan`; `metrics.py` line 51-52             |
| 3   | `generate_scenario(curve_type='log')` runs without error and produces metrics using the log curve  | VERIFIED | Executes, returns events; `compute_gini(df, curve_type='log')` = 0.6189 vs sqrt 0.6383 — values differ, confirming log curve is active |
| 4   | `budget.py` module exists with public `VoterLedger`, `AllocationDistribution`, and `compute_allocation_fraction` — importable and unit-testable independently of the factory | VERIFIED | `budget.py` is a leaf module (no `backtesting.*` imports); all three names import cleanly; `VoterLedger.available_balance()` and `BetaDistribution.sample()` work correctly |
| 5   | All 147 existing tests pass after the refactor                                                     | VERIFIED | `152 passed, 3 warnings in 18.79s` — 152 tests (147 pre-existing + 5 new regression tests added in Phase 8) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Status | Details |
| -------- | ------ | ------- |
| `apps/simulations/src/backtesting/metrics.py` | VERIFIED | `_gini` and `_enp` fixed with `float(np.nan)` returns; `_add_signals_weight_column` and all 6 metric functions accept `curve_type` param |
| `apps/simulations/tests/test_metrics.py` | VERIFIED | 3 NaN regression tests added: `test_gini_zero_sum_returns_nan`, `test_gini_empty_array_returns_nan`, `test_enp_zero_weight_returns_nan` |
| `apps/simulations/src/backtesting/data/budget.py` | VERIFIED | Created as leaf module with `LockEntry`, `VoterLedger`, `AllocationStrategy`, `compute_allocation_fraction`, and full `AllocationDistribution` hierarchy |
| `apps/simulations/src/backtesting/data/factory.py` | VERIFIED | Private `_VoterLedger`, `_LockEntry`, `_compute_allocation_fraction` removed; imports from `budget.py`; `generate_scenario()` has `curve_type` param with validation |
| `apps/simulations/src/backtesting/data/__init__.py` | VERIFIED | Exports `VoterLedger`, `LockEntry`, `AllocationDistribution`, `BetaDistribution`, `UniformDistribution`, `TruncnormDistribution`, `compute_allocation_fraction` |
| `apps/simulations/src/backtesting/simulation/runner.py` | VERIFIED | `run_backtest(event_records, curve_type='sqrt')` — `curve_type` in cadCAD `M` dict at line 53 |
| `apps/simulations/src/backtesting/simulation/sufs.py` | VERIFIED | `suf_tallies` reads `curve_type = params.get('curve_type', 'sqrt')` and passes to `compute_signals_weight` at line 54 |
| `apps/simulations/src/backtesting/pipeline.py` | VERIFIED | `_GENERATE_SCENARIO_KEYS` includes `'curve_type'`; extracted from config and threaded to `run_backtest` and all 6 metric functions |
| `apps/simulations/tests/test_factory.py` | VERIFIED | Imports `VoterLedger` from `backtesting.data.budget` (not `_VoterLedger` from factory); 2 new curve_type tests added |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `_gini()` | `return float(np.nan)` | zero-sum guard | WIRED | `metrics.py` line 38-39: `if n == 0 or arr.sum() == 0: return float(np.nan)` |
| `_enp()` | `return float(np.nan)` | zero-weight guard | WIRED | `metrics.py` line 51-52: `if total == 0: return float(np.nan)` |
| `generate_scenario(curve_type=)` | `run_backtest(curve_type=)` | caller pipeline | WIRED | `pipeline.py` line 263-267: extracts `curve_type` from config, passes to `run_backtest` |
| `run_backtest(curve_type=)` | cadCAD `M` dict | constructor | WIRED | `runner.py` line 53: `'curve_type': curve_type` in `M` dict |
| cadCAD `M` dict `curve_type` | `compute_signals_weight(curve_type=)` | `suf_tallies` | WIRED | `sufs.py` line 51+54: reads from `params.get('curve_type', 'sqrt')`, passes to `compute_signals_weight` |
| `_add_signals_weight_column(curve_type=)` | `_compute_signals_weight` | `np.vectorize` scalar broadcast | WIRED | `metrics.py` line 81-84: `curve_type` passed as third positional arg to vectorized call |
| 6 metric functions `curve_type=` | `_add_signals_weight_column(curve_type)` | forwarding | WIRED | All 6 functions confirmed at lines 258, 290, 310, 393, 427, 449 |
| `pipeline.py` | all 6 metric functions `curve_type=` | explicit kwarg | WIRED | `pipeline.py` lines 280-288: all calls use `curve_type=curve_type` |
| `factory.py` | `budget.py` | `from backtesting.data.budget import ...` | WIRED | `factory.py` lines 25-30: imports `AllocationStrategy`, `LockEntry`, `VoterLedger`, `compute_allocation_fraction` |
| `budget.py` | stdlib/numpy/scipy only | leaf module | WIRED | No `backtesting.*` imports found in `budget.py` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| BUDG-01 | 08-02-PLAN | Promote `_VoterLedger` and `_compute_allocation_fraction` to public `backtesting/data/budget.py` | SATISFIED | `budget.py` exists with public names; factory.py delegates via import; no private duplicates remain |
| BUDG-02 | 08-01-PLAN | Fix `_gini()` to return `np.nan` for zero-sum arrays instead of `0.0` | SATISFIED | `metrics.py` line 39: `return float(np.nan)`; `test_gini_zero_sum_returns_nan` passes |
| BUDG-03 | 08-01-PLAN | Fix `_enp()` to return `np.nan` for zero-weight arrays instead of `0.0` | SATISFIED | `metrics.py` line 52: `return float(np.nan)`; `test_enp_zero_weight_returns_nan` passes |
| BUDG-04 | 08-03-PLAN | Thread `curve_type` as a parameter through `generate_scenario()` to metrics computation | SATISFIED | Full chain verified: factory -> runner -> cadCAD M dict -> suf_tallies -> compute_signals_weight; metrics layer independently via `_add_signals_weight_column` |
| BUDG-05 | 08-02-PLAN | Add `AllocationDistribution` dataclass to `budget.py` supporting Beta/truncnorm/uniform parameterization | SATISFIED | `BetaDistribution`, `UniformDistribution`, `TruncnormDistribution` all exist with `sample(rng, size)` interface and construction-time validation |
| BUDG-06 | 08-03-PLAN | All existing tests pass after budget promotion refactor | SATISFIED | 152 passed (exceeds 147 baseline — 5 new regression tests added) |

### Anti-Patterns Found

None. Scanned `budget.py`, `metrics.py`, `factory.py`, `runner.py`, `sufs.py`, `pipeline.py` for TODO/FIXME/HACK/placeholder comments, empty implementations, and stub returns. Zero findings.

### Human Verification Required

None. All success criteria are programmatically verifiable and were confirmed by direct execution.

### Gaps Summary

No gaps. All 5 success criteria were independently confirmed against the live codebase:

1. `_gini(np.array([0.0, 0.0, 0.0]))` confirmed to return `nan` at runtime.
2. `_enp(np.array([0.0, 0.0, 0.0]))` confirmed to return `nan` at runtime.
3. `generate_scenario(curve_type='log')` executes and produces metrics that differ from `curve_type='sqrt'` (gini.signals 0.6189 vs 0.6383), confirming the log curve is active end-to-end.
4. `budget.py` imports independently, contains all required public names, and is a true leaf module with no backtesting internal imports.
5. 152 tests pass (the 147 baseline plus 5 new regression tests added by Phase 8 plans).

The codebase is clean and correctly instrumented. Heatmap-corrupting bugs are eliminated. The budget/lock constraint system is a properly testable public module. `curve_type` is threaded as a first-class parameter through the full pipeline.

---

_Verified: 2026-02-28_
_Verifier: Claude (gsd-verifier)_
