---
phase: 11-extended-analysis
verified: 2026-02-28T14:05:48Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 11: Extended Analysis Verification Report

**Phase Goal:** The simulation produces deep governance statistics — proposal flip breakdowns by margin class, per-voter influence shifts with a proper counterfactual baseline, 2D timing sensitivity, voter archetypes, and statistical significance tests — all operating on SweepResult output
**Verified:** 2026-02-28T14:05:48Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `margin_class_breakdown()` returns tight/moderate/decisive flip counts from a results DataFrame | VERIFIED | Function exists at line 106 of analysis.py; `pd.cut` with bins `[0.0, 0.10, 0.30, 1.01]`; 3 tests pass (real data, no-flip, controlled-flip) |
| 2 | Voters are classified into whale/medium/retail archetypes by stake quantile | VERIFIED | `voter_archetypes()` at line 163 uses `pd.qcut(q=3, labels=['retail','medium','whale'])`; 2 tests pass including archetype label coverage |
| 3 | `analysis.py` is importable from `backtesting.analysis` and exports all public functions | VERIFIED | `__all__` confirmed with 6 functions + 6 dataclasses; import verified live; no cadCAD in source |
| 4 | `address_influence()` returns per-voter legacy_share, signals_share, delta using median lock duration as counterfactual baseline | VERIFIED | `delta = signals_share - counterfactual_share` (line 357); median_lock computed at line 321; test confirms `median_lock_days == 75.0` for known inputs |
| 5 | `timing_sensitivity()` produces a 2D DataFrame heatmap indexed by timing quantile and lock quantile | VERIFIED | `pivot_table(observed=True)` with T*/L* labels at lines 444-450; `result.heatmap.ndim == 2` test passes |
| 6 | Mann-Whitney U p-values are computed on influence distribution differences | VERIFIED | `influence_significance()` wraps `_mannwhitneyu(..., alternative='two-sided')`; 3 tests pass including degenerate NaN guard |
| 7 | Bootstrap confidence intervals are computed on aggregate metrics across runs | VERIFIED | `bootstrap_ci()` wraps `_bootstrap(..., method='percentile')`; 2 tests pass including degenerate NaN guard |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/simulations/src/backtesting/analysis.py` | Complete analysis module with all 6 functions | VERIFIED | 525 lines; 6 public functions, 6 frozen dataclasses; full `__all__`; no cadCAD imports |
| `apps/simulations/tests/test_analysis.py` | Full test coverage ANAL-01 through ANAL-07, min 150 lines | VERIFIED | 421 lines (> 150 min); 15 tests total; all 15 pass in 0.61s |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `analysis.py` | `backtesting.weighting.signals.compute_signals_weight` | import for counterfactual weight computation | VERIFIED | `from backtesting.weighting.signals import compute_signals_weight as _compute_signals_weight` at line 24; used in `address_influence()` and `timing_sensitivity()` |
| `analysis.py` | `scipy.stats.mannwhitneyu` | import for significance test | VERIFIED | `from scipy.stats import mannwhitneyu as _mannwhitneyu` at line 22; called at line 479 |
| `analysis.py` | `scipy.stats.bootstrap` | import for confidence intervals | VERIFIED | `from scipy.stats import bootstrap as _bootstrap` at line 21; called at line 513 |
| `test_analysis.py` | `backtesting.analysis` | import all public functions | VERIFIED | Lines 20-33 import all 6 functions and 6 dataclasses by name |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ANAL-01 | 11-01 | Flip breakdown by margin class: tight (<10%), moderate (10-30%), decisive (>30%) | SATISFIED | `margin_class_breakdown()` implemented; 3 tests pass with controlled margin assertions |
| ANAL-02 | 11-02 | Per-voter influence with median-lock counterfactual baseline | SATISFIED | `address_influence()` uses `median_lock = vote_df['lock_duration_days'].median()`; `delta = signals_share - counterfactual_share` (not legacy_share); test verifies `median_lock_days == 75.0` |
| ANAL-03 | 11-02 | 2D timing x lock quantile heatmap | SATISFIED | `timing_sensitivity()` returns 2D `pd.DataFrame` pivot table; `observed=True` suppresses FutureWarning; test asserts `ndim == 2` |
| ANAL-04 | 11-01 | Voter archetype classification (whale/medium/retail by stake quantile) | SATISFIED | `voter_archetypes()` with `pd.qcut(q=3)` and `duplicates='drop'` fallback |
| ANAL-05 | 11-02 | Mann-Whitney U p-values on influence distribution differences | SATISFIED | `influence_significance()` wraps `mannwhitneyu`; NaN guard for degenerate inputs; 3 tests pass |
| ANAL-06 | 11-02 | Bootstrap confidence intervals on aggregate metrics | SATISFIED | `bootstrap_ci()` wraps `scipy.stats.bootstrap` with percentile method; NaN guard; 2 tests pass |
| ANAL-07 | 11-01 | Cross-run analysis module (`analysis.py`) operating on SweepResult output | SATISFIED (with note) | Module is pure-function, no cadCAD imports, `__all__` complete; functions operate on `results_df` (per-event DataFrame) rather than `SweepResult.summary_df` — see note below |

**Note on ANAL-07 input type:** The REQUIREMENTS.md entry for ANAL-07 describes the module as "operating on `SweepResult.summary_df`", but the actual implementation operates on `results_df` (the 14-column per-event DataFrame from `build_results_dataframe`). This is the correct design: ANAL-02 (per-voter influence), ANAL-03 (timing sensitivity), and ANAL-04 (voter archetypes) all require individual vote-level data that does not exist in the aggregated `summary_df`. The RESEARCH.md document explicitly acknowledges this — ANAL-02 "requires access to per-vote DataFrame (not just summary_df)". The Plans were written correctly with `results_df` inputs, and all the analysis functions are usable from a sweep consumer that has access to per-run DataFrames. The requirement text is imprecise but the implementation satisfies the stated analytical goals.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

No TODOs, FIXMEs, placeholder returns, empty implementations, or stubs detected in either `analysis.py` or `test_analysis.py`.

---

### Human Verification Required

None. All phase goals are verifiable programmatically:

- All 15 tests run and pass (automated: `pytest tests/test_analysis.py`)
- Full 193-test suite passes with no regressions (automated: `pytest tests/`)
- All 4 claimed commits exist and are verified in git history (e1132a9, fa4ed3b, c525dee, 4daeda2)
- Import and `__all__` completeness verified by live Python invocation

---

### Gaps Summary

No gaps. All 7 observable truths are verified, all artifacts exist and are substantive, all key links are wired, all 7 requirement IDs are satisfied.

The only notable deviation from the ANAL-07 requirement wording ("operating on SweepResult.summary_df") is a clarification issue in the requirement text, not an implementation defect. The actual implementation correctly operates on per-event DataFrames, which is architecturally necessary and explicitly confirmed in the research document.

---

## Test Execution Evidence

```
============================= test session starts ==============================
platform linux -- Python 3.12.12

tests/test_analysis.py::test_anal07_module_importable PASSED
tests/test_analysis.py::test_anal01_margin_class_breakdown PASSED
tests/test_analysis.py::test_anal01_margin_class_no_flips PASSED
tests/test_analysis.py::test_anal01_margin_class_with_flips PASSED
tests/test_analysis.py::test_anal04_voter_archetypes PASSED
tests/test_analysis.py::test_anal04_archetypes_labels_present PASSED
tests/test_analysis.py::test_anal02_address_influence_counterfactual PASSED
tests/test_analysis.py::test_anal02_address_influence_median_lock_used PASSED
tests/test_analysis.py::test_anal03_timing_sensitivity_2d PASSED
tests/test_analysis.py::test_anal03_timing_sensitivity_custom_quantiles PASSED
tests/test_analysis.py::test_anal05_mannwhitney PASSED
tests/test_analysis.py::test_anal05_mannwhitney_same_distribution PASSED
tests/test_analysis.py::test_anal05_mannwhitney_degenerate PASSED
tests/test_analysis.py::test_anal06_bootstrap_ci PASSED
tests/test_analysis.py::test_anal06_bootstrap_ci_degenerate PASSED

======================== 15 passed, 1 warning in 0.61s =========================

Full suite: 193 passed, 10 warnings in 20.05s
```

## Commit Verification

All 4 commits claimed in SUMMARY.md exist in git history:

- `e1132a9` — feat(11-01): Create backtesting/analysis.py with margin_class_breakdown and voter_archetypes
- `fa4ed3b` — test(11-01): Add test_analysis.py covering ANAL-01, ANAL-04, ANAL-07
- `c525dee` — feat(11-02): Add four new analysis functions to analysis.py
- `4daeda2` — test(11-02): Add ANAL-02/03/05/06 tests to test_analysis.py

---

_Verified: 2026-02-28T14:05:48Z_
_Verifier: Claude (gsd-verifier)_
