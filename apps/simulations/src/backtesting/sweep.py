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

import numpy as np
import pandas as pd

from backtesting.data.budget import AllocationDistribution
from backtesting.data.factory import VoteTimingConfig

__all__ = ['SweepConfig', 'SweepCell', 'SweepResult', 'load_sweep_config', 'run_sweep']

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
    mc_dists: list[AllocationDistribution] | None = None
    vote_timings: list[VoteTimingConfig] | None = None


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
    mc_dist: AllocationDistribution | None = None
    vote_timing: VoteTimingConfig | None = None


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
    mc_dist_values = config.mc_dists if config.mc_dists else [None]
    vote_timing_values = config.vote_timings if config.vote_timings else [None]
    combos = itertools.product(
        config.curve_types,
        config.alphas,
        config.lock_profiles,
        config.allocation_strategies,
        mc_dist_values,
        vote_timing_values,
    )
    for cell_id, (curve_type, alpha, lock_profile, allocation_strategy, mc_dist, vote_timing) in enumerate(combos):
        cells.append(
            SweepCell(
                cell_id=cell_id,
                curve_type=curve_type,
                alpha=alpha,
                lock_profile=lock_profile,
                allocation_strategy=allocation_strategy,
                mc_dist=mc_dist,
                vote_timing=vote_timing,
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

        [[sweep.vote_timings]]
        early = 0.30
        mid = 0.40

        [[sweep.vote_timings]]
        early = 0.80
        mid = 0.10

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

    raw_timings = sweep.get('vote_timings', None)
    vote_timings = None
    if raw_timings:
        vote_timings = [VoteTimingConfig(early=t['early'], mid=t['mid']) for t in raw_timings]

    return SweepConfig(
        curve_types=sweep['curve_types'],
        alphas=sweep['alphas'],
        lock_profiles=sweep['lock_profiles'],
        allocation_strategies=sweep.get('allocation_strategies', ['uniform_fraction']),
        max_workers=max_workers,
        cell_timeout_seconds=sweep.get('cell_timeout_seconds', 120),
        base=base,
        vote_timings=vote_timings,
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
        'mc_dist_label': repr(cell.mc_dist) if cell.mc_dist is not None else None,
        'vote_timing_label': repr(cell.vote_timing) if cell.vote_timing is not None else None,
        'failed': True,
        'flip_rate': float('nan'),
        'gini_legacy': float('nan'),
        'gini_signals': float('nan'),
        'participation_rate': float('nan'),
        'margin_shift_mean': float('nan'),
        'margin_shift_std': float('nan'),
        'enp_legacy_mean': float('nan'),
        'enp_signals_mean': float('nan'),
        'nakamoto_legacy_mean': float('nan'),
        'nakamoto_signals_mean': float('nan'),
    }


# ---------------------------------------------------------------------------
# Module-level cell executor (must be module-level for ProcessPoolExecutor picklability)
# ---------------------------------------------------------------------------


def _run_cell(cell: SweepCell, base_cfg: dict) -> dict:
    """Execute a single sweep cell: generate scenario, run backtest, compute metrics.

    Module-level (not nested) so it is picklable for ProcessPoolExecutor.

    Imports are deferred inside the function to avoid circular imports and
    ensure picklability across worker processes.

    Memory management (SWEP-04): raw cadCAD results and intermediate DataFrames
    are deleted and gc.collect() is called after metrics are computed.

    Args:
        cell: The SweepCell parameter combination to execute.
        base_cfg: Passthrough kwargs for generate_scenario (n_voters, seed, etc.).

    Returns:
        Flat dict with grid params and scalar metric values, plus failed=False.
    """
    # Deferred imports for picklability and circular import avoidance
    from backtesting.data.factory import generate_scenario
    from backtesting.simulation.runner import run_backtest, build_results_dataframe
    from backtesting.metrics import (
        compute_flip_rate,
        compute_gini,
        compute_participation_rate,
        compute_margin_shift,
        compute_enp,
        compute_nakamoto_coefficient,
    )

    # Map cell params to generate_scenario kwargs
    kwargs = dict(base_cfg)  # copy base config
    kwargs['curve_type'] = cell.curve_type
    kwargs['pareto_alpha'] = cell.alpha
    kwargs['l_max_days'] = float(cell.lock_profile['long'])
    kwargs['allocation_strategy'] = cell.allocation_strategy
    # Do NOT pass lock_profile key from the dict — use 'independent' or base_cfg value
    kwargs.setdefault('lock_profile', 'independent')

    # Wire mc_dist from cell into generate_scenario when provided (INT-01)
    if cell.mc_dist is not None:
        kwargs['mc_dist'] = cell.mc_dist

    # Wire vote_timing from cell into generate_scenario when provided (MCAL-05)
    if cell.vote_timing is not None:
        kwargs['vote_timing'] = cell.vote_timing

    # Run simulation
    events = generate_scenario(**kwargs)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        raw = run_backtest(events, curve_type=cell.curve_type)
    results_df = build_results_dataframe(raw, events)

    # Compute scalar metrics
    flip = compute_flip_rate(results_df)
    gini = compute_gini(results_df, curve_type=cell.curve_type)
    participation = compute_participation_rate(results_df)
    margin = compute_margin_shift(results_df)
    enp = compute_enp(results_df, curve_type=cell.curve_type)
    nakamoto = compute_nakamoto_coefficient(results_df, curve_type=cell.curve_type)

    # CRITICAL memory management (SWEP-04): delete large objects and force GC
    del raw, events, results_df
    gc.collect()

    return {
        'cell_id': cell.cell_id,
        'curve_type': cell.curve_type,
        'alpha': cell.alpha,
        'lock_profile_short': cell.lock_profile['short'],
        'lock_profile_long': cell.lock_profile['long'],
        'allocation_strategy': cell.allocation_strategy,
        'mc_dist_label': repr(cell.mc_dist) if cell.mc_dist is not None else None,
        'vote_timing_label': repr(cell.vote_timing) if cell.vote_timing is not None else None,
        'flip_rate': flip.aggregate,
        'gini_legacy': gini.legacy,
        'gini_signals': gini.signals,
        'participation_rate': participation.aggregate,
        'margin_shift_mean': margin.aggregate_mean,
        'margin_shift_std': margin.aggregate_std,
        'enp_legacy_mean': float(np.nanmean(list(enp.legacy.values()))) if enp.legacy else float('nan'),
        'enp_signals_mean': float(np.nanmean(list(enp.signals.values()))) if enp.signals else float('nan'),
        'nakamoto_legacy_mean': float(np.nanmean(list(nakamoto.legacy.values()))) if nakamoto.legacy else float('nan'),
        'nakamoto_signals_mean': float(np.nanmean(list(nakamoto.signals.values()))) if nakamoto.signals else float('nan'),
        'failed': False,
    }


# ---------------------------------------------------------------------------
# Sweep orchestrator
# ---------------------------------------------------------------------------


def run_sweep(
    config: SweepConfig,
    *,
    fail_fast: bool = False,
    output_dir: str | None = None,
) -> SweepResult:
    """Execute a full parameter sweep with parallel cell execution.

    Dispatches cells to a ProcessPoolExecutor with max_workers from config.
    Uses tqdm for progress reporting (one update per completed cell).
    Failed cells are logged and added to failed_cells list; sweep continues
    unless fail_fast=True, which stops on first failure.

    Auto-exports summary.csv and config.json to a timestamped output directory.

    Args:
        config: SweepConfig defining the sweep axes and execution parameters.
        fail_fast: If True, stop the sweep on the first cell failure.
        output_dir: Override output directory base path. Defaults to
            config.base.get('output_dir', './output').

    Returns:
        SweepResult with summary_df, failed_cells list, and output_dir path.

    Raises:
        RuntimeError: If fail_fast=True and a cell times out.
        Exception: If fail_fast=True and a cell raises an exception.
    """
    from concurrent.futures import ProcessPoolExecutor, TimeoutError as FutureTimeout, as_completed
    from tqdm import tqdm

    cells = _enumerate_cells(config)
    out_dir = _make_output_dir(output_dir or config.base.get('output_dir', './output'))

    rows: list[dict] = []
    failed_cells: list[int] = []

    with ProcessPoolExecutor(max_workers=config.max_workers) as ex:
        futures = {ex.submit(_run_cell, cell, config.base): cell for cell in cells}
        with tqdm(total=len(futures), desc='Sweep', unit='cell') as pbar:
            for fut in as_completed(futures):
                cell = futures[fut]
                try:
                    row = fut.result(timeout=config.cell_timeout_seconds)
                    rows.append(row)
                except FutureTimeout:
                    fut.cancel()
                    logging.error('Cell %d timed out', cell.cell_id)
                    failed_cells.append(cell.cell_id)
                    rows.append(_make_failed_row(cell))
                    if fail_fast:
                        ex.shutdown(wait=False, cancel_futures=True)
                        raise RuntimeError(f'Sweep aborted: cell {cell.cell_id} timed out')
                except Exception as e:
                    logging.error('Cell %d failed: %s', cell.cell_id, e)
                    failed_cells.append(cell.cell_id)
                    rows.append(_make_failed_row(cell))
                    if fail_fast:
                        ex.shutdown(wait=False, cancel_futures=True)
                        raise
                pbar.update(1)

    summary_df = pd.DataFrame(rows).sort_values('cell_id').reset_index(drop=True)

    # Auto-export results
    summary_df.to_csv(out_dir / 'summary.csv', index=False)
    config_dict = {
        'curve_types': config.curve_types,
        'alphas': config.alphas,
        'lock_profiles': config.lock_profiles,
        'allocation_strategies': config.allocation_strategies,
        'max_workers': config.max_workers,
        'cell_timeout_seconds': config.cell_timeout_seconds,
        'base': config.base,
        'mc_dists': [repr(d) for d in config.mc_dists] if config.mc_dists else None,
        'vote_timings': [repr(t) for t in config.vote_timings] if config.vote_timings else None,
    }
    with open(out_dir / 'config.json', 'w') as f:
        json.dump(config_dict, f, indent=2)

    return SweepResult(
        config=config,
        summary_df=summary_df,
        failed_cells=failed_cells,
        output_dir=str(out_dir),
    )
