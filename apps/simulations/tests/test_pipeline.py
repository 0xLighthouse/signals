"""
Requirement-traced tests for the backtesting pipeline module.

Tests verify PIPE-01, PIPE-02, PIPE-03 requirements.

PIPE-01: Single entry point that orchestrates the full data->simulation->metrics->plots workflow
PIPE-02: Outputs (plots + metrics.json) saved to a configurable named directory
PIPE-03: Usable as CLI (python -m backtesting.pipeline) or importable API
"""
import matplotlib
matplotlib.use('Agg')  # Must be FIRST matplotlib call — before any backtesting import

import dataclasses
import json
import math
import os
import pathlib
import subprocess
import sys

import pytest

from backtesting.pipeline import PipelineResult, run_pipeline

# Path to apps/simulations/src for subprocess PYTHONPATH
_SRC_PATH = str(pathlib.Path(__file__).parent.parent / 'src')
_APPS_SIM_DIR = str(pathlib.Path(__file__).parent.parent)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope='module')
def pipeline_result(tmp_path_factory):
    """Run the full pipeline once for this module; all tests reuse the result.

    Uses 50 voters / 5 proposals for speed. Outputs go to a temporary directory.
    """
    tmp_dir = tmp_path_factory.mktemp('pipeline_output')
    result = run_pipeline(
        config={
            'data': {'n_voters': 50, 'n_proposals': 5, 'seed': 42},
            'output': {'dir': str(tmp_dir), 'name': 'test_run'},
        },
        verbose=False,
    )
    return result


# ---------------------------------------------------------------------------
# PIPE-01: Single entry point orchestrates full workflow
# ---------------------------------------------------------------------------

@pytest.mark.slow
def test_pipe01_run_pipeline_returns_result(pipeline_result):
    """PIPE-01: run_pipeline() returns a PipelineResult with all required fields."""
    assert isinstance(pipeline_result, PipelineResult), (
        f'Expected PipelineResult, got {type(pipeline_result)}'
    )
    assert isinstance(pipeline_result.metrics, dict) and len(pipeline_result.metrics) > 0, (
        'metrics dict is empty'
    )
    assert isinstance(pipeline_result.plot_paths, list) and len(pipeline_result.plot_paths) > 0, (
        'plot_paths list is empty'
    )
    assert isinstance(pipeline_result.output_dir, str) and len(pipeline_result.output_dir) > 0, (
        'output_dir is empty string'
    )


@pytest.mark.slow
def test_pipe01_metrics_keys_complete(pipeline_result):
    """PIPE-01: metrics dict contains all 10 required metric keys."""
    expected_keys = {
        'flip_rate',
        'gini',
        'participation_rate',
        'enp',
        'nakamoto_coefficient',
        'margin_shift',
        'transition_matrix',
        'late_vote_share',
        'lockin_timing',
        'top_k_concentration',
    }
    actual_keys = set(pipeline_result.metrics.keys())
    assert actual_keys == expected_keys, (
        f'Missing metric keys: {expected_keys - actual_keys}. '
        f'Extra keys: {actual_keys - expected_keys}'
    )


@pytest.mark.slow
def test_pipe01_cli_entry_point(tmp_path):
    """PIPE-01 + PIPE-03: python -m backtesting.pipeline runs end-to-end via CLI."""
    env = {**os.environ, 'PYTHONPATH': _SRC_PATH}
    result = subprocess.run(
        [
            sys.executable,
            '-m', 'backtesting.pipeline',
            '--output', str(tmp_path),
            '--name', 'cli_test',
        ],
        capture_output=True,
        text=True,
        cwd=_APPS_SIM_DIR,
        env=env,
        timeout=120,
    )
    assert result.returncode == 0, (
        f'CLI failed (returncode={result.returncode}).\n'
        f'stdout: {result.stdout}\nstderr: {result.stderr}'
    )
    out_dir = tmp_path / 'cli_test'
    assert out_dir.is_dir(), f'Expected output dir {out_dir} to exist'
    png_files = list(out_dir.glob('*.png'))
    assert len(png_files) > 0, 'No PNG files found in CLI output dir'
    assert (out_dir / 'metrics.json').exists(), 'metrics.json not found in CLI output dir'


# ---------------------------------------------------------------------------
# PIPE-02: Outputs saved to configurable directory
# ---------------------------------------------------------------------------

@pytest.mark.slow
def test_pipe02_output_dir_exists(pipeline_result):
    """PIPE-02: Output directory exists after pipeline run."""
    out_dir = pathlib.Path(pipeline_result.output_dir)
    assert out_dir.is_dir(), f'Output directory does not exist: {out_dir}'


@pytest.mark.slow
def test_pipe02_metrics_json_written(pipeline_result):
    """PIPE-02: metrics.json is written to the output directory and is a valid dict."""
    metrics_path = pathlib.Path(pipeline_result.output_dir) / 'metrics.json'
    assert metrics_path.exists(), f'metrics.json not found at {metrics_path}'
    with open(metrics_path) as f:
        data = json.load(f)
    assert isinstance(data, dict) and len(data) > 0, 'metrics.json loaded as empty or non-dict'


@pytest.mark.slow
def test_pipe02_plot_files_written(pipeline_result):
    """PIPE-02: All plot paths exist on disk, all are PNG, at least 11 files."""
    assert len(pipeline_result.plot_paths) >= 11, (
        f'Expected at least 11 plot files, got {len(pipeline_result.plot_paths)}'
    )
    for path_str in pipeline_result.plot_paths:
        p = pathlib.Path(path_str)
        assert p.exists(), f'Plot file does not exist: {p}'
        assert p.suffix == '.png', f'Expected .png suffix, got {p.suffix} for {p}'


@pytest.mark.slow
def test_pipe02_named_output_dir(pipeline_result):
    """PIPE-02: Named output directory ends with the provided experiment name."""
    out_dir = pipeline_result.output_dir
    assert out_dir.endswith('/test_run') or out_dir.endswith('\\test_run'), (
        f"Expected output_dir to end with '/test_run', got: {out_dir}"
    )


# ---------------------------------------------------------------------------
# PIPE-03: CLI or module import
# ---------------------------------------------------------------------------

def test_pipe03_importable_api():
    """PIPE-03: run_pipeline and PipelineResult are importable and well-formed."""
    from backtesting.pipeline import PipelineResult as PR, run_pipeline as rp  # noqa: F401

    assert callable(rp), 'run_pipeline is not callable'

    # PipelineResult should have the three required fields
    fields = {f.name for f in dataclasses.fields(PR)}
    assert 'metrics' in fields, 'PipelineResult missing .metrics field'
    assert 'plot_paths' in fields, 'PipelineResult missing .plot_paths field'
    assert 'output_dir' in fields, 'PipelineResult missing .output_dir field'


# ---------------------------------------------------------------------------
# INT-03: _GENERATE_SCENARIO_KEYS includes mc_dist and vote_timing
# ---------------------------------------------------------------------------

def test_generate_scenario_keys_include_mc_dist_vote_timing():
    """INT-03: _GENERATE_SCENARIO_KEYS frozenset includes 'mc_dist' and 'vote_timing'."""
    from backtesting.pipeline import _GENERATE_SCENARIO_KEYS
    assert 'mc_dist' in _GENERATE_SCENARIO_KEYS, (
        "'mc_dist' must be in _GENERATE_SCENARIO_KEYS for pipeline to pass it to generate_scenario"
    )
    assert 'vote_timing' in _GENERATE_SCENARIO_KEYS, (
        "'vote_timing' must be in _GENERATE_SCENARIO_KEYS for pipeline to pass it to generate_scenario"
    )


# ---------------------------------------------------------------------------
# INT-04: VoteTimingConfig re-export from backtesting.data
# ---------------------------------------------------------------------------

def test_vote_timing_config_importable_from_data():
    """INT-04: VoteTimingConfig is importable from backtesting.data (re-export)."""
    from backtesting.data import VoteTimingConfig
    vtc = VoteTimingConfig(early=0.25, mid=0.45)
    assert vtc.early == 0.25, f'Expected early=0.25, got {vtc.early}'
    assert vtc.mid == 0.45, f'Expected mid=0.45, got {vtc.mid}'


@pytest.mark.slow
def test_pipe03_init_flag(tmp_path):
    """PIPE-03: --init flag writes a valid backtesting.toml template."""
    env = {**os.environ, 'PYTHONPATH': _SRC_PATH}
    result = subprocess.run(
        [sys.executable, '-m', 'backtesting.pipeline', '--init'],
        capture_output=True,
        text=True,
        cwd=str(tmp_path),
        env=env,
        timeout=30,
    )
    assert result.returncode == 0, (
        f'--init failed (returncode={result.returncode}).\n'
        f'stdout: {result.stdout}\nstderr: {result.stderr}'
    )
    toml_path = tmp_path / 'backtesting.toml'
    assert toml_path.exists(), f'backtesting.toml not created at {toml_path}'
    content = toml_path.read_text()
    assert '[data]' in content, 'backtesting.toml missing [data] section'


# ---------------------------------------------------------------------------
# JSON validity: no NaN values in metrics.json
# ---------------------------------------------------------------------------

def _walk_for_nan(obj, path=''):
    """Recursively walk obj and raise AssertionError on any NaN/Inf value."""
    if isinstance(obj, float):
        assert not math.isnan(obj), f'NaN found at {path}'
        assert not math.isinf(obj), f'Inf found at {path}'
    elif isinstance(obj, str):
        assert obj.lower() != 'nan', f"String 'NaN' found at {path}"
        assert obj.lower() != 'inf', f"String 'Inf' found at {path}"
    elif isinstance(obj, dict):
        for k, v in obj.items():
            _walk_for_nan(v, f'{path}.{k}')
    elif isinstance(obj, (list, tuple)):
        for i, v in enumerate(obj):
            _walk_for_nan(v, f'{path}[{i}]')


@pytest.mark.slow
def test_pipe02_metrics_json_no_nan(pipeline_result):
    """PIPE-02: metrics.json contains no NaN or Inf values (valid JSON numerics only)."""
    metrics_path = pathlib.Path(pipeline_result.output_dir) / 'metrics.json'
    with open(metrics_path) as f:
        data = json.load(f)
    # json.load converts JSON null to None, so we walk the raw dict
    _walk_for_nan(data, 'metrics.json')
