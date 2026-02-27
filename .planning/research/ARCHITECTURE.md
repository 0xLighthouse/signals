# Architecture Research — v3.0 Sweep Engine & Extended Analysis

**Domain:** Parameter sweep engine, Monte Carlo allocation, extended governance analysis
**Researched:** 2026-02-27
**Confidence:** HIGH (existing code read directly; integration points verified)

---

## Integration Answers

### 1. Sweep Runner Placement

New module `backtesting/sweep.py` — NOT a wrapper around `run_pipeline()`.

**Why:** `run_pipeline()` has per-run I/O side effects (output directories, PNG generation per run). Inside a sweep loop, you want to accumulate results in memory and visualize cross-run comparisons after all configs complete.

The sweep runner calls inner stages directly:
```
generate_scenario() → run_backtest() → build_results_dataframe() → compute_*()
```

**Key optimization:** In v2.0, cadCAD stores raw `weight` and `lock_duration_days` per vote; `compute_signals_weight()` is called at metrics time, not simulation time. This means sweeping `curve_type` does NOT require re-running cadCAD — run cadCAD once per (stake_profile, lock_profile, allocation_strategy, seed) and compute metrics multiple times per curve type. Significant performance win.

### 2. Monte Carlo Allocation Integration

Promote `_VoterLedger` and `_compute_allocation_fraction` from `factory.py` to a new public module `backtesting/data/budget.py`.

Add `AllocationDistribution` dataclass (Beta/truncnorm/uniform parameterized). `generate_scenario()` gains an optional `mc_dist` parameter — fully backward compatible. `factory.py` imports from `budget.py`.

### 3. Extended Analysis Placement

Two-tier split:
- **Per-run analysis** (margin class flips, address influence) → extend `metrics.py` with new functions and result dataclasses
- **Cross-run sweep analysis** (timing sensitivity, heatmap pivoting) → new `backtesting/analysis.py` that takes `SweepResult.summary_df` as input

### 4. Heatmap/Report Bundle

Add sweep visualization functions to `plots.py` (heatmaps, sensitivity curves, per-config detail plots). New module `backtesting/report.py` provides `generate_sweep_report()` that orchestrates analysis + plotting + CSV/JSON export.

Output directory structure:
```
output/sweep_{timestamp}/
├── heatmaps/           # Metric heatmaps across parameter grid
├── detail/             # Per-configuration detail plots (best/worst configs)
├── timing_sensitivity/ # Timing analysis plots
├── sweep_summary.csv   # Full results table
└── sweep_summary.json  # Machine-readable results
```

---

## Recommended New/Modified Modules

```
apps/simulations/src/backtesting/
├── data/
│   ├── budget.py          # NEW: promoted _VoterLedger, AllocationDistribution, MC sampling
│   └── factory.py         # MODIFY: import from budget.py, add mc_dist parameter
├── sweep.py               # NEW: SweepConfig, SweepRunner, SweepResult
├── analysis.py            # NEW: cross-run analysis (heatmap pivoting, timing sensitivity)
├── metrics.py             # MODIFY: add margin_class_breakdown(), address_influence()
├── plots.py               # MODIFY: add heatmap, sensitivity curve, detail plot functions
├── report.py              # NEW: generate_sweep_report() orchestrator
└── pipeline.py            # UNCHANGED (single-config runs still work)
```

---

## Data Flow: Sweep Execution

```
SweepConfig (grid definition)
    │
    ▼
SweepRunner.run()
    │
    ├── For each (stake_profile, lock_profile, allocation_dist, seed):
    │   ├── generate_scenario() → events
    │   ├── run_backtest() → raw cadCAD results
    │   ├── build_results_dataframe() → results_df
    │   │
    │   └── For each curve_type × alpha:  ← metrics-only sweep (no re-sim!)
    │       └── compute_all_metrics(results_df, curve_type, alpha) → MetricsBundle
    │
    ▼
SweepResult
    ├── summary_df: DataFrame (one row per config, columns = metrics)
    ├── detail_results: dict[config_key, results_df]  (optional, for detail plots)
    │
    ▼
analysis.py
    ├── pivot_heatmap(summary_df, x_param, y_param, metric) → 2D array
    ├── timing_sensitivity(detail_results) → TimingSensitivityResult
    ├── margin_class_summary(summary_df) → MarginClassResult
    │
    ▼
report.py
    generate_sweep_report(sweep_result, output_dir)
        ├── heatmap plots (one per metric × parameter pair)
        ├── detail plots (best/worst N configs)
        ├── timing sensitivity plots
        ├── sweep_summary.csv
        └── sweep_summary.json
```

---

## Build Order (Dependency-Ordered)

| Step | Module | Depends On | Can Parallelize With |
|------|--------|------------|---------------------|
| 1 | `budget.py` | existing factory internals | Step 2 |
| 2 | Extended metrics (margin_class, address_influence) | existing metrics.py | Step 1 |
| 3 | `sweep.py` | budget.py + full metrics | — |
| 4 | `analysis.py` | sweep.py (SweepResult shape) | — |
| 5 | Sweep plot functions in `plots.py` | analysis.py output shapes | — |
| 6 | `report.py` | analysis + plots | — |

Steps 1 and 2 can develop in parallel (budget mechanics and extended metrics are independent).

The cadCAD-once / metrics-N-times optimization should be built into the sweep runner from day one — retrofitting later would require significant rework.

---

## Open Questions

- What Monte Carlo distribution parameters best model realistic DAO allocation behavior? (needs empirical grounding or literature review)
- Should the sweep CLI be a new `__main__` in `sweep.py` or added to the existing pipeline CLI?
- Detail plot subset: which cells (best/worst flip rate, highest/lowest Gini delta) are most useful for the report bundle?

---

*Architecture research for: Signals v3.0 — Sweep Engine & Extended Analysis*
*Researched: 2026-02-27*
