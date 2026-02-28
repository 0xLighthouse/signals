"""
Pipeline orchestrator: data -> simulation -> metrics -> plots.

Single entry point for the full backtesting workflow. Runnable as CLI:
    python -m backtesting.pipeline --output ./output --name my_run -v

Or importable as Python module:
    from backtesting.pipeline import run_pipeline, PipelineResult
    result = run_pipeline(config={'data': {'n_voters': 200}})
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime
import json
import math
import pathlib
import sys
import tomllib
import warnings
from dataclasses import dataclass
from typing import Any

from backtesting.data.budget import AllocationDistribution
from backtesting.data.factory import VoteTimingConfig, generate_scenario
from backtesting.data.loader import events_to_dataframe
from backtesting.metrics import (
    compute_enp,
    compute_flip_rate,
    compute_gini,
    compute_late_vote_share,
    compute_lockin_timing,
    compute_margin_shift,
    compute_nakamoto_coefficient,
    compute_participation_rate,
    compute_top_k_concentration,
    compute_transition_matrix,
)
from backtesting.plots import (
    plot_cumulative_vote_curve,
    plot_enp_comparison,
    plot_flip_rate_summary,
    plot_gini_comparison,
    plot_late_vote_share,
    plot_lock_duration_histogram,
    plot_lorenz_curve,
    plot_margin_shift_histogram,
    plot_proposal_story,
    plot_top_k_comparison,
    plot_transition_matrix,
)
from backtesting.simulation.runner import build_results_dataframe, run_backtest

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

_DEFAULTS: dict[str, Any] = {
    'data': {
        'n_voters': 200,
        'n_proposals': 30,
        'seed': 42,
        'stake_profile': 'pareto',
        'lock_profile': 'independent',
    },
    'output': {
        'dir': './output',
        'name': None,
    },
}

# ---------------------------------------------------------------------------
# Starter TOML template (for --init)
# ---------------------------------------------------------------------------

_STARTER_TOML = """\
# backtesting.toml — Signals backtesting configuration
# All values shown are defaults. Uncomment and edit as needed.

[data]
# n_voters = 200
# n_proposals = 30
# seed = 42
# stake_profile = "pareto"   # "pareto" | "uniform" | "bimodal"
# lock_profile = "independent"  # "correlated" | "inverse_correlated" | "independent" | "bimodal"

[output]
# dir = "./output"
# name = ""   # empty = auto-timestamp
"""

# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class PipelineResult:
    """Result of a complete pipeline run.

    Attributes
    ----------
    metrics : dict
        Keyed by metric name (e.g. 'flip_rate', 'gini'). Values are plain
        dicts produced by dataclasses.asdict() with NaN replaced by None.
    plot_paths : list[str]
        Absolute paths to all saved PNG files.
    output_dir : str
        Absolute path to the experiment output directory.
    """

    metrics: dict
    plot_paths: list
    output_dir: str


# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------


def _deep_merge(base: dict, override: dict) -> dict:
    """Recursively merge override into base, returning a new dict."""
    result = dict(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def _resolve_config(config: Any) -> dict:
    """Load and merge user config over _DEFAULTS.

    Parameters
    ----------
    config : None | str | pathlib.Path | dict
        - None: auto-discover backtesting.toml in CWD; use empty dict if absent
        - str/Path: load TOML from that path
        - dict: use directly
    """
    if config is None:
        toml_path = pathlib.Path.cwd() / 'backtesting.toml'
        if toml_path.exists():
            with open(toml_path, 'rb') as f:
                user_cfg = tomllib.load(f)
        else:
            user_cfg = {}
    elif isinstance(config, (str, pathlib.Path)):
        with open(config, 'rb') as f:
            user_cfg = tomllib.load(f)
    elif isinstance(config, dict):
        user_cfg = config
    else:
        raise TypeError(f'config must be None, str, Path, or dict — got {type(config)}')

    return _deep_merge(_DEFAULTS, user_cfg)


# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------


def _make_output_dir(cfg: dict) -> pathlib.Path:
    """Create and return the absolute output directory path."""
    output_base = pathlib.Path(cfg['output']['dir'])
    name = cfg['output'].get('name')

    if name and str(name).strip():
        out_dir = output_base / str(name)
    else:
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        out_dir = output_base / timestamp

    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir


# ---------------------------------------------------------------------------
# NaN -> None converter (for JSON serialization)
# ---------------------------------------------------------------------------


def _nan_to_none(obj: Any) -> Any:
    """Recursively replace float('nan') with None for JSON compatibility."""
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return obj
    if isinstance(obj, dict):
        return {k: _nan_to_none(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        converted = [_nan_to_none(v) for v in obj]
        return type(obj)(converted)
    return obj


# ---------------------------------------------------------------------------
# Core pipeline
# ---------------------------------------------------------------------------

# Keys accepted by generate_scenario
_GENERATE_SCENARIO_KEYS = frozenset({
    'n_voters', 'n_proposals', 'total_supply', 'avg_participation_rate',
    'stake_profile', 'lock_profile', 'pareto_alpha', 'l_max_days',
    'proposal_window_blocks', 'seed', 'budget_enabled', 'allocation_strategy',
    'blocks_per_day', 'curve_type', 'mc_dist', 'vote_timing',
})


def run_pipeline(
    config: Any = None,
    verbose: bool = False,
    mc_dist: AllocationDistribution | None = None,
    vote_timing: VoteTimingConfig | None = None,
) -> PipelineResult:
    """Execute the full data -> simulation -> metrics -> plots pipeline.

    Parameters
    ----------
    config : None | str | pathlib.Path | dict
        Configuration source. See _resolve_config for details.
    verbose : bool
        If True, print stage progress to stdout.
    mc_dist : AllocationDistribution | None
        Optional Monte Carlo allocation distribution object. When provided,
        injected directly into generate_scenario() as mc_dist= kwarg.
        Bypasses TOML config — programmatic API only.
    vote_timing : VoteTimingConfig | None
        Optional vote timing configuration object. When provided, injected
        directly into generate_scenario() as vote_timing= kwarg.
        Bypasses TOML config — programmatic API only.

    Returns
    -------
    PipelineResult
        Contains .metrics (dict), .plot_paths (list[str]), .output_dir (str).

    Raises
    ------
    RuntimeError
        If any pipeline stage fails, wraps the underlying exception.
    """
    cfg = _resolve_config(config)
    out_dir = _make_output_dir(cfg)

    # ------------------------------------------------------------------ #
    # Stage 1: Data generation
    # ------------------------------------------------------------------ #
    if verbose:
        print('Generating data...')
    try:
        data_cfg = {k: v for k, v in cfg.get('data', {}).items() if k in _GENERATE_SCENARIO_KEYS}
        # Inject object params from programmatic API (bypass TOML, which can't encode them)
        if mc_dist is not None:
            data_cfg['mc_dist'] = mc_dist
        if vote_timing is not None:
            data_cfg['vote_timing'] = vote_timing
        events = generate_scenario(**data_cfg)
    except Exception as e:
        raise RuntimeError(f'Pipeline stage "data" failed: {e}') from e

    # ------------------------------------------------------------------ #
    # Stage 2: Simulation
    # ------------------------------------------------------------------ #
    if verbose:
        print('Running simulation...')
    try:
        # Extract windows_df BEFORE running simulation
        events_df = events_to_dataframe(events)
        windows_df = (
            events_df[events_df['event_type'] == 'PROPOSAL_CREATED']
            [['proposal_id', 'start_block', 'end_block']]
            .copy()
            .reset_index(drop=True)
        )

        curve_type = cfg.get('data', {}).get('curve_type', 'sqrt')

        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            raw = run_backtest(events, curve_type=curve_type)

        results_df = build_results_dataframe(raw, events)
    except Exception as e:
        raise RuntimeError(f'Pipeline stage "simulation" failed: {e}') from e

    # ------------------------------------------------------------------ #
    # Stage 3: Metrics
    # ------------------------------------------------------------------ #
    if verbose:
        print('Computing metrics...')
    try:
        flip_result = compute_flip_rate(results_df)
        gini_result = compute_gini(results_df, curve_type=curve_type)
        participation_result = compute_participation_rate(results_df)
        enp_result = compute_enp(results_df, curve_type=curve_type)
        nakamoto_result = compute_nakamoto_coefficient(results_df, curve_type=curve_type)
        margin_shift_result = compute_margin_shift(results_df)
        transition_result = compute_transition_matrix(results_df)
        late_vote_result = compute_late_vote_share(results_df, windows_df, curve_type=curve_type)
        lockin_result = compute_lockin_timing(results_df, windows_df, curve_type=curve_type)
        topk_result = compute_top_k_concentration(results_df, curve_type=curve_type)

        metrics_dict = {
            'flip_rate': _nan_to_none(dataclasses.asdict(flip_result)),
            'gini': _nan_to_none(dataclasses.asdict(gini_result)),
            'participation_rate': _nan_to_none(dataclasses.asdict(participation_result)),
            'enp': _nan_to_none(dataclasses.asdict(enp_result)),
            'nakamoto_coefficient': _nan_to_none(dataclasses.asdict(nakamoto_result)),
            'margin_shift': _nan_to_none(dataclasses.asdict(margin_shift_result)),
            'transition_matrix': _nan_to_none(dataclasses.asdict(transition_result)),
            'late_vote_share': _nan_to_none(dataclasses.asdict(late_vote_result)),
            'lockin_timing': _nan_to_none(dataclasses.asdict(lockin_result)),
            'top_k_concentration': _nan_to_none(dataclasses.asdict(topk_result)),
        }
    except Exception as e:
        raise RuntimeError(f'Pipeline stage "metrics" failed: {e}') from e

    # ------------------------------------------------------------------ #
    # Stage 4: Plots
    # ------------------------------------------------------------------ #
    if verbose:
        print('Plotting...')
    try:
        all_paths: list[pathlib.Path] = []

        def _save(fig: Any, filename: str) -> pathlib.Path:
            path = out_dir / filename
            fig.savefig(str(path), dpi=300, bbox_inches='tight')
            fig.clf()
            all_paths.append(path)
            return path

        _save(plot_flip_rate_summary(flip_result), 'flip_rate.png')
        _save(plot_margin_shift_histogram(margin_shift_result), 'margin_shift.png')
        _save(plot_transition_matrix(transition_result), 'transition_matrix.png')
        _save(plot_gini_comparison(gini_result), 'gini_comparison.png')
        _save(plot_top_k_comparison(topk_result), 'top_k_comparison.png')
        _save(plot_enp_comparison(enp_result), 'enp_comparison.png')
        _save(plot_late_vote_share(late_vote_result), 'late_vote_share.png')
        _save(plot_lorenz_curve(results_df), 'lorenz_curve.png')
        _save(plot_lock_duration_histogram(results_df), 'lock_duration_histogram.png')

        # Per-proposal plots
        vote_mask = results_df['event_type'] == 'VOTE_CAST'
        proposal_ids = sorted(results_df.loc[vote_mask, 'proposal_id'].dropna().unique())
        for pid in proposal_ids:
            _save(
                plot_cumulative_vote_curve(results_df, pid),
                f'cumulative_vote_{pid}.png',
            )
            _save(
                plot_proposal_story(results_df, pid, lockin_result),
                f'proposal_story_{pid}.png',
            )
    except Exception as e:
        raise RuntimeError(f'Pipeline stage "plots" failed: {e}') from e

    # ------------------------------------------------------------------ #
    # Save metrics.json
    # ------------------------------------------------------------------ #
    metrics_json_path = out_dir / 'metrics.json'
    with open(metrics_json_path, 'w') as f:
        json.dump(metrics_dict, f, indent=2)

    if verbose:
        print(f'Done. Output: {out_dir}')

    return PipelineResult(
        metrics=metrics_dict,
        plot_paths=[str(p) for p in all_paths],
        output_dir=str(out_dir),
    )


# ---------------------------------------------------------------------------
# CLI helpers
# ---------------------------------------------------------------------------


def _write_init_config() -> None:
    """Write _STARTER_TOML to CWD/backtesting.toml and print the path."""
    dest = pathlib.Path.cwd() / 'backtesting.toml'
    dest.write_text(_STARTER_TOML)
    print(f'Wrote config template to: {dest}')


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        prog='python -m backtesting.pipeline',
        description='Run the full backtesting pipeline: data -> simulation -> metrics -> plots.',
    )
    parser.add_argument(
        '--output',
        default='./output',
        metavar='DIR',
        help='Base output directory (default: ./output)',
    )
    parser.add_argument(
        '--name',
        default=None,
        metavar='NAME',
        help='Experiment name (subdirectory under --output). Auto-timestamp if omitted.',
    )
    parser.add_argument(
        '--config',
        default=None,
        metavar='PATH',
        help='Path to backtesting.toml config file.',
    )
    parser.add_argument(
        '--init',
        action='store_true',
        help='Write a starter backtesting.toml to the current directory and exit.',
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Print stage progress to stdout.',
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    """CLI entry point for the backtesting pipeline."""
    args = _parse_args(argv)

    if args.init:
        _write_init_config()
        sys.exit(0)

    # Build config: start from --config path (or None for auto-discover)
    cfg: Any = args.config  # str path or None

    # If no explicit --config, build a minimal dict so CLI overrides work
    # Start with None to trigger auto-discover logic in _resolve_config,
    # then we need to overlay --output / --name.
    # We do this by resolving first, then patching the output section.
    resolved = _resolve_config(cfg)

    # Overlay CLI output args (user provided --output or --name explicitly)
    resolved['output']['dir'] = args.output
    if args.name is not None:
        resolved['output']['name'] = args.name

    run_pipeline(config=resolved, verbose=args.verbose)


if __name__ == '__main__':
    main()
