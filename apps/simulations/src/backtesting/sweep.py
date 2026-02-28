"""
Sweep engine data model and configuration layer.

Defines SweepConfig, SweepCell, SweepResult dataclasses, cartesian grid
enumeration via itertools.product, and TOML configuration loading.

Plan 02 will add run_sweep() execution on top of this data model.

Usage:
    from backtesting.sweep import SweepConfig, SweepCell, SweepResult, load_sweep_config
    config = load_sweep_config('sweep.toml')
    cells = _enumerate_cells(config)
"""
from __future__ import annotations

import datetime
import gc
import itertools
import json
import logging
import math
import pathlib
import tomllib
import warnings
from dataclasses import dataclass, field
from typing import Any

import pandas as pd

__all__ = ['SweepConfig', 'SweepCell', 'SweepResult', 'load_sweep_config']

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class SweepConfig:
    """Configuration for a parameter sweep run.

    Attributes:
        curve_types: Voting curve types to sweep (e.g., ['sqrt', 'log']).
        alphas: Pareto alpha values mapping to pareto_alpha in generate_scenario.
        lock_profiles: List of lock profile dicts with 'short' and 'long' keys.
            The 'long' value maps to l_max_days in generate_scenario.
        allocation_strategies: Allocation strategy names to sweep.
        max_workers: Number of parallel workers. Required — no auto-detection.
        cell_timeout_seconds: Timeout per cell in seconds.
        base: Passthrough dict from [base] TOML section for generate_scenario kwargs.
    """

    curve_types: list[str]
    alphas: list[float]
    lock_profiles: list[dict]
    allocation_strategies: list[str]
    max_workers: int
    cell_timeout_seconds: int = 120
    base: dict = field(default_factory=dict)


@dataclass
class SweepCell:
    """A single parameter combination in the sweep grid.

    Attributes:
        cell_id: Sequential identifier starting from 0.
        curve_type: Voting curve type for this cell.
        alpha: Pareto alpha value for this cell (maps to pareto_alpha).
        lock_profile: Dict with 'short' and 'long' keys. 'long' maps to
            l_max_days in generate_scenario; 'short' is captured for analysis.
        allocation_strategy: Allocation strategy name for this cell.
    """

    cell_id: int
    curve_type: str
    alpha: float
    lock_profile: dict
    allocation_strategy: str


@dataclass
class SweepResult:
    """Results from a completed sweep run.

    Attributes:
        config: The SweepConfig used for this run.
        summary_df: DataFrame with one row per cell, containing grid param
            columns plus computed metric columns.
        failed_cells: List of cell_ids that failed or timed out.
        output_dir: Path to the output directory for this run.
    """

    config: SweepConfig
    summary_df: pd.DataFrame
    failed_cells: list[int]
    output_dir: str


# ---------------------------------------------------------------------------
# Grid enumeration
# ---------------------------------------------------------------------------


def _enumerate_cells(config: SweepConfig) -> list[SweepCell]:
    """Enumerate all cells in the sweep grid via cartesian product.

    Uses itertools.product to produce the full cartesian product of
    curve_types x alphas x lock_profiles x allocation_strategies.

    Args:
        config: SweepConfig defining the sweep axes.

    Returns:
        List of SweepCell objects with sequential cell_ids starting from 0.
    """
    cells = []
    combos = itertools.product(
        config.curve_types,
        config.alphas,
        config.lock_profiles,
        config.allocation_strategies,
    )
    for cell_id, (curve_type, alpha, lock_profile, allocation_strategy) in enumerate(combos):
        cells.append(
            SweepCell(
                cell_id=cell_id,
                curve_type=curve_type,
                alpha=alpha,
                lock_profile=lock_profile,
                allocation_strategy=allocation_strategy,
            )
        )
    return cells


# ---------------------------------------------------------------------------
# TOML configuration loading
# ---------------------------------------------------------------------------


def load_sweep_config(path: str | pathlib.Path) -> SweepConfig:
    """Load a sweep configuration from a TOML file.

    Expected TOML structure:
        [base]
        n_voters = 200
        seed = 42

        [sweep]
        curve_types = ["sqrt", "log"]
        alphas = [0.5, 1.0, 2.0]
        max_workers = 4  # required
        cell_timeout_seconds = 120  # optional, default 120

        [[sweep.lock_profiles]]
        short = 30
        long = 365

    Args:
        path: Path to the TOML configuration file.

    Returns:
        SweepConfig populated from the TOML file.

    Raises:
        KeyError: If max_workers is not specified in [sweep] section.
        FileNotFoundError: If the TOML file does not exist.
    """
    path = pathlib.Path(path)
    with open(path, 'rb') as f:
        data = tomllib.load(f)

    sweep = data['sweep']
    base = data.get('base', {})

    # max_workers is required — raise KeyError if missing (no auto-detection)
    max_workers = sweep['max_workers']

    return SweepConfig(
        curve_types=sweep['curve_types'],
        alphas=sweep['alphas'],
        lock_profiles=sweep['lock_profiles'],
        allocation_strategies=sweep.get('allocation_strategies', ['uniform_fraction']),
        max_workers=max_workers,
        cell_timeout_seconds=sweep.get('cell_timeout_seconds', 120),
        base=base,
    )


# ---------------------------------------------------------------------------
# Output directory helper
# ---------------------------------------------------------------------------


def _make_output_dir(base_dir: str = './output') -> pathlib.Path:
    """Create and return a timestamped output directory.

    Follows the pipeline.py pattern: creates a subdirectory named with the
    current timestamp under base_dir.

    Args:
        base_dir: Base directory for output. Defaults to './output'.

    Returns:
        Resolved, created output directory path.
    """
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out_dir = pathlib.Path(base_dir) / timestamp
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir


# ---------------------------------------------------------------------------
# JSON serialization helper
# ---------------------------------------------------------------------------


def _nan_to_none(obj: Any) -> Any:
    """Recursively replace float('nan') and float('inf') with None.

    Copied from pipeline.py for JSON export compatibility.

    Args:
        obj: Any Python object to process.

    Returns:
        Object with NaN/Inf float values replaced by None.
    """
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    if isinstance(obj, dict):
        return {k: _nan_to_none(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_nan_to_none(v) for v in obj]
    return obj


# ---------------------------------------------------------------------------
# Failed cell row helper
# ---------------------------------------------------------------------------


def _make_failed_row(cell: SweepCell) -> dict:
    """Create a summary row dict for a failed/timed-out cell.

    Returns grid parameters with failed=True and NaN for all metric columns.

    Args:
        cell: The SweepCell that failed.

    Returns:
        Dict with grid params and NaN metric placeholders.
    """
    return {
        'cell_id': cell.cell_id,
        'curve_type': cell.curve_type,
        'alpha': cell.alpha,
        'lock_profile_short': cell.lock_profile.get('short'),
        'lock_profile_long': cell.lock_profile.get('long'),
        'allocation_strategy': cell.allocation_strategy,
        'failed': True,
        'flip_rate': float('nan'),
        'gini_legacy': float('nan'),
        'gini_signals': float('nan'),
        'participation_rate': float('nan'),
        'margin_shift_mean': float('nan'),
        'margin_shift_std': float('nan'),
    }
