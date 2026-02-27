"""
Pytest configuration and shared fixtures for the simulation test suite.
"""

import pytest
import os
import sys

# Add src directory to Python path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

# ---------------------------------------------------------------------------
# Backtesting fixtures (backtesting.data — 03-02)
# ---------------------------------------------------------------------------
from backtesting.data.factory import generate_scenario
from backtesting.data.loader import events_to_dataframe


@pytest.fixture
def default_scenario_config():
    """Config dict for a full-scale scenario (200 voters, 30 proposals)."""
    return {
        'n_voters': 200,
        'n_proposals': 30,
        'total_supply': 1_000_000.0,
        'avg_participation_rate': 0.10,
        'stake_profile': 'pareto',
        'lock_profile': 'independent',
        'seed': 42,
    }


@pytest.fixture
def small_scenario_config():
    """Config dict for a fast test scenario (50 voters, 5 proposals)."""
    return {
        'n_voters': 50,
        'n_proposals': 5,
        'total_supply': 1_000_000.0,
        'avg_participation_rate': 0.10,
        'stake_profile': 'pareto',
        'lock_profile': 'independent',
        'seed': 42,
    }


@pytest.fixture
def sample_events(small_scenario_config):
    """In-memory event list from small scenario config."""
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        return generate_scenario(**small_scenario_config)


@pytest.fixture
def sample_dataframe(sample_events):
    """DataFrame produced from sample_events."""
    return events_to_dataframe(sample_events)

# ---------------------------------------------------------------------------
# Phase 4 fixtures (backtesting.simulation — 04-02)
# ---------------------------------------------------------------------------

@pytest.fixture
def minimal_event_records():
    """Minimal 5-event stream for 1 proposal. No factory dependency."""
    return [
        {'event_type': 'PROPOSAL_CREATED', 'proposal_id': 'p1', 'block_number': 100, 'voter': None, 'support': None, 'weight': None, 'lock_duration_days': None},
        {'event_type': 'VOTE_CAST', 'proposal_id': 'p1', 'block_number': 110, 'voter': '0xA', 'support': 'FOR', 'weight': 1000.0, 'lock_duration_days': 90.0},
        {'event_type': 'VOTE_CAST', 'proposal_id': 'p1', 'block_number': 120, 'voter': '0xB', 'support': 'AGAINST', 'weight': 500.0, 'lock_duration_days': 0.0},
        {'event_type': 'VOTE_CAST', 'proposal_id': 'p1', 'block_number': 130, 'voter': '0xC', 'support': 'ABSTAIN', 'weight': 200.0, 'lock_duration_days': 365.0},
        {'event_type': 'PROPOSAL_FINALIZED', 'proposal_id': 'p1', 'block_number': 200, 'voter': None, 'support': None, 'weight': None, 'lock_duration_days': None},
    ]


@pytest.fixture
def backtest_raw_result(minimal_event_records):
    """raw_result from run_backtest on minimal_event_records."""
    import warnings
    from backtesting.simulation.runner import run_backtest
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        return run_backtest(minimal_event_records)


@pytest.fixture
def backtest_dataframe(backtest_raw_result, minimal_event_records):
    """Results DataFrame from build_results_dataframe on minimal run."""
    from backtesting.simulation.runner import build_results_dataframe
    return build_results_dataframe(backtest_raw_result, minimal_event_records)


# ---------------------------------------------------------------------------
# Phase 5 fixtures (backtesting.metrics — 05-02)
# ---------------------------------------------------------------------------

@pytest.fixture
def metrics_results_df(sample_events):
    """Results DataFrame from full 50-voter, 5-proposal scenario (seed=42).

    Uses sample_events fixture (already defined above). Produces a DataFrame
    with enough proposals and votes to meaningfully test all 10 metrics.
    """
    import warnings
    from backtesting.simulation.runner import run_backtest, build_results_dataframe
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        raw = run_backtest(sample_events)
    return build_results_dataframe(raw, sample_events)


@pytest.fixture
def metrics_windows_df(sample_events):
    """Windows DataFrame with proposal_id, start_block, end_block.

    Required by timing metrics (METR-08, METR-09). Extracted from the
    PROPOSAL_CREATED rows of the loader DataFrame.
    """
    from backtesting.data.loader import events_to_dataframe
    events_df = events_to_dataframe(sample_events)
    return (
        events_df[events_df['event_type'] == 'PROPOSAL_CREATED']
        [['proposal_id', 'start_block', 'end_block']]
        .copy()
        .reset_index(drop=True)
    )


# Test markers for different test categories
def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "unit: mark test as a unit test")
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")
    config.addinivalue_line("markers", "performance: mark test as a performance test")


# Pytest collection hooks
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers automatically."""
    for item in items:
        # Add markers based on test file names
        if "test_simulation.py" in str(item.fspath):
            item.add_marker(pytest.mark.integration)

        # Add slow marker for performance tests
        if "performance" in item.name.lower():
            item.add_marker(pytest.mark.slow)
            item.add_marker(pytest.mark.performance)
