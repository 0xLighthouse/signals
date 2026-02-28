"""
Tests for backtesting.report module.

Requirement traces:
- test_rept01: REPT-01 — heatmaps use origin='lower'
- test_rept02: REPT-02 — CSV export
- test_rept03: REPT-03 — JSON export (NaN/np.int64-safe)
- test_rept04: REPT-04 — directory structure creation
- test_rept07: REPT-07 — heatmap cell annotations
- test_rept08: REPT-08 — generate_sweep_report orchestrator
"""
import json
import math

import numpy as np
import pandas as pd
import pytest

from backtesting.report import (
    ReportResult,
    _nan_to_none_extended,
    _plot_metric_heatmap,
    generate_sweep_report,
)
from backtesting.sweep import SweepConfig, SweepResult


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_sweep_result(tmp_path) -> SweepResult:
    """Create a minimal SweepResult fixture with 4 cells: 2 curve_types x 2 alphas."""
    config = SweepConfig(
        curve_types=['sqrt', 'log'],
        alphas=[0.5, 1.0],
        lock_profiles=[{'short': 30, 'long': 365}],
        allocation_strategies=['uniform_fraction'],
        max_workers=1,
    )

    summary_df = pd.DataFrame({
        'cell_id': [0, 1, 2, 3],
        'curve_type': ['sqrt', 'sqrt', 'log', 'log'],
        'alpha': [0.5, 1.0, 0.5, 1.0],
        'lock_profile_short': [30, 30, 30, 30],
        'lock_profile_long': [365, 365, 365, 365],
        'allocation_strategy': ['uniform_fraction'] * 4,
        'mc_dist_label': [None] * 4,
        'vote_timing_label': [None] * 4,
        'failed': [False, False, False, False],
        'flip_rate': [0.30, 0.35, 0.42, 0.48],
        'gini_legacy': [0.60, 0.62, 0.58, 0.65],
        'gini_signals': [0.55, 0.57, 0.53, 0.60],
        'participation_rate': [0.75, 0.72, 0.78, 0.70],
        'margin_shift_mean': [0.05, -0.02, 0.08, -0.01],
        'margin_shift_std': [0.10, 0.12, 0.09, 0.11],
        'enp_legacy_mean': [5.2, 4.8, 5.5, 4.5],
        'enp_signals_mean': [6.1, 5.7, 6.3, 5.4],
        'nakamoto_legacy_mean': [8.0, 7.5, 8.5, 7.0],
        'nakamoto_signals_mean': [9.2, 8.8, 9.5, 8.5],
    })

    return SweepResult(
        config=config,
        summary_df=summary_df,
        failed_cells=[],
        output_dir=str(tmp_path),
    )


# ---------------------------------------------------------------------------
# REPT-04: Directory structure
# ---------------------------------------------------------------------------


def test_generate_sweep_report_creates_directories(tmp_path):
    """REPT-04: generate_sweep_report creates heatmaps/, detail/, timing_sensitivity/ subdirs."""
    sweep_result = _make_sweep_result(tmp_path)
    generate_sweep_report(sweep_result)

    assert (tmp_path / 'heatmaps').is_dir(), 'heatmaps/ directory not created'
    assert (tmp_path / 'detail').is_dir(), 'detail/ directory not created'
    assert (tmp_path / 'timing_sensitivity').is_dir(), 'timing_sensitivity/ directory not created'


# ---------------------------------------------------------------------------
# REPT-02: CSV export
# ---------------------------------------------------------------------------


def test_generate_sweep_report_exports_csv(tmp_path):
    """REPT-02: sweep_results.csv exists and has correct number of rows."""
    sweep_result = _make_sweep_result(tmp_path)
    generate_sweep_report(sweep_result)

    csv_path = tmp_path / 'sweep_results.csv'
    assert csv_path.exists(), 'sweep_results.csv not created'

    loaded_df = pd.read_csv(csv_path)
    assert len(loaded_df) == len(sweep_result.summary_df), (
        f'CSV row count mismatch: got {len(loaded_df)}, '
        f'expected {len(sweep_result.summary_df)}'
    )


# ---------------------------------------------------------------------------
# REPT-03: JSON export
# ---------------------------------------------------------------------------


def _check_no_nan_inf(obj, path='root') -> None:
    """Recursively assert no NaN or Inf float values in JSON-decoded structure."""
    if isinstance(obj, float):
        assert not math.isnan(obj), f'NaN found at {path}'
        assert not math.isinf(obj), f'Inf found at {path}'
    elif isinstance(obj, dict):
        for k, v in obj.items():
            _check_no_nan_inf(v, f'{path}.{k}')
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            _check_no_nan_inf(v, f'{path}[{i}]')


def test_generate_sweep_report_exports_json(tmp_path):
    """REPT-03: sweep_summary.json exists, is valid JSON, and contains no NaN/Inf values."""
    sweep_result = _make_sweep_result(tmp_path)
    generate_sweep_report(sweep_result)

    json_path = tmp_path / 'sweep_summary.json'
    assert json_path.exists(), 'sweep_summary.json not created'

    with open(json_path) as f:
        data = json.load(f)  # This raises JSONDecodeError if invalid JSON

    _check_no_nan_inf(data)


# ---------------------------------------------------------------------------
# REPT-01: Heatmap origin='lower'
# ---------------------------------------------------------------------------


def test_heatmap_uses_origin_lower(tmp_path):
    """REPT-01: _plot_metric_heatmap uses origin='lower' for correct axis orientation."""
    sweep_result = _make_sweep_result(tmp_path)
    df = sweep_result.summary_df

    fig = _plot_metric_heatmap(df, 'flip_rate', 'curve_type', 'alpha', 'Blues')
    ax = fig.get_axes()[0]

    assert len(ax.images) > 0, 'No images found on axes'
    im = ax.images[0]
    assert im.origin == 'lower', (
        f"Expected origin='lower', got origin='{im.origin}'"
    )


# ---------------------------------------------------------------------------
# REPT-07: Heatmap cell annotations
# ---------------------------------------------------------------------------


def test_heatmap_annotated_cells(tmp_path):
    """REPT-07: _plot_metric_heatmap annotates each non-NaN cell with its numeric value."""
    sweep_result = _make_sweep_result(tmp_path)
    df = sweep_result.summary_df

    fig = _plot_metric_heatmap(df, 'flip_rate', 'curve_type', 'alpha', 'Blues')
    ax = fig.get_axes()[0]

    assert len(ax.texts) > 0, 'No cell annotations found on axes'


# ---------------------------------------------------------------------------
# NaN / np.int64 handling
# ---------------------------------------------------------------------------


def test_nan_to_none_extended_handles_np_int64():
    """_nan_to_none_extended converts np.int64 to Python int for JSON serialization."""
    result = _nan_to_none_extended({'cell_id': np.int64(3)})
    assert result == {'cell_id': 3}, f'Expected {{cell_id: 3}}, got {result}'
    assert isinstance(result['cell_id'], int), (
        f"Expected Python int, got {type(result['cell_id'])}"
    )
    # Must be JSON-serializable — raises TypeError if np.int64 leaks through
    serialized = json.dumps(result)
    loaded = json.loads(serialized)
    assert loaded == {'cell_id': 3}


def test_nan_to_none_extended_handles_nan():
    """_nan_to_none_extended converts float('nan') to None."""
    result = _nan_to_none_extended(float('nan'))
    assert result is None, f'Expected None, got {result}'


# ---------------------------------------------------------------------------
# REPT-08: Return type
# ---------------------------------------------------------------------------


def test_report_result_type(tmp_path):
    """REPT-08: generate_sweep_report returns ReportResult with correct output_dir and non-empty saved_paths."""
    sweep_result = _make_sweep_result(tmp_path)
    result = generate_sweep_report(sweep_result)

    assert isinstance(result, ReportResult), (
        f'Expected ReportResult, got {type(result)}'
    )
    assert result.output_dir == str(tmp_path), (
        f'Expected output_dir={tmp_path}, got {result.output_dir}'
    )
    assert len(result.saved_paths) > 0, 'saved_paths is empty — no files were saved'
