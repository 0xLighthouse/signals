"""
Sweep report generation module.

Creates structured output directories with heatmaps, CSV/JSON exports
for a completed SweepResult. All matplotlib code uses the OO API exclusively
(no pyplot state). Each figure is saved to disk at dpi=300.

Exports:
    generate_sweep_report  — REPT-08 orchestrator
    ReportResult           — frozen dataclass with output paths
"""
import json
import math
import pathlib
from dataclasses import dataclass
from typing import Any

import matplotlib
matplotlib.use('Agg')  # Must be FIRST matplotlib call — before any Figure import

import matplotlib.figure               # noqa: E402
import matplotlib.backends.backend_agg  # noqa: E402  (registers Agg backend)
import numpy as np                     # noqa: E402
import pandas as pd                    # noqa: E402

from matplotlib.figure import Figure   # noqa: E402

from backtesting.sweep import SweepResult  # noqa: E402

__all__ = ['generate_sweep_report', 'ReportResult', '_plot_cell_detail', '_build_composite']

# ---------------------------------------------------------------------------
# Dataclass
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ReportResult:
    """Result of a generate_sweep_report() call.

    Attributes:
        output_dir: Absolute path to the sweep output directory.
        saved_paths: List of all file paths saved during report generation.
    """

    output_dir: str
    saved_paths: list[str]


# ---------------------------------------------------------------------------
# Colormap mapping — REPT-01 / REPT-07
# ---------------------------------------------------------------------------

# Map metric column names to appropriate colormaps.
# - Unsigned metrics: Blues
# - Concentration where lower is better (Gini): RdYlGn_r (reversed — low=green)
# - Concentration where higher is better (ENP, Nakamoto): RdYlGn
# - Signed metrics (margin_shift): RdYlGn
_METRIC_CMAPS: dict[str, str] = {
    'flip_rate': 'Blues',
    'participation_rate': 'Blues',
    'gini_legacy': 'RdYlGn_r',
    'gini_signals': 'RdYlGn_r',
    'enp_legacy_mean': 'RdYlGn',
    'enp_signals_mean': 'RdYlGn',
    'nakamoto_legacy_mean': 'RdYlGn',
    'nakamoto_signals_mean': 'RdYlGn',
    'margin_shift_mean': 'RdYlGn',
}


# ---------------------------------------------------------------------------
# JSON serialization helper — extended to handle np.integer types
# ---------------------------------------------------------------------------


def _nan_to_none_extended(obj: Any) -> Any:
    """Recursively replace NaN/Inf floats and numpy integer/float types with
    JSON-serializable equivalents.

    Extends sweep.py's _nan_to_none by also handling np.integer (np.int64,
    np.int32, etc.) and np.floating types. This is CRITICAL because
    summary_df['cell_id'] is np.int64 which is NOT a subclass of Python int
    and will cause json.dumps() to raise TypeError.

    Args:
        obj: Any Python or numpy object to process.

    Returns:
        Object with NaN/Inf replaced by None and numpy scalars cast to Python
        native types.
    """
    # Handle numpy integer types (np.int64, np.int32, etc.)
    if isinstance(obj, np.integer):
        return int(obj)
    # Handle numpy floating types (np.float64, np.float32, etc.)
    if isinstance(obj, np.floating):
        val = float(obj)
        if math.isnan(val) or math.isinf(val):
            return None
        return val
    # Handle Python floats
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    # Recurse into dicts
    if isinstance(obj, dict):
        return {k: _nan_to_none_extended(v) for k, v in obj.items()}
    # Recurse into lists and tuples
    if isinstance(obj, (list, tuple)):
        return [_nan_to_none_extended(v) for v in obj]
    return obj


# ---------------------------------------------------------------------------
# Heatmap plotting — REPT-01, REPT-07
# ---------------------------------------------------------------------------


def _plot_metric_heatmap(
    summary_df: pd.DataFrame,
    metric: str,
    row_axis: str,
    col_axis: str,
    cmap: str,
    title: str | None = None,
) -> Figure:
    """Plot a 2D annotated heatmap of a sweep metric.

    Filters out failed cells before pivoting. Uses origin='lower' so that
    the first row_axis value appears at the bottom of the image (REPT-01).
    Annotates each cell with its numeric value (REPT-07).

    Args:
        summary_df: DataFrame with one row per sweep cell.
        metric: Column name to visualize (must be in _METRIC_CMAPS or a numeric col).
        row_axis: Column name to use as the heatmap row axis (y-axis).
        col_axis: Column name to use as the heatmap column axis (x-axis).
        cmap: Matplotlib colormap name.
        title: Optional title override. Defaults to metric name.

    Returns:
        Figure object with the rendered heatmap.
    """
    # Exclude failed cells before pivoting
    df = summary_df[summary_df['failed'] == False].copy()  # noqa: E712

    # Build 2D pivot table: rows=row_axis, cols=col_axis, values=metric
    pivot = pd.pivot_table(
        df,
        values=metric,
        index=row_axis,
        columns=col_axis,
        aggfunc='mean',
    )

    data = pivot.values  # shape: (n_rows, n_cols)
    row_labels = list(pivot.index)
    col_labels = list(pivot.columns)

    # Create figure using OO API — no pyplot
    fig = Figure(figsize=(8, 6))
    ax = fig.add_subplot(1, 1, 1)

    # REPT-01: origin='lower' ensures first row appears at the bottom
    im = ax.imshow(data, origin='lower', cmap=cmap, aspect='auto')

    # Colorbar
    fig.colorbar(im, ax=ax, label=metric)

    # REPT-07: Annotate each cell with its numeric value
    vmin = np.nanmin(data)
    vmax = np.nanmax(data)
    v_range = vmax - vmin if (vmax - vmin) > 0 else 1.0

    n_rows, n_cols = data.shape
    for i in range(n_rows):
        for j in range(n_cols):
            val = data[i, j]
            if np.isnan(val):
                continue
            # Determine contrasting text color based on value relative to range
            normalized = (val - vmin) / v_range
            text_color = 'white' if normalized > 0.6 else 'black'
            ax.text(
                j, i, f'{val:.3f}',
                ha='center', va='center',
                fontsize=8, color=text_color,
            )

    # Set tick labels
    ax.set_xticks(range(n_cols))
    ax.set_xticklabels([str(c) for c in col_labels], rotation=45, ha='right')
    ax.set_yticks(range(n_rows))
    ax.set_yticklabels([str(r) for r in row_labels])

    ax.set_xlabel(col_axis)
    ax.set_ylabel(row_axis)
    ax.set_title(title if title is not None else metric)

    return fig


# ---------------------------------------------------------------------------
# Summary dict builder for JSON export — REPT-03
# ---------------------------------------------------------------------------


def _build_summary_dict(df: pd.DataFrame) -> dict:
    """Build a summary dict from summary_df for JSON export.

    Args:
        df: SweepResult.summary_df (all rows including failed cells).

    Returns:
        Dict with aggregate statistics across non-failed cells.
    """
    metric_cols = list(_METRIC_CMAPS.keys())
    non_failed = df[df['failed'] == False]  # noqa: E712

    total_cells = len(df)
    failed_count = int(df['failed'].sum())

    per_metric: dict[str, dict] = {}
    for col in metric_cols:
        if col not in non_failed.columns:
            continue
        values = non_failed[col].dropna()
        if len(values) == 0:
            per_metric[col] = {'mean': None, 'min': None, 'max': None, 'count': 0}
        else:
            per_metric[col] = {
                'mean': float(values.mean()),
                'min': float(values.min()),
                'max': float(values.max()),
                'count': int(len(values)),
            }

    return {
        'total_cells': total_cells,
        'failed_cells': failed_count,
        'metrics': per_metric,
    }


# ---------------------------------------------------------------------------
# Per-config detail plot — REPT-06
# ---------------------------------------------------------------------------

_DETAIL_METRICS: list[str] = [
    'flip_rate',
    'gini_legacy',
    'gini_signals',
    'participation_rate',
    'enp_legacy_mean',
    'enp_signals_mean',
    'nakamoto_legacy_mean',
    'nakamoto_signals_mean',
    'margin_shift_mean',
]

_ORANGE = '#FF9800'


def _plot_cell_detail(row: pd.Series, title: str) -> Figure:
    """Plot a bar chart showing all metric values for a single sweep cell.

    NaN metric values are replaced with 0.0 for bar height. Uses ORANGE bars
    and rotates x-axis labels 45 degrees for readability.

    Args:
        row: A single row from summary_df with metric columns.
        title: Title identifying the cell (e.g. "Best #1 — cell 7 (sqrt, alpha=0.5)").

    Returns:
        Figure with the bar chart.
    """
    # Collect metric values from the row, replacing NaN with 0.0
    labels: list[str] = []
    values: list[float] = []
    for metric in _DETAIL_METRICS:
        if metric not in row.index:
            continue
        val = row[metric]
        labels.append(metric)
        values.append(0.0 if (isinstance(val, float) and math.isnan(val)) or
                      (isinstance(val, np.floating) and np.isnan(val)) else float(val))

    fig = Figure(figsize=(10, 5))
    ax = fig.add_subplot(1, 1, 1)

    x_positions = range(len(labels))
    ax.bar(x_positions, values, color=_ORANGE)

    ax.set_xticks(list(x_positions))
    ax.set_xticklabels(labels, rotation=45, ha='right')
    ax.set_ylabel('Value')
    ax.set_title(title)

    fig.tight_layout()
    return fig


# ---------------------------------------------------------------------------
# Multi-panel composite figure — REPT-05
# ---------------------------------------------------------------------------

# The four metrics shown in the composite 2x2 layout
_COMPOSITE_METRICS: list[tuple[str, str]] = [
    ('flip_heatmap', 'flip_rate'),
    ('gini_heatmap', 'gini_legacy'),
    ('enp_heatmap', 'enp_signals_mean'),
    ('margin_heatmap', 'margin_shift_mean'),
]


def _build_composite(
    summary_df: pd.DataFrame,
    row_axis: str,
    col_axis: str,
) -> Figure:
    """Build a multi-panel composite figure combining key heatmaps.

    Uses Figure.subplot_mosaic for a 2x2 layout. Renders heatmap data
    directly into each axes (no per-metric Figure allocation). Filters out
    failed cells before pivoting.

    Args:
        summary_df: DataFrame with one row per sweep cell.
        row_axis: Column to use as the heatmap row axis.
        col_axis: Column to use as the heatmap column axis.

    Returns:
        Figure with 4 heatmap panels.
    """
    layout = [
        ['flip_heatmap', 'gini_heatmap'],
        ['enp_heatmap',  'margin_heatmap'],
    ]

    fig = Figure(figsize=(18, 12))
    axes_dict = fig.subplot_mosaic(layout)

    df = summary_df[summary_df['failed'] == False].copy()  # noqa: E712

    for panel_key, metric in _COMPOSITE_METRICS:
        ax = axes_dict[panel_key]

        if metric not in df.columns or row_axis not in df.columns or col_axis not in df.columns:
            ax.set_title(f'{metric} (no data)')
            continue

        try:
            pivot = pd.pivot_table(
                df,
                values=metric,
                index=row_axis,
                columns=col_axis,
                aggfunc='mean',
            )
        except Exception:
            ax.set_title(f'{metric} (pivot error)')
            continue

        data = pivot.values
        row_labels = list(pivot.index)
        col_labels = list(pivot.columns)

        cmap = _METRIC_CMAPS.get(metric, 'Blues')
        im = ax.imshow(data, origin='lower', cmap=cmap, aspect='auto')
        fig.colorbar(im, ax=ax, label=metric)

        # Annotate cells
        vmin = np.nanmin(data)
        vmax = np.nanmax(data)
        v_range = vmax - vmin if (vmax - vmin) > 0 else 1.0
        n_rows, n_cols = data.shape
        for i in range(n_rows):
            for j in range(n_cols):
                val = data[i, j]
                if np.isnan(val):
                    continue
                normalized = (val - vmin) / v_range
                text_color = 'white' if normalized > 0.6 else 'black'
                ax.text(j, i, f'{val:.3f}', ha='center', va='center',
                        fontsize=8, color=text_color)

        ax.set_xticks(range(n_cols))
        ax.set_xticklabels([str(c) for c in col_labels], rotation=45, ha='right')
        ax.set_yticks(range(n_rows))
        ax.set_yticklabels([str(r) for r in row_labels])
        ax.set_xlabel(col_axis)
        ax.set_ylabel(row_axis)
        ax.set_title(metric)

    fig.suptitle('Sweep Report Summary', fontsize=16, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    return fig


# ---------------------------------------------------------------------------
# Main orchestrator — REPT-08
# ---------------------------------------------------------------------------


def generate_sweep_report(
    sweep_result: SweepResult,
    *,
    best_n: int = 3,
    worst_n: int = 3,
    ranking_metric: str = 'flip_rate',
    row_axis: str = 'curve_type',
    col_axis: str = 'alpha',
) -> ReportResult:
    """Generate a structured report bundle from a completed sweep run.

    Creates subdirectories under sweep_result.output_dir:
        heatmaps/           — one PNG per metric in _METRIC_CMAPS (REPT-01, REPT-07)
        detail/             — reserved for Plan 02 detail plots (REPT-06)
        timing_sensitivity/ — reserved for Plan 02 timing analysis

    Exports:
        sweep_results.csv   — all summary_df rows and columns (REPT-02)
        sweep_summary.json  — aggregated statistics, NaN/np.int64-safe (REPT-03)

    Args:
        sweep_result: Completed SweepResult from run_sweep().
        best_n: Number of top-performing cells to highlight (reserved for Plan 02).
        worst_n: Number of worst-performing cells to highlight (reserved for Plan 02).
        ranking_metric: Metric used to rank cells (reserved for Plan 02).
        row_axis: Column to use as heatmap row axis. Defaults to 'curve_type'.
        col_axis: Column to use as heatmap column axis. Defaults to 'alpha'.

    Returns:
        ReportResult with output_dir and list of all saved file paths.
    """
    out_dir = pathlib.Path(sweep_result.output_dir)
    saved_paths: list[str] = []

    # REPT-04: Create subdirectories
    heatmaps_dir = out_dir / 'heatmaps'
    detail_dir = out_dir / 'detail'
    timing_sensitivity_dir = out_dir / 'timing_sensitivity'

    heatmaps_dir.mkdir(parents=True, exist_ok=True)
    detail_dir.mkdir(parents=True, exist_ok=True)
    timing_sensitivity_dir.mkdir(parents=True, exist_ok=True)

    df = sweep_result.summary_df

    # REPT-02: Export CSV — all rows and columns
    csv_path = out_dir / 'sweep_results.csv'
    df.to_csv(csv_path, index=False)
    saved_paths.append(str(csv_path))

    # REPT-03: Export JSON — NaN/np.int64-safe summary
    summary_dict = _build_summary_dict(df)
    safe_summary = _nan_to_none_extended(summary_dict)
    json_path = out_dir / 'sweep_summary.json'
    with open(json_path, 'w') as f:
        json.dump(safe_summary, f, indent=2)
    saved_paths.append(str(json_path))

    # REPT-01 + REPT-07: Generate one heatmap per metric
    for metric, cmap in _METRIC_CMAPS.items():
        if metric not in df.columns:
            continue
        # Skip if the required axes are not present or pivot would be empty
        if row_axis not in df.columns or col_axis not in df.columns:
            continue
        non_failed = df[df['failed'] == False]  # noqa: E712
        if non_failed.empty:
            continue
        # Need at least some variation in both axes for a meaningful heatmap
        if non_failed[row_axis].nunique() < 1 or non_failed[col_axis].nunique() < 1:
            continue

        try:
            fig = _plot_metric_heatmap(df, metric, row_axis, col_axis, cmap)
            png_path = heatmaps_dir / f'{metric}.png'
            fig.savefig(str(png_path), dpi=300, bbox_inches='tight')
            saved_paths.append(str(png_path))
            del fig
        except Exception:
            # Skip metrics that can't be pivoted (e.g. all NaN after filtering)
            pass

    # REPT-06: Per-config detail plots for best/worst N configurations
    if not df.empty:
        valid_df = df[df['failed'] == False]  # noqa: E712
        if not valid_df.empty and ranking_metric in valid_df.columns:
            # Best N configs (highest ranking metric)
            for rank, (_, row) in enumerate(
                valid_df.nlargest(best_n, ranking_metric).iterrows(), start=1
            ):
                cell_id = int(row['cell_id']) if 'cell_id' in row.index else rank
                title = f'Best #{rank} — cell {cell_id}'
                if 'curve_type' in row.index and 'alpha' in row.index:
                    title += f' ({row["curve_type"]}, alpha={row["alpha"]})'
                fig = _plot_cell_detail(row, title)
                png_path = detail_dir / f'best_{rank:02d}_cell_{cell_id}.png'
                fig.savefig(str(png_path), dpi=300, bbox_inches='tight')
                saved_paths.append(str(png_path))
                del fig

            # Worst N configs (lowest ranking metric)
            for rank, (_, row) in enumerate(
                valid_df.nsmallest(worst_n, ranking_metric).iterrows(), start=1
            ):
                cell_id = int(row['cell_id']) if 'cell_id' in row.index else rank
                title = f'Worst #{rank} — cell {cell_id}'
                if 'curve_type' in row.index and 'alpha' in row.index:
                    title += f' ({row["curve_type"]}, alpha={row["alpha"]})'
                fig = _plot_cell_detail(row, title)
                png_path = detail_dir / f'worst_{rank:02d}_cell_{cell_id}.png'
                fig.savefig(str(png_path), dpi=300, bbox_inches='tight')
                saved_paths.append(str(png_path))
                del fig

    # REPT-05: Multi-panel composite figure
    if not df.empty:
        try:
            fig = _build_composite(df, row_axis, col_axis)
            composite_path = out_dir / 'composite.png'
            fig.savefig(str(composite_path), dpi=200, bbox_inches='tight')
            saved_paths.append(str(composite_path))
            del fig
        except Exception:
            pass

    return ReportResult(
        output_dir=str(out_dir),
        saved_paths=saved_paths,
    )
