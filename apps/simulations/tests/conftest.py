"""
Pytest configuration and shared fixtures for the simulation test suite.
"""

import pytest
import tempfile
import os
from datetime import datetime
from src.cadcad.state import generate_initial_state


@pytest.fixture
def basic_initial_state():
    """Fixture providing a basic initial state for testing."""
    return generate_initial_state(num_users=5, total_supply=100000, randomize=False)


@pytest.fixture
def large_initial_state():
    """Fixture providing a larger initial state for testing."""
    return generate_initial_state(num_users=20, total_supply=1000000, randomize=True)


@pytest.fixture
def basic_params():
    """Fixture providing basic simulation parameters."""
    return {
        "acceptance_threshold": 1000.0,
        "decay_multiplier": 0.95,
        "initiative_creation_stake": 10.0,
        "prob_create_initiative": 0.08,
        "prob_support_initiative": 0.2,
        "max_support_tokens_fraction": 0.5,
        "min_lock_duration_epochs": 5,
        "max_lock_duration_epochs": 20,
        "inactivity_period": 10,
    }


@pytest.fixture
def temp_output_dir():
    """Fixture providing a temporary directory for test outputs."""
    with tempfile.TemporaryDirectory() as temp_dir:
        yield temp_dir


@pytest.fixture
def sample_policy_input():
    """Fixture providing sample policy input for testing."""
    return {
        "user_actions": [
            {
                "type": "create_initiative",
                "user_id": "0x00",
                "title": "Test Initiative",
                "description": "A test initiative for testing",
            },
            {
                "type": "support_initiative",
                "user_id": "0x01",
                "initiative_id": "test-init-id",
                "amount": 1000.0,
                "lock_duration_epochs": 10,
            },
        ]
    }


@pytest.fixture
def state_with_initiative(basic_initial_state):
    """Fixture providing a state with an existing initiative."""
    state = basic_initial_state.copy()
    state["initiatives"] = {
        "test-init-1": {
            "id": "test-init-1",
            "title": "Test Initiative 1",
            "description": "First test initiative",
            "creator": "0x00",
            "creation_epoch": 0,
            "last_support_epoch": 0,
            "weight": 0.0,
        }
    }
    return state


@pytest.fixture
def state_with_support(state_with_initiative):
    """Fixture providing a state with initiative and support."""
    state = state_with_initiative.copy()
    state["supporters"] = {
        "0x01_test-init-1": {
            "user_id": "0x01",
            "initiative_id": "test-init-1",
            "amount": 1000.0,
            "lock_duration_epochs": 10,
            "creation_epoch": 1,
            "expiry_epoch": 11,
            "current_weight": 5000.0,
            "last_decay_epoch": 1,
        }
    }
    return state


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
        elif (
            "test_state.py" in str(item.fspath)
            or "test_sufs.py" in str(item.fspath)
            or "test_policies.py" in str(item.fspath)
        ):
            item.add_marker(pytest.mark.unit)

        # Add slow marker for performance tests
        if "performance" in item.name.lower():
            item.add_marker(pytest.mark.slow)
            item.add_marker(pytest.mark.performance)
