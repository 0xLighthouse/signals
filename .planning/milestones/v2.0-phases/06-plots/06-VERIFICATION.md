---
phase: 06-plots
verified: 2026-02-27T18:00:00Z
status: passed
score: 6/6 must-haves verified
re_verification: false
---

# Phase 06: Plots Verification Report

**Phase Goal:** Every metric has a corresponding publication-grade matplotlib figure
**Verified:** 2026-02-27T18:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All 11 plot functions return a matplotlib.figure.Figure object | VERIFIED | Every function uses `Figure(figsize=...)` + `add_subplot` OO API and `return fig`. 12/12 pytest assertions confirm `isinstance(fig, Figure)`. |
| 2 | No pyplot state — matplotlib.pyplot is never imported in plots.py | VERIFIED | `grep` finds zero matches for `matplotlib.pyplot` or `plt.` in plots.py. `test_plot_12_no_pyplot_state` passes, asserting pyplot is absent from `sys.modules` after importing the module. |
| 3 | rcParams are set once at module import for consistent publication styling | VERIFIED | Lines 28-48 of plots.py call `matplotlib.rcParams.update({...})` at module level with `font.family='serif'`, `axes.grid.axis='y'`, `savefig.dpi=300`, `axes.spines.top=False`, `axes.spines.right=False`, `legend.frameon=False`. Runtime check confirmed all values applied correctly. |
| 4 | Blue (#2196F3) represents Legacy, Orange (#FF9800) represents Signals in every chart | VERIFIED | Constants `BLUE = '#2196F3'` and `ORANGE = '#FF9800'` defined at lines 51-52. Every dual-regime bar/line uses these constants with matching `label='Legacy'` / `label='Signals'`. |
| 5 | Horizontal gridlines only, serif font, no top/right spines across all plots | VERIFIED | rcParams sets `axes.grid.axis='y'`, `font.family='serif'`, `axes.spines.top=False`, `axes.spines.right=False`. These are applied module-wide at import time. |
| 6 | Dual-regime charts include self-contained legends | VERIFIED | All 9 dual-regime functions (PLOT-01, 04, 05, 06, 07, 08, 09, 10, 11) call `ax.legend()` or combined `ax1.legend(lines1+lines2, labels1+labels2)`. PLOT-11 uses combined twinx legend pattern. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/simulations/src/backtesting/plots.py` | All 11 plot functions + module-level rcParams | VERIFIED | 478 lines. All 11 functions present and callable. `matplotlib.use('Agg')` is first matplotlib call (line 9). `rcParams.update()` at lines 28-48. BLUE/ORANGE constants at lines 51-52. No pyplot imports. |
| `apps/simulations/tests/test_plots.py` | 12 requirement-traced plot tests | VERIFIED | 182 lines. 12 tests collected and all pass. Each test has PLOT-XX docstring. Three-assertion pattern: `isinstance(fig, Figure)` + axes count + title substring. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `apps/simulations/src/backtesting/plots.py` | `backtesting.metrics` (FlipRateResult, GiniResult, etc.) | `from backtesting.metrics import` at module top (line 16) | WIRED | All 8 result dataclasses imported at module level. Runtime import succeeds. |
| `plot_lorenz_curve` / `plot_lock_duration_histogram` | `backtesting.weighting.signals.compute_signals_weight` | `from backtesting.weighting.signals import compute_signals_weight as _cw` inside function body | WIRED | Found at lines 325 and 438 inside function bodies. Internal import avoids circular dependency. Tests for PLOT-09 and PLOT-11 exercise these code paths and pass. |
| `apps/simulations/tests/test_plots.py` | `backtesting.plots` (all 11 functions) | `from backtesting.plots import` at test module top (lines 23-35) | WIRED | All 11 function names imported. 12 tests collected and executed against them. |
| `test_plot_12_no_pyplot_state` | `sys.modules` check | Module reimport + assertion | WIRED | Test deletes `backtesting.plots` from `sys.modules`, removes pyplot if present, reimports, then asserts `matplotlib.pyplot` not in `sys.modules`. Passes. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| PLOT-01 | 06-01-PLAN, 06-02-PLAN | Flip rate summary bar chart | SATISFIED | `plot_flip_rate_summary` in plots.py; `test_plot_01_flip_rate_returns_figure` passes |
| PLOT-02 | 06-01-PLAN, 06-02-PLAN | Margin shift histogram | SATISFIED | `plot_margin_shift_histogram` in plots.py; `test_plot_02_margin_shift_returns_figure` passes |
| PLOT-03 | 06-01-PLAN, 06-02-PLAN | Outcome transition matrix visualization | SATISFIED | `plot_transition_matrix` in plots.py; `test_plot_03_transition_matrix_returns_figure` passes |
| PLOT-04 | 06-01-PLAN, 06-02-PLAN | Gini before vs after comparison per regime | SATISFIED | `plot_gini_comparison` in plots.py; `test_plot_04_gini_comparison_returns_figure` passes |
| PLOT-05 | 06-01-PLAN, 06-02-PLAN | Top-k share comparison chart | SATISFIED | `plot_top_k_comparison` in plots.py; `test_plot_05_top_k_comparison_returns_figure` passes |
| PLOT-06 | 06-01-PLAN, 06-02-PLAN | ENP comparison visualization | SATISFIED | `plot_enp_comparison` in plots.py; `test_plot_06_enp_comparison_returns_figure` passes |
| PLOT-07 | 06-01-PLAN, 06-02-PLAN | Cumulative vote curve per proposal | SATISFIED | `plot_cumulative_vote_curve` in plots.py; `test_plot_07_cumulative_vote_curve_returns_figure` passes |
| PLOT-08 | 06-01-PLAN, 06-02-PLAN | Late-vote share comparison | SATISFIED | `plot_late_vote_share` in plots.py; `test_plot_08_late_vote_share_returns_figure` passes |
| PLOT-09 | 06-01-PLAN, 06-02-PLAN | Lorenz curve (legacy vs Signals voting power) | SATISFIED | `plot_lorenz_curve` in plots.py; `test_plot_09_lorenz_curve_returns_figure` passes (including >= 3 lines assertion) |
| PLOT-10 | 06-01-PLAN, 06-02-PLAN | Proposal story — time evolution of net margin | SATISFIED | `plot_proposal_story` in plots.py; `test_plot_10_proposal_story_returns_figure` passes (including >= 2 lines assertion) |
| PLOT-11 | 06-01-PLAN, 06-02-PLAN | Lock duration distribution histogram with Signals weight overlay | SATISFIED | `plot_lock_duration_histogram` in plots.py; `test_plot_11_lock_duration_histogram_returns_figure` passes |
| PLOT-12 | 06-01-PLAN, 06-02-PLAN | All plots use matplotlib OO API, publication-grade styling, consistent rcParams | SATISFIED | No pyplot imports; `matplotlib.use('Agg')` first; `rcParams.update()` at module import; `test_plot_12_no_pyplot_state` passes |

**Orphaned requirements:** None. All 12 PLOT requirements are claimed by both plan 01 and plan 02 and all are implemented.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No TODOs, FIXMEs, placeholders, empty implementations, or `return null`/`return {}` patterns found in plots.py or test_plots.py. Every function has a substantive body that produces and returns a real Figure object.

### Human Verification Required

#### 1. Visual appearance of publication-grade output

**Test:** Run `uv run python3 -c "import sys; sys.path.insert(0,'src'); import matplotlib; matplotlib.use('Agg'); import backtesting.plots as p; from backtesting.metrics import *; ..."` to generate actual figure PNGs and inspect them visually.
**Expected:** Serif font visible on axis labels/titles; horizontal-only gridlines in light grey; no top/right spines; consistent BLUE for Legacy and ORANGE for Signals; 300 DPI output readable at publication size.
**Why human:** rcParams are set correctly in code but visual rendering quality, font availability on the target system, and true publication-grade appearance require human eyes.

#### 2. Edge-case data rendering

**Test:** Call plot functions with data containing all-NaN per_proposal dictionaries, empty proposal sets, or proposals with zero votes.
**Expected:** Functions handle edge cases gracefully without rendering empty white figures or raising exceptions.
**Why human:** The NaN guards are coded (np.nan_to_num, filter-before-plot patterns) but visual correctness of degenerate cases cannot be fully asserted via title substring checks alone.

## Summary

Phase 06 goal is fully achieved. Every metric from Phase 5 has a corresponding publication-grade matplotlib Figure-returning function in `apps/simulations/src/backtesting/plots.py`. All 11 chart types are implemented using the OO API exclusively (no pyplot global state), with module-level rcParams ensuring consistent publication styling across all figures. All 12 PLOT requirements are satisfied with 12/12 passing pytest tests confirming correctness. No stubs, placeholders, or anti-patterns were detected.

---

_Verified: 2026-02-27T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
