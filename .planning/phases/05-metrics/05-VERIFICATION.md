---
phase: 05-metrics
verified: 2026-02-27T17:30:00Z
status: passed
score: 10/10 must-haves verified
re_verification: false
---

# Phase 5: Metrics Verification Report

**Phase Goal:** Every required metric is computable as a pure function on the results DataFrame
**Verified:** 2026-02-27T17:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `compute_flip_rate` returns a `FlipRateResult` with `per_proposal` dict and aggregate float | VERIFIED | Confirmed in metrics.py lines 220-233; test_flip_rate passes |
| 2 | `compute_gini` returns a `GiniResult` with both legacy and signals Gini coefficients | VERIFIED | metrics.py lines 236-247; test_gini passes |
| 3 | `compute_participation_rate` returns per-proposal and aggregate participation fractions | VERIFIED | metrics.py lines 250-264; test_participation_rate passes |
| 4 | `compute_enp` and `compute_nakamoto_coefficient` each return per-proposal dicts for both regimes | VERIFIED | metrics.py lines 267-303; test_enp and test_nakamoto_coefficient pass |
| 5 | `compute_margin_shift` returns per-proposal margin difference between regimes | VERIFIED | metrics.py lines 306-332; test_margin_shift passes |
| 6 | `compute_transition_matrix` returns a `TransitionMatrix` with counts and proportions | VERIFIED | metrics.py lines 335-362; test_transition_matrix passes |
| 7 | `compute_late_vote_share` and `compute_lockin_timing` accept `windows_df` as a second argument | VERIFIED | metrics.py lines 365-420; both timing tests pass |
| 8 | `compute_top_k_concentration` uses hardcoded `k=[1,5,10]` for both regimes | VERIFIED | `K_VALUES = [1, 5, 10]` at line 217; test_top_k_concentration confirms `set(result.legacy.keys()) == {1, 5, 10}` |
| 9 | No cadCAD import exists anywhere in metrics.py | VERIFIED | `grep cadcad metrics.py` returns nothing; module docstring says "No simulation framework imports" |
| 10 | All 10 functions return frozen dataclasses with named fields | VERIFIED | All 10 dataclasses have `@dataclass(frozen=True)`: FlipRateResult, GiniResult, ParticipationResult, ENPResult, NakamotoResult, MarginShiftResult, TransitionMatrix, LateVoteShareResult, LockinTimingResult, TopKConcentrationResult |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/simulations/src/backtesting/metrics.py` | All 10 governance metric pure functions | VERIFIED | 459 lines; 10 `compute_*` functions, 10 frozen dataclasses, 6 private helpers |
| `apps/simulations/tests/test_metrics.py` | 10 metric test functions + tie-is-fail | VERIFIED | 359 lines; 11 test functions, all passing |
| `apps/simulations/tests/conftest.py` | `metrics_results_df` and `metrics_windows_df` fixtures | VERIFIED | Lines 194-228 add Phase 5 fixtures; existing fixtures intact |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `metrics.py` | `backtesting.weighting.signals.compute_signals_weight` | import at top of module | WIRED | Line 17: `from backtesting.weighting.signals import compute_signals_weight as _compute_signals_weight`; aliased private to keep exactly 10 public `compute_*` names |
| `compute_gini / compute_enp / compute_nakamoto_coefficient / compute_top_k_concentration` | `VOTE_CAST` rows only | `event_type` filter | WIRED | All four functions filter `results_df['event_type'] == 'VOTE_CAST'` before any per-voter analysis (confirmed at lines 243, 274, 294, 431) |
| `compute_late_vote_share / compute_lockin_timing` | `windows_df` merge | `_merge_windows` helper | WIRED | Both functions call `_merge_windows(vote_df, windows_df)` (lines 379, 412); `_merge_windows` defined at lines 75-81 |
| `test_metrics.py` | `backtesting.metrics` | import | WIRED | Line 12: `from backtesting.metrics import (...)` — all 10 compute functions and all 10 result dataclasses imported |
| `metrics_results_df` fixture | `backtest_dataframe` / `sample_events` chain | fixture dependency | WIRED | `metrics_results_df(sample_events)` at conftest line 198 chains `run_backtest` + `build_results_dataframe` on the existing `sample_events` fixture |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| METR-01 | 05-01, 05-02 | Flip rate per-proposal and aggregate | SATISFIED | `compute_flip_rate` returns `FlipRateResult(per_proposal, aggregate)`; `test_flip_rate` validates types and range |
| METR-02 | 05-01, 05-02 | Gini coefficient over legacy and Signals distributions | SATISFIED | `compute_gini` returns `GiniResult(legacy, signals)`; test validates both in [0, 1] |
| METR-03 | 05-01, 05-02 | Participation rate per-proposal and aggregate | SATISFIED | `compute_participation_rate` returns `ParticipationResult`; test validates structure and range |
| METR-04 | 05-01, 05-02 | ENP = 1/sum(s_i^2) for both regimes | SATISFIED | `compute_enp` filters FOR/AGAINST, applies `_enp` per proposal, returns `ENPResult`; test validates ENP >= 1 |
| METR-05 | 05-01, 05-02 | Nakamoto coefficient min voters > 50% for both regimes | SATISFIED | `compute_nakamoto_coefficient` uses `_nakamoto`, returns `NakamotoResult`; test validates positive ints |
| METR-06 | 05-01, 05-02 | Margin shift between legacy and Signals per proposal | SATISFIED | `compute_margin_shift` computes (for-against)/(for+against) diff, guards zero denominator with nan; test validates |
| METR-07 | 05-01, 05-02 | Outcome transition matrix PP/PF/FP/FF | SATISFIED | `compute_transition_matrix` returns `TransitionMatrix(counts, proportions)`; test validates all proposals classified, proportions sum to 1 |
| METR-08 | 05-01, 05-02 | Late-vote share in final third of window | SATISFIED | `compute_late_vote_share(results_df, windows_df)` weight-based; test validates values in [0, 1] |
| METR-09 | 05-01, 05-02 | Lock-in timing fraction of window elapsed | SATISFIED | `compute_lockin_timing(results_df, windows_df)` uses `_compute_lockin_fraction`; test validates [0, 1] with nan guards |
| METR-10 | 05-01, 05-02 | Top-k concentration for k=1,5,10 both regimes | SATISFIED | `compute_top_k_concentration` uses hardcoded `K_VALUES=[1,5,10]`; test validates monotonicity and keys == {1,5,10} |

All 10 METR requirements from REQUIREMENTS.md are mapped to Phase 5 in the traceability table. Both plans (05-01 and 05-02) declare the full set METR-01..10. No orphaned requirements found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `tests/test_simulation.py` | 12 | `ImportError: cannot import name 'generate_summary_stats'` | Info | Pre-existing import failure in a file outside Phase 5 scope; documented in 05-02-SUMMARY.md as out-of-scope |

No blockers or warnings found in Phase 5 files. The `test_simulation.py` error is pre-existing and not introduced by this phase.

### Human Verification Required

None. All required behaviors are fully verifiable programmatically:

- All 11 tests pass (confirmed by live test run)
- All 10 frozen dataclasses verified via AST inspection
- No cadCAD import verified via grep
- Key links verified via code inspection
- K_VALUES hardcoding verified via regex
- 153 total tests pass with no regressions (excluding pre-existing broken `test_simulation.py`)

### Gaps Summary

No gaps. All 10 truths verified, all artifacts substantive and wired, all 10 METR requirements satisfied by implemented and tested functions.

**Notable implementation detail:** `compute_signals_weight` is imported under the private alias `_compute_signals_weight` (line 17). This is intentional — it keeps exactly 10 public `compute_*` names in the module namespace, matching the plan's verification invariant. The import to `backtesting.weighting.signals` is still present and wired correctly; the alias is a namespace hygiene decision, not a missing connection.

---

_Verified: 2026-02-27T17:30:00Z_
_Verifier: Claude (gsd-verifier)_
