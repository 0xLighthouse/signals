"""
Tests for backtesting.sweep data model, configuration layer, and execution engine.

Requirement traces:
- test_swep01: SWEP-01 — cartesian product enumeration
- test_swep02: SWEP-02 — cartesian not zip
- test_swep03: SWEP-03 — parallel execution via ProcessPoolExecutor
- test_swep04: SWEP-04 — memory release after each cell
- test_swep05: SWEP-05 — SweepResult summary_df shape
- test_swep06: SWEP-06 — tqdm progress bar
- test_swep07: SWEP-07 — TOML config loading
"""
import inspect
import pathlib

import pandas as pd
import pytest

from backtesting.sweep import (
    SweepConfig,
    SweepCell,
    SweepResult,
    _enumerate_cells,
    _run_cell,
    load_sweep_config,
    run_sweep,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_base_config() -> SweepConfig:
    """Base config: 2 curve_types x 3 alphas x 1 lock_profile x 2 strategies = 12 cells."""
    return SweepConfig(
        curve_types=['sqrt', 'log'],
        alphas=[0.5, 1.0, 2.0],
        lock_profiles=[{'short': 30, 'long': 365}],
        allocation_strategies=['uniform_fraction', 'conviction_weighted'],
        max_workers=1,
    )


# ---------------------------------------------------------------------------
# SWEP-01: Cartesian product enumeration
# ---------------------------------------------------------------------------


def test_swep01_cartesian_product():
    """SWEP-01: _enumerate_cells produces exactly 12 cells for 2x3x1x2 grid."""
    config = _make_base_config()
    cells = _enumerate_cells(config)

    # Exactly 12 cells
    assert len(cells) == 12, f'Expected 12 cells, got {len(cells)}'

    # All cell_ids are unique and sequential 0-11
    cell_ids = [c.cell_id for c in cells]
    assert cell_ids == list(range(12)), f'Expected sequential IDs 0-11, got {cell_ids}'

    # Every (curve_type, alpha, strategy) combination appears exactly once
    combos = set(
        (c.curve_type, c.alpha, c.allocation_strategy) for c in cells
    )
    expected_combos = set()
    for ct in config.curve_types:
        for alpha in config.alphas:
            for strat in config.allocation_strategies:
                expected_combos.add((ct, alpha, strat))
    assert combos == expected_combos, f'Missing combos: {expected_combos - combos}'


# ---------------------------------------------------------------------------
# SWEP-02: Cartesian not zip
# ---------------------------------------------------------------------------


def test_swep02_cartesian_not_zip():
    """SWEP-02: Grid is cartesian product not zip — 6 unique (curve_type, alpha) pairs."""
    config = _make_base_config()
    cells = _enumerate_cells(config)

    # Collect all (curve_type, alpha) pairs
    ct_alpha_pairs = set((c.curve_type, c.alpha) for c in cells)

    # Cartesian: 2 curve_types * 3 alphas = 6 unique pairs
    # Zip would only produce 2 pairs (one per position)
    assert len(ct_alpha_pairs) == 6, (
        f'Expected 6 unique (curve_type, alpha) pairs from cartesian product, '
        f'got {len(ct_alpha_pairs)}: {ct_alpha_pairs}'
    )

    # Also verify each curve_type appears with each alpha
    expected_pairs = {(ct, alpha) for ct in config.curve_types for alpha in config.alphas}
    assert ct_alpha_pairs == expected_pairs, (
        f'Missing pairs: {expected_pairs - ct_alpha_pairs}'
    )


# ---------------------------------------------------------------------------
# SWEP-05: SweepResult summary_df shape
# ---------------------------------------------------------------------------


def test_swep05_summary_df_shape():
    """SWEP-05: SweepResult.summary_df has one row per cell with expected columns."""
    config = _make_base_config()
    summary_df = pd.DataFrame([
        {
            'cell_id': i,
            'curve_type': 'sqrt',
            'alpha': 0.5,
            'flip_rate': 0.1,
            'failed': False,
        }
        for i in range(12)
    ])

    result = SweepResult(
        config=config,
        summary_df=summary_df,
        failed_cells=[],
        output_dir='/tmp/test_output',
    )

    # 12 rows — one per cell
    assert len(result.summary_df) == 12, (
        f'Expected 12 rows, got {len(result.summary_df)}'
    )

    # Expected columns exist
    expected_cols = {'cell_id', 'curve_type', 'alpha', 'flip_rate', 'failed'}
    actual_cols = set(result.summary_df.columns)
    missing_cols = expected_cols - actual_cols
    assert not missing_cols, f'Missing columns: {missing_cols}'


# ---------------------------------------------------------------------------
# SWEP-07: TOML config loading
# ---------------------------------------------------------------------------


def test_swep07_toml_config(tmp_path: pathlib.Path):
    """SWEP-07: TOML config with [base] and [sweep] sections loads correctly."""
    toml_content = """\
[base]
n_voters = 50
n_proposals = 3
seed = 42

[sweep]
curve_types = ["sqrt", "log"]
alphas = [0.5, 1.0]
max_workers = 2
cell_timeout_seconds = 60

[[sweep.lock_profiles]]
short = 30
long = 365

[[sweep.lock_profiles]]
short = 90
long = 730
"""
    toml_path = tmp_path / 'sweep.toml'
    toml_path.write_text(toml_content)

    config = load_sweep_config(toml_path)

    assert config.curve_types == ['sqrt', 'log']
    assert config.alphas == [0.5, 1.0]
    assert len(config.lock_profiles) == 2
    assert config.max_workers == 2
    assert config.cell_timeout_seconds == 60
    assert config.base['n_voters'] == 50
    assert config.base.get('n_proposals') == 3
    assert config.base.get('seed') == 42
    # allocation_strategies defaults to ['uniform_fraction'] when not specified
    assert config.allocation_strategies == ['uniform_fraction'], (
        f'Expected default allocation_strategies, got {config.allocation_strategies}'
    )


def test_swep07_toml_missing_max_workers(tmp_path: pathlib.Path):
    """SWEP-07: load_sweep_config raises KeyError if max_workers is not specified."""
    toml_content = """\
[sweep]
curve_types = ["sqrt"]
alphas = [0.5]

[[sweep.lock_profiles]]
short = 30
long = 365
"""
    toml_path = tmp_path / 'sweep_no_workers.toml'
    toml_path.write_text(toml_content)

    with pytest.raises(KeyError):
        load_sweep_config(toml_path)


# ---------------------------------------------------------------------------
# SWEP-03: Parallel execution via ProcessPoolExecutor (integration tests)
# ---------------------------------------------------------------------------


def test_swep03_parallel_execution(tmp_path: pathlib.Path):
    """SWEP-03: run_sweep() executes a single cell successfully via ProcessPoolExecutor.

    Integration test — runs actual simulation with small n_voters=20 and n_proposals=3.
    """
    config = SweepConfig(
        curve_types=['sqrt'],
        alphas=[0.5],
        lock_profiles=[{'short': 30, 'long': 365}],
        allocation_strategies=['uniform_fraction'],
        max_workers=1,
        base={'n_voters': 20, 'n_proposals': 3, 'seed': 42},
    )
    result = run_sweep(config, output_dir=str(tmp_path))

    # One row in summary_df — one cell in grid
    assert len(result.summary_df) == 1, (
        f'Expected 1 row, got {len(result.summary_df)}'
    )
    # No failures
    assert result.failed_cells == [], (
        f'Expected no failed cells, got {result.failed_cells}'
    )
    # Cell not marked failed
    assert result.summary_df['failed'].iloc[0] == False, (
        f"Expected failed=False, got {result.summary_df['failed'].iloc[0]}"
    )
    # Metrics were computed (flip_rate is not NaN)
    assert result.summary_df['flip_rate'].notna().all(), (
        f"Expected flip_rate to be non-NaN: {result.summary_df['flip_rate'].tolist()}"
    )

    # Auto-export files exist
    out = pathlib.Path(result.output_dir)
    assert (out / 'summary.csv').exists(), f'summary.csv missing from {out}'
    assert (out / 'config.json').exists(), f'config.json missing from {out}'


def test_swep03_multi_cell_sweep(tmp_path: pathlib.Path):
    """SWEP-03: run_sweep() produces exactly 12 rows for 2x3x1x2 grid.

    Integration test — runs actual simulations with small n_voters=20 and n_proposals=3.
    Validates SWEP-01 end-to-end: '2 curve types, 3 alpha values, and 2 allocation
    strategies produces exactly 12 result rows.'
    """
    config = SweepConfig(
        curve_types=['sqrt', 'log'],
        alphas=[0.5, 1.0, 2.0],
        lock_profiles=[{'short': 30, 'long': 365}],
        allocation_strategies=['uniform_fraction', 'conviction_weighted'],
        max_workers=2,
        base={'n_voters': 20, 'n_proposals': 3, 'seed': 42},
    )
    result = run_sweep(config, output_dir=str(tmp_path))

    # Exactly 12 cells from 2*3*1*2 cartesian product
    assert len(result.summary_df) == 12, (
        f'Expected 12 rows, got {len(result.summary_df)}'
    )

    # All expected metric columns are present
    expected_cols = {
        'cell_id', 'curve_type', 'alpha', 'lock_profile_short', 'lock_profile_long',
        'allocation_strategy', 'flip_rate', 'gini_legacy', 'gini_signals',
        'participation_rate', 'margin_shift_mean', 'margin_shift_std',
        'enp_legacy_mean', 'enp_signals_mean', 'nakamoto_legacy_mean',
        'nakamoto_signals_mean', 'failed',
    }
    actual_cols = set(result.summary_df.columns)
    missing_cols = expected_cols - actual_cols
    assert not missing_cols, f'Missing columns: {missing_cols}'


# ---------------------------------------------------------------------------
# SWEP-04: Memory release after each cell
# ---------------------------------------------------------------------------


def test_swep04_memory_release():
    """SWEP-04: _run_cell() contains del raw and gc.collect() for memory management.

    Static source inspection — dynamic memory profiling is fragile in CI.
    """
    src = inspect.getsource(_run_cell)
    assert 'del raw' in src, (
        '_run_cell() must contain "del raw" for memory management (SWEP-04)'
    )
    assert 'gc.collect()' in src, (
        '_run_cell() must contain "gc.collect()" for memory management (SWEP-04)'
    )


# ---------------------------------------------------------------------------
# SWEP-06: tqdm progress bar
# ---------------------------------------------------------------------------


def test_swep06_tqdm_progress():
    """SWEP-06: run_sweep() uses tqdm for progress reporting.

    Static source inspection verifies tqdm is used in the orchestrator.
    """
    src = inspect.getsource(run_sweep)
    assert 'tqdm(' in src, (
        'run_sweep() must use tqdm() for progress reporting (SWEP-06)'
    )
