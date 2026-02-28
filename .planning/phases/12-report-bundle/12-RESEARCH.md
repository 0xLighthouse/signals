# Phase 12: Report Bundle - Research

**Researched:** 2026-02-28
**Domain:** matplotlib visualization, data export, sweep report orchestration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

None — user gave full discretion across all implementation areas.

### Claude's Discretion

User gave full discretion across all implementation areas with guiding principles:

- **Optimize for compatibility** — standard formats (CSV with headers, NaN-safe JSON), widely-supported image formats, matplotlib defaults that render well across environments
- **Optimize for efficiency** — minimize redundant computation, reuse figure data across plot types where possible, batch file writes
- **Best practices** — follow matplotlib/visualization conventions, use established patterns from the existing codebase (phases 5, 6, 11)

Specific areas under discretion:
- Heatmap annotation style (cell value formatting, font sizing, colormap selection per metric type)
- Composite figure layout (panel arrangement, relative sizing, figure dimensions)
- Per-config detail plot content (what to show, default N for best/worst, default ranking metric)
- CSV column ordering and JSON summary structure
- Directory naming conventions and output organization
- Error handling for edge cases (empty results, single-config sweeps)

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REPT-01 | Heatmap plots per metric across parameter grid with correct orientation (`origin='lower'`) and diverging colormaps (RdYlGn for signed metrics) | Verified: `ax.imshow(data, origin='lower', cmap='RdYlGn')` works in matplotlib 3.10.8. `origin='lower'` requires explicit set — default is 'upper' (flipped). |
| REPT-02 | CSV export of full sweep results table | `summary_df.to_csv(path, index=False)` — already used by `run_sweep()` for `summary.csv`. REPT-02 exports the full per-cell table. |
| REPT-03 | JSON export of summary metrics with NaN sanitization | `_nan_to_none()` helper exists in `sweep.py` — handles `float` and `np.float64` (which is a subclass of float). CRITICAL: `np.int64` is NOT handled — needs explicit `int()` cast for `cell_id` column. |
| REPT-04 | Structured output directory (`heatmaps/`, `detail/`, `timing_sensitivity/`) | `pathlib.Path.mkdir(parents=True, exist_ok=True)` — same pattern as `_make_output_dir()` in `sweep.py`. |
| REPT-05 | Multi-panel composite figure combining heatmaps + flip breakdown + timing | `Figure.subplot_mosaic()` verified working in matplotlib 3.10.8 — cleaner than `add_subplot` for mixed-size layouts. |
| REPT-06 | Per-config detail plots for best/worst N configurations | `DataFrame.nlargest(n, col)` / `DataFrame.nsmallest(n, col)` — verified for extracting best/worst configs from `summary_df`. |
| REPT-07 | Annotated heatmaps showing cell values + color encoding | `ax.text(j, i, f'{val:.2f}', ha='center', va='center')` — already used in `plot_transition_matrix()` (PLOT-03). |
| REPT-08 | `generate_sweep_report()` orchestrator in `report.py` | New module at `src/backtesting/report.py`. Accepts `SweepResult`, produces structured output directory. Pattern mirrors `run_pipeline()` in `pipeline.py`. |
</phase_requirements>

## Summary

Phase 12 builds a reporting layer on top of the completed sweep engine (`SweepResult`) and extended analysis (`analysis.py`). The primary deliverable is a `generate_sweep_report()` function in a new `report.py` module that accepts a `SweepResult` and produces a structured output directory. All technology in this phase is already present in the dependency stack — no new libraries are needed.

The core visualization challenge is heatmap generation from `SweepResult.summary_df`. The `summary_df` is a pandas DataFrame with one row per sweep cell. Heatmaps require pivoting two grid axes (e.g., `curve_type` vs `alpha`) with a metric as the cell value. This pivot-then-imshow pattern with `origin='lower'` is the standard approach. The existing `plot_transition_matrix()` (PLOT-03) in `plots.py` already demonstrates the annotated heatmap pattern using the OO matplotlib API.

The critical implementation detail is the NaN/numpy type handling for JSON export. The existing `_nan_to_none()` helper in `sweep.py` handles `float` and `np.float64` correctly (since `np.float64` subclasses `float`), but `np.int64` (used in `cell_id`) is NOT a subclass of `int` in numpy and will cause `json.dumps()` to fail. The `report.py` module needs an extended `_nan_to_none()` that also handles `np.integer` types. The per-config detail plots require re-running the simulation for individual cells (since `summary_df` only has scalar metrics), or they can plot the scalar metrics from `summary_df` in a bar/radar chart without re-running.

**Primary recommendation:** Build `report.py` as a pure orchestration module that: (1) creates subdirectories, (2) generates heatmaps via pivot+imshow with `origin='lower'`, (3) generates per-config detail bar charts from `summary_df` scalars (no re-simulation needed), (4) generates timing sensitivity heatmap from `analysis.timing_sensitivity()`, (5) builds composite figure via `Figure.subplot_mosaic()`, (6) exports CSV and NaN-sanitized JSON.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| matplotlib | 3.10.8 (>=3.9.2) | All visualization — heatmaps, detail plots, composite figure | Already in stack; OO API (`Figure`, not `pyplot`) is the codebase standard |
| pandas | >=2.2.3 | pivot_table for heatmap data, nlargest/nsmallest for best/worst configs | Already in stack; `summary_df` is a pandas DataFrame |
| numpy | >=1.26.4 | Array operations for heatmap data, NaN handling | Already in stack |
| pathlib | stdlib | Directory creation and path management | Already used throughout codebase |
| json | stdlib | JSON export with NaN sanitization | Already used in `sweep.py` and `pipeline.py` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| backtesting.analysis | local | timing_sensitivity(), margin_class_breakdown() | For REPT-05 composite figure panels and timing_sensitivity/ directory |
| backtesting.sweep | local | SweepResult, _nan_to_none | Input type and helper reuse |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `imshow` for heatmaps | `seaborn.heatmap` | seaborn is not in the stack; imshow is already used in plot_transition_matrix — stay consistent |
| `subplot_mosaic` for composite | `gridspec` / `add_subplot` | subplot_mosaic is cleaner for named panels; both work identically |
| `Figure.savefig()` | `pyplot.savefig()` | OO API is mandatory (PLOT-12 compliance) — never use pyplot |

**Installation:** No new packages needed — all dependencies already in `pyproject.toml`.

## Architecture Patterns

### Recommended Project Structure
```
src/backtesting/
├── report.py              # NEW: generate_sweep_report() orchestrator
└── plots.py               # existing: per-proposal/metric plot functions (reuse BLUE/ORANGE)

output/<sweep_timestamp>/  # SweepResult.output_dir — already created by run_sweep()
├── summary.csv            # already written by run_sweep()
├── config.json            # already written by run_sweep()
├── heatmaps/              # REPT-04: new subdirectory
│   ├── flip_rate.png
│   ├── gini_signals.png
│   ├── enp_signals_mean.png
│   └── ...one per metric
├── detail/                # REPT-04: new subdirectory
│   ├── best_01_cell_7.png
│   ├── best_02_cell_3.png
│   ├── worst_01_cell_1.png
│   └── ...N best + N worst
├── timing_sensitivity/    # REPT-04: new subdirectory
│   └── timing_sensitivity.png
├── composite.png          # REPT-05: multi-panel composite
├── sweep_summary.json     # REPT-03: NaN-sanitized summary metrics
└── sweep_results.csv      # REPT-02: full results table (summary_df)
```

### Pattern 1: Heatmap Generation via pivot_table + imshow
**What:** Pivot `summary_df` on two grid axes to create a 2D matrix, render with `imshow(origin='lower')`
**When to use:** For every metric in `summary_df` that should appear as a heatmap (REPT-01, REPT-07)
**Example:**
```python
# Source: verified in project environment (matplotlib 3.10.8, pandas 2.2+)
def _plot_metric_heatmap(
    summary_df: pd.DataFrame,
    metric: str,
    row_axis: str,
    col_axis: str,
    cmap: str = 'RdYlGn',
    title: str | None = None,
) -> Figure:
    pivot = summary_df.pivot_table(
        values=metric,
        index=row_axis,
        columns=col_axis,
        aggfunc='mean',
    )
    data = pivot.values  # 2D numpy array, shape (n_rows, n_cols)

    fig = Figure(figsize=(8, 6))
    ax = fig.add_subplot(1, 1, 1)

    # REPT-01: origin='lower' is MANDATORY — default 'upper' flips row order
    im = ax.imshow(data, origin='lower', cmap=cmap, aspect='auto')

    # REPT-07: annotate cell values
    for i in range(data.shape[0]):
        for j in range(data.shape[1]):
            val = data[i, j]
            if not np.isnan(val):
                ax.text(j, i, f'{val:.3f}', ha='center', va='center', fontsize=8)

    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels([str(c) for c in pivot.columns], rotation=45, ha='right')
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels([str(r) for r in pivot.index])
    ax.set_xlabel(col_axis)
    ax.set_ylabel(row_axis)
    ax.set_title(title or metric)
    fig.colorbar(im, ax=ax, shrink=0.8)
    return fig
```

### Pattern 2: Composite Figure via subplot_mosaic
**What:** Assemble multiple analysis panels into a single publication figure
**When to use:** REPT-05 — multi-panel composite combining heatmaps + flip breakdown + timing
**Example:**
```python
# Source: verified in project environment (matplotlib 3.10.8)
fig = Figure(figsize=(18, 12))
axes = fig.subplot_mosaic([
    ['flip_heatmap', 'gini_heatmap', 'timing'],
    ['flip_heatmap', 'enp_heatmap', 'margin_breakdown'],
], height_ratios=[1, 1])
# Each key maps to an Axes object
ax_flip = axes['flip_heatmap']
# Render individual panels into the pre-created axes
```

### Pattern 3: Per-Config Detail Plot (from summary_df scalars)
**What:** Bar chart of metric values for a single sweep cell (no re-simulation)
**When to use:** REPT-06 — detail plots for best/worst N configurations
**Example:**
```python
# Source: derived from existing plots.py patterns (PLOT-01, PLOT-04, PLOT-06)
def _plot_cell_detail(row: pd.Series, title: str) -> Figure:
    """Bar chart of all metric values for a single sweep cell."""
    metrics = {
        'flip_rate': row.get('flip_rate', float('nan')),
        'gini_legacy': row.get('gini_legacy', float('nan')),
        'gini_signals': row.get('gini_signals', float('nan')),
        'enp_legacy': row.get('enp_legacy_mean', float('nan')),
        'enp_signals': row.get('enp_signals_mean', float('nan')),
        'nakamoto_legacy': row.get('nakamoto_legacy_mean', float('nan')),
        'nakamoto_signals': row.get('nakamoto_signals_mean', float('nan')),
        'margin_shift_mean': row.get('margin_shift_mean', float('nan')),
    }
    labels = list(metrics.keys())
    values = [v if not np.isnan(v) else 0.0 for v in metrics.values()]

    fig = Figure(figsize=(10, 5))
    ax = fig.add_subplot(1, 1, 1)
    ax.bar(range(len(labels)), values, color=ORANGE, zorder=3)
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha='right', fontsize=9)
    ax.set_title(title)
    return fig
```

### Pattern 4: generate_sweep_report() Orchestrator
**What:** Top-level function orchestrating all report generation steps
**When to use:** REPT-08 — single entry point, mirrors `run_pipeline()` structure
**Example:**
```python
# Source: mirrors pipeline.py run_pipeline() pattern
def generate_sweep_report(
    sweep_result: SweepResult,
    *,
    best_n: int = 3,
    worst_n: int = 3,
    ranking_metric: str = 'flip_rate',
    row_axis: str = 'curve_type',
    col_axis: str = 'alpha',
) -> ReportResult:
    out_dir = pathlib.Path(sweep_result.output_dir)
    (out_dir / 'heatmaps').mkdir(exist_ok=True)
    (out_dir / 'detail').mkdir(exist_ok=True)
    (out_dir / 'timing_sensitivity').mkdir(exist_ok=True)

    df = sweep_result.summary_df
    saved: list[str] = []

    # REPT-02: CSV export
    df.to_csv(out_dir / 'sweep_results.csv', index=False)

    # REPT-03: JSON export with NaN sanitization
    summary = _build_summary_dict(df)
    with open(out_dir / 'sweep_summary.json', 'w') as f:
        json.dump(_nan_to_none_extended(summary), f, indent=2)

    # REPT-01 + REPT-07: Heatmaps per metric
    for metric, cmap in _METRIC_CMAPS.items():
        fig = _plot_metric_heatmap(df, metric, row_axis, col_axis, cmap=cmap)
        path = out_dir / 'heatmaps' / f'{metric}.png'
        fig.savefig(str(path), dpi=300, bbox_inches='tight')
        saved.append(str(path))

    # REPT-06: Per-config detail plots
    valid_df = df[df['failed'] == False]
    for rank, (_, row) in enumerate(valid_df.nlargest(best_n, ranking_metric).iterrows(), 1):
        fig = _plot_cell_detail(row, f'Best #{rank} — cell {row.cell_id}')
        path = out_dir / 'detail' / f'best_{rank:02d}_cell_{row.cell_id}.png'
        fig.savefig(str(path), dpi=300, bbox_inches='tight')
        saved.append(str(path))

    # REPT-05: Composite figure
    fig = _build_composite(df, row_axis, col_axis)
    path = out_dir / 'composite.png'
    fig.savefig(str(path), dpi=200, bbox_inches='tight')
    saved.append(str(path))

    return ReportResult(output_dir=str(out_dir), saved_paths=saved)
```

### Anti-Patterns to Avoid
- **Using `pyplot` state:** `plots.py` enforces OO API (PLOT-12). Never `import matplotlib.pyplot`. Use `Figure()` directly.
- **Calling `ax.imshow()` without `origin='lower'`:** Default `origin='upper'` flips the row order — row 0 appears at the top, making heatmaps read upside-down relative to axis labels. Always explicit.
- **Using `json.dumps()` directly on `summary_df.to_dict()`:** `np.int64` values (e.g., `cell_id`) are not JSON-serializable. The existing `_nan_to_none()` handles `np.float64` correctly (subclasses `float`) but does NOT handle `np.int64` (does NOT subclass `int`). Verified: `json.dumps({'cell_id': np.int64(3)})` raises `TypeError`.
- **Re-running simulation for per-config detail plots:** `summary_df` already has all scalar metrics. Detail plots should chart from `summary_df` rows, not re-execute sweep cells.
- **Saving figures with `pyplot.savefig()`:** Use `fig.savefig(str(path), dpi=300, bbox_inches='tight')` on the `Figure` object directly.
- **`fig.clf()` vs creating new Figure:** The pipeline uses `fig.clf()` after saving. In `report.py`, prefer creating a fresh `Figure()` per plot function for clarity (same as `plots.py` pattern).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pivot table for heatmap | custom nested loops | `pd.pivot_table(aggfunc='mean')` | Handles missing combinations, NaN aggregation, duplicate axes gracefully |
| NaN sanitization for JSON | custom walk | `_nan_to_none()` from `sweep.py` (extended for `np.integer`) | Already battle-tested in pipeline and sweep; just needs `np.integer` branch |
| Colormap selection | custom color mapping | `ax.imshow(cmap='RdYlGn')` / `'Blues'` / `'viridis'` | matplotlib provides all needed colormaps natively |
| Best/worst N selection | custom sort+slice | `df.nlargest(n, col)` / `df.nsmallest(n, col)` | Handles NaN correctly (excluded by default), vectorized |
| Directory structure | manual `os.makedirs` | `pathlib.Path.mkdir(parents=True, exist_ok=True)` | Already used in `_make_output_dir()` — stay consistent |

**Key insight:** All data needed for the report already exists in `SweepResult.summary_df`. The report bundle is a pure transformation of that DataFrame into files — no simulation re-runs, no new data computation beyond `analysis.timing_sensitivity()`.

## Common Pitfalls

### Pitfall 1: imshow origin='upper' (default flips rows)
**What goes wrong:** Heatmap row 0 appears at the top of the image; axis tick labels are correctly ordered but the visual grid is inverted.
**Why it happens:** matplotlib `imshow()` default is `origin='upper'` (image convention where row 0 = top). For data matrices where row 0 = first category (bottom of axis), this is wrong.
**How to avoid:** Always pass `origin='lower'` explicitly. This is called out in REQUIREMENTS.md as P5 pitfall.
**Warning signs:** The bottom axis tick label corresponds to the top row of color in the heatmap.

### Pitfall 2: np.int64 not JSON-serializable
**What goes wrong:** `json.dumps(summary_df.to_dict(orient='records'))` raises `TypeError: Object of type int64 is not JSON serializable`.
**Why it happens:** `np.int64` does NOT subclass Python `int`. The existing `_nan_to_none()` in `sweep.py` only checks `isinstance(obj, float)` — correctly handles `np.float64` (which IS a float subclass) but misses integer columns.
**How to avoid:** Extend `_nan_to_none()` with an `isinstance(obj, np.integer)` → `int(obj)` branch. Or use `df.to_dict(orient='records')` followed by a pandas-aware serializer.
**Warning signs:** JSON export works for float columns but crashes on `cell_id`.

### Pitfall 3: Heatmap axis mismatch when pivot has missing combinations
**What goes wrong:** If some (row_axis, col_axis) combinations were never run (failed cells), `pivot_table` produces NaN in those cells, which `imshow` renders as blank/white patches.
**Why it happens:** `summary_df` may have cells where `failed=True` — those cells have NaN for all metric columns. Pivoting them creates NaN entries in the pivot matrix.
**How to avoid:** Filter `df[df['failed'] == False]` before pivoting. Document NaN cells in the heatmap annotation (skip annotation for NaN values with `if not np.isnan(val)`).
**Warning signs:** Heatmap has unexplained blank white squares.

### Pitfall 4: subplot_mosaic panel keys must match axes dict keys exactly
**What goes wrong:** `KeyError` when trying to access `axes['flip_heatmap']` if the mosaic layout used a different key.
**Why it happens:** `Figure.subplot_mosaic()` returns a dict with keys matching the layout strings exactly.
**How to avoid:** Define layout strings as constants and use them both in the mosaic spec and when accessing the dict.

### Pitfall 5: Colormap choice for signed vs unsigned metrics
**What goes wrong:** Using `'Blues'` (sequential) for `margin_shift_mean` (signed, can be negative) — negative values render in the same blue color space as positive, hiding the sign.
**Why it happens:** Sequential colormaps don't have a neutral midpoint; diverging colormaps (RdYlGn, RdBu) are needed for signed metrics.
**How to avoid:** Define a `_METRIC_CMAPS` dict mapping metric names to appropriate colormaps:
  - Signed metrics (delta, shift): `'RdYlGn'` (red=bad, green=good) or `'RdBu'`
  - Unsigned metrics (flip_rate, gini, enp): `'Blues'` or `'viridis'`
  - Ratios (gini_signals vs gini_legacy): consider `'RdYlGn'` with `vmin`/`vmax` centering

### Pitfall 6: timing_sensitivity() requires windows_df — not available from SweepResult
**What goes wrong:** `analysis.timing_sensitivity()` needs `windows_df` (proposal windows) in addition to `results_df`, but `SweepResult.summary_df` only has scalar metrics — it does NOT contain `results_df` or `windows_df` for individual cells.
**Why it happens:** The sweep engine releases `results_df` after computing scalar metrics (SWEP-04 memory management). `windows_df` was never stored.
**How to avoid:** The timing sensitivity figure for the report bundle should be generated from a representative single-config run (e.g., the best-ranked cell re-executed), OR the timing sensitivity data must be computed and stored during the sweep. The simplest approach: generate one timing sensitivity figure using a fresh scenario with default parameters, or skip per-cell timing sensitivity and only do a summary-level timing figure. **Recommendation:** re-run one representative cell (the top-ranked config) to generate the timing sensitivity figure. Document this in function signature as `reference_results_df` optional parameter.

## Code Examples

Verified patterns from the existing codebase and project environment:

### Heatmap with annotation (OO API, origin='lower')
```python
# Source: verified in project environment (matplotlib 3.10.8) + mirrors plot_transition_matrix pattern
import numpy as np
from matplotlib.figure import Figure

def _plot_metric_heatmap(pivot: pd.DataFrame, metric: str, cmap: str) -> Figure:
    data = pivot.values.astype(float)
    fig = Figure(figsize=(8, 6))
    ax = fig.add_subplot(1, 1, 1)
    # origin='lower' is the documented requirement (REPT-01, PITFALLS P5)
    im = ax.imshow(data, origin='lower', cmap=cmap, aspect='auto')
    # Annotate cells — skip NaN (failed cells)
    for i in range(data.shape[0]):
        for j in range(data.shape[1]):
            val = data[i, j]
            if not np.isnan(val):
                max_val = np.nanmax(data) if np.nanmax(data) > 0 else 1.0
                text_color = 'white' if val > max_val * 0.7 else 'black'
                ax.text(j, i, f'{val:.3f}', ha='center', va='center',
                        fontsize=8, color=text_color)
    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels([str(c) for c in pivot.columns])
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels([str(r) for r in pivot.index])
    fig.colorbar(im, ax=ax, shrink=0.8)
    return fig
```

### Extended _nan_to_none for JSON export
```python
# Source: extended from sweep._nan_to_none — verified np.int64 fix needed
import math
import numpy as np

def _nan_to_none_extended(obj):
    """Recursively replace NaN/Inf floats with None; convert numpy scalars."""
    if isinstance(obj, float):
        return None if (math.isnan(obj) or math.isinf(obj)) else obj
    if isinstance(obj, np.integer):  # catches np.int64, np.int32, etc.
        return int(obj)
    if isinstance(obj, np.floating):  # redundant (np.float64 subclasses float) but defensive
        return None if (math.isnan(float(obj)) or math.isinf(float(obj))) else float(obj)
    if isinstance(obj, dict):
        return {k: _nan_to_none_extended(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_nan_to_none_extended(v) for v in obj]
    return obj
```

### Directory creation (matches sweep.py pattern)
```python
# Source: mirrors _make_output_dir() in sweep.py
import pathlib

def _create_report_dirs(out_dir: pathlib.Path) -> dict[str, pathlib.Path]:
    dirs = {
        'heatmaps': out_dir / 'heatmaps',
        'detail': out_dir / 'detail',
        'timing_sensitivity': out_dir / 'timing_sensitivity',
    }
    for d in dirs.values():
        d.mkdir(parents=True, exist_ok=True)
    return dirs
```

### Metric colormap mapping
```python
# Recommended _METRIC_CMAPS constant for report.py
_METRIC_CMAPS = {
    # Unsigned metrics: sequential colormap
    'flip_rate': 'Blues',           # higher flip_rate = more impact (darker = more)
    'participation_rate': 'Blues',
    # Concentration metrics: reverse — lower gini/higher ENP = better
    'gini_legacy': 'RdYlGn_r',     # reversed: low gini = green (good)
    'gini_signals': 'RdYlGn_r',
    'enp_legacy_mean': 'RdYlGn',   # high ENP = green (good)
    'enp_signals_mean': 'RdYlGn',
    'nakamoto_legacy_mean': 'RdYlGn',
    'nakamoto_signals_mean': 'RdYlGn',
    # Signed metrics: diverging colormap
    'margin_shift_mean': 'RdYlGn', # positive shift = green (signals increases margin)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `pyplot.imshow()` (stateful) | `Figure() + ax.imshow()` (OO) | Enforced in plots.py from project start | Agg backend safe, no display required, test-friendly |
| `add_subplot(rows, cols, idx)` | `subplot_mosaic(layout)` | matplotlib 3.3+ | Named panels, easier composite layout |
| `plt.savefig()` | `fig.savefig()` | Enforced by PLOT-12 compliance | No pyplot state required |

**Deprecated/outdated:**
- `plt.get_cmap()`: still works in 3.10 but `matplotlib.colormaps['name']` is the new API. Either works — stick with `cmap='name'` string parameter to `imshow()` which resolves internally.

## Open Questions

1. **Timing sensitivity figure in report bundle (REPT-05)**
   - What we know: `analysis.timing_sensitivity()` requires `results_df` + `windows_df` per cell. The sweep engine releases these after computing scalar metrics (SWEP-04). `SweepResult` only has `summary_df` (scalar metrics) + `output_dir`.
   - What's unclear: Should timing sensitivity figure re-run one representative config, or should the timing sensitivity analysis be computed during sweep and stored separately?
   - Recommendation: Accept an optional `reference_results_df` + `reference_windows_df` parameter pair in `generate_sweep_report()`. If provided, compute timing sensitivity figure. If None, skip timing_sensitivity/ subdirectory. This avoids mandatory re-simulation while keeping the API clean. Document that callers can pass data from `pipeline.run_pipeline()` if they want timing figures.

2. **Heatmap axis selection for multi-dimensional sweep grids**
   - What we know: `summary_df` may have 5+ categorical axes (curve_type, alpha, lock_profile_long, allocation_strategy, vote_timing_label). A 2D heatmap can only show 2 axes at a time.
   - What's unclear: Which 2 axes should be default row/col for heatmaps when the grid has more than 2 axes?
   - Recommendation: Default `row_axis='curve_type'`, `col_axis='alpha'` — these are the most analytically interesting axes per the existing sweep grid design. Make them parameters so callers can override. When extra axes exist (e.g., multiple lock_profiles), aggregate by mean across the extra dimensions via `pivot_table(aggfunc='mean')` — this is already how `pivot_table` handles multi-value aggregation.

## Validation Architecture

> `workflow.nyquist_validation` is not present in `.planning/config.json` — treating as disabled. Skipping this section.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — `src/backtesting/plots.py` (PLOT-01 through PLOT-12), `plot_transition_matrix()` (annotated heatmap pattern)
- Direct codebase inspection — `src/backtesting/sweep.py` (`_nan_to_none()`, `SweepResult`, `summary_df` schema from `_run_cell()` and `_make_failed_row()`)
- Direct codebase inspection — `src/backtesting/pipeline.py` (`run_pipeline()` orchestrator pattern, `_make_output_dir()`, `_nan_to_none()`)
- Direct codebase inspection — `src/backtesting/analysis.py` (`timing_sensitivity()`, `margin_class_breakdown()` — available for composite figure)
- Runtime verification — matplotlib 3.10.8 OO API: `Figure.subplot_mosaic()`, `ax.imshow(origin='lower', cmap='RdYlGn')`, cell annotation pattern
- Runtime verification — `np.int64` NOT JSON-serializable via `json.dumps()`; `np.float64` IS handled by `isinstance(x, float)` check
- Runtime verification — `df.pivot_table()` for 2D heatmap generation from `summary_df`
- Runtime verification — `df.nlargest()` / `df.nsmallest()` for best/worst N config selection

### Secondary (MEDIUM confidence)
- `pyproject.toml` — confirms matplotlib>=3.9.2, pandas>=2.2.3, scipy>=1.13.0, numpy>=1.26.4, pytest>=8.0.0
- `tests/conftest.py` — confirms test runner is pytest; `metrics_results_df` fixture pattern for future `test_report.py`
- `tests/test_plots.py` — confirms OO API test pattern (isinstance Figure, no pyplot in sys.modules)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in pyproject.toml, versions confirmed
- Architecture: HIGH — directly derived from existing modules (plots.py, pipeline.py, sweep.py)
- Pitfalls: HIGH — np.int64 pitfall runtime-verified; origin='lower' is documented in REQUIREMENTS.md; timing_sensitivity requires extra data confirmed by reading analysis.py signature

**Research date:** 2026-02-28
**Valid until:** 2026-05-28 (stable matplotlib/pandas/numpy APIs)
