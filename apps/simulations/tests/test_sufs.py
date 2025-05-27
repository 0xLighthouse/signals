"""
Tests for State Update Functions (SUFs).
"""

import pytest
from datetime import datetime
from src.cadcad.state import State, generate_initial_state
from src.cadcad.sufs import (
    s_apply_user_actions_initiatives,
    s_apply_user_actions_supporters,
    s_apply_user_actions_balances,
    s_apply_user_actions_circulating_supply,
    s_calculate_current_support,
    s_update_initiative_aggregate_weights,
    s_process_accepted_initiatives,
    s_process_expired_initiatives,
    s_update_current_epoch,
    s_update_current_time,
    get_state_obj,
)


class TestGetStateObj:
    """Test the get_state_obj helper function."""

    def test_get_state_obj_from_dict(self):
        """Test converting dict to State object."""
        state_dict = generate_initial_state(num_users=5, total_supply=1000000, randomize=False)
        state_obj = get_state_obj(state_dict)

        assert isinstance(state_obj, State)
        assert state_obj.total_supply == 1000000
        assert len(state_obj.balances) == 5


class TestUserActionSUFs:
    """Test SUFs that handle user actions."""

    def setup_method(self):
        """Set up test fixtures."""
        self.initial_state = generate_initial_state(
            num_users=5, total_supply=1000000, randomize=False
        )
        self.params = {
            "initiative_creation_stake": 10.0,
            "acceptance_threshold": 1000.0,
            "decay_multiplier": 0.95,
            "inactivity_period": 10,
        }

    def test_s_apply_user_actions_initiatives_create(self):
        """Test initiative creation through SUF."""
        policy_input = {
            "user_actions": [
                {
                    "type": "create_initiative",
                    "user_id": "0x00",
                    "title": "Test Initiative",
                    "description": "A test initiative",
                }
            ]
        }

        result_key, result_value = s_apply_user_actions_initiatives(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input=policy_input,
        )

        assert result_key == "initiatives"
        assert isinstance(result_value, dict)
        assert len(result_value) == 1

        # Check initiative properties
        initiative_id = list(result_value.keys())[0]
        initiative = result_value[initiative_id]
        assert initiative["title"] == "Test Initiative"
        assert initiative["id"] == initiative_id

    def test_s_apply_user_actions_initiatives_insufficient_balance(self):
        """Test initiative creation fails with insufficient balance."""
        # Set a very high creation stake
        params = self.params.copy()
        params["initiative_creation_stake"] = 1000000.0

        policy_input = {
            "user_actions": [
                {
                    "type": "create_initiative",
                    "user_id": "0x00",
                    "title": "Expensive Initiative",
                    "description": "Too expensive",
                }
            ]
        }

        result_key, result_value = s_apply_user_actions_initiatives(
            params=params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input=policy_input,
        )

        # Should not create initiative due to insufficient balance
        assert len(result_value) == 0

    def test_s_apply_user_actions_supporters_create(self):
        """Test support creation through SUF."""
        # First create an initiative
        state_with_initiative = self.initial_state.copy()
        state_with_initiative["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Test Initiative",
                "description": "Test",
                "created_at": "2025-01-01T12:00:00",
                "weight": 0.0,
                "last_support_time": "2025-01-01T12:00:00",
                "last_support_epoch": 0,
            }
        }

        policy_input = {
            "user_actions": [
                {
                    "type": "support_initiative",
                    "user_id": "0x01",
                    "initiative_id": "init1",
                    "amount": 1000.0,
                    "lock_duration_epochs": 10,
                }
            ]
        }

        result_key, result_value = s_apply_user_actions_supporters(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=state_with_initiative,
            policy_input=policy_input,
        )

        assert result_key == "locks"
        assert isinstance(result_value, dict)
        assert len(result_value) == 1

        # Check support properties
        support_key = ("0x01", "init1")  # Tuple key as used in actual implementation
        assert support_key in result_value
        support = result_value[support_key]
        assert support["user_id"] == "0x01"
        assert support["initiative_id"] == "init1"
        assert support["amount"] == 1000.0

    def test_s_apply_user_actions_balances_deduction(self):
        """Test balance deduction for user actions."""
        policy_input = {
            "user_actions": [
                {
                    "type": "create_initiative",
                    "user_id": "0x00",
                    "title": "Test Initiative",
                    "description": "Test",
                }
            ]
        }

        original_balance = self.initial_state["balances"]["0x00"]

        result_key, result_value = s_apply_user_actions_balances(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input=policy_input,
        )

        assert result_key == "balances"
        new_balance = result_value["0x00"]
        expected_balance = original_balance - self.params["initiative_creation_stake"]
        assert new_balance == expected_balance

    def test_s_apply_user_actions_circulating_supply_update(self):
        """Test circulating supply update for user actions."""
        policy_input = {
            "user_actions": [
                {
                    "type": "create_initiative",
                    "user_id": "0x00",
                    "title": "Test Initiative",
                    "description": "Test",
                }
            ]
        }

        original_supply = self.initial_state["circulating_supply"]

        result_key, result_value = s_apply_user_actions_circulating_supply(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input=policy_input,
        )

        assert result_key == "circulating_supply"
        # Initiative creation doesn't affect circulating supply, only support actions do
        assert result_value == original_supply


class TestSupportDecayAndWeights:
    """Test support decay and weight calculation SUFs."""

    def setup_method(self):
        """Set up test fixtures with support."""
        self.initial_state = generate_initial_state(
            num_users=5, total_supply=1000000, randomize=False
        )

        # Add an initiative and support
        self.initial_state["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Test Initiative",
                "description": "Test",
                "created_at": "2025-01-01T12:00:00",
                "weight": 0.0,
                "last_support_time": "2025-01-01T12:00:00",
                "last_support_epoch": 1,
            }
        }

        self.initial_state["locks"] = {
            ("0x01", "init1"): {
                "user_id": "0x01",
                "initiative_id": "init1",
                "amount": 1000.0,
                "lock_duration_epochs": 10,
                "start_epoch": 1,  # Changed from creation_epoch to start_epoch
                "expiry_epoch": 11,
                "current_weight": 5000.0,
                "initial_weight": 10000.0,  # Added missing field
            }
        }

        self.params = {
            "decay_multiplier": 0.95,
            "acceptance_threshold": 1000.0,
        }

    def test_s_apply_support_decay(self):
        """Test support decay SUF."""
        self.initial_state["current_epoch"] = 2

        result_key, result_value = s_calculate_current_support(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input={},
        )

        assert result_key == "locks"
        support = result_value[("0x01", "init1")]

        # Weight should have decayed
        expected_weight = 5000.0 * 0.95
        assert support["current_weight"] == expected_weight

    def test_s_update_initiative_aggregate_weights(self):
        """Test initiative weight aggregation SUF."""
        result_key, result_value = s_update_initiative_aggregate_weights(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input={},
        )

        assert result_key == "initiatives"
        initiative = result_value["init1"]

        # Initiative weight should equal sum of support weights
        assert initiative["weight"] == 5000.0


class TestLifecycleSUFs:
    """Test initiative and support lifecycle SUFs."""

    def setup_method(self):
        """Set up test fixtures."""
        self.initial_state = generate_initial_state(
            num_users=5, total_supply=1000000, randomize=False
        )

        # Add initiative with high weight (above threshold)
        self.initial_state["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "High Weight Initiative",
                "description": "Test",
                "created_at": "2025-01-01T12:00:00",
                "weight": 2000.0,  # Above threshold
                "last_support_time": "2025-01-01T12:00:00",
                "last_support_epoch": 1,
            }
        }

        self.initial_state["accepted_initiatives"] = set()
        self.initial_state["expired_initiatives"] = set()

        self.params = {
            "acceptance_threshold": 1000.0,
            "inactivity_period": 10,
        }

    def test_s_process_accepted_initiatives(self):
        """Test initiative acceptance SUF."""
        result_key, result_value = s_process_accepted_initiatives(
            params=self.params,
            substep=1,
            state_history=[],
            previous_state=self.initial_state,
            policy_input={},
        )

        assert result_key == "accepted_initiatives"
        assert "init1" in result_value

    def test_s_process_expired_initiatives_inactivity(self):
        """Test initiative expiration due to inactivity."""
        # Create initiative with no support and old last_support_epoch
        state = self.initial_state.copy()
        state["current_epoch"] = 15
        state["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Inactive Initiative",
                "description": "Test",
                "created_at": "2025-01-01T12:00:00",
                "weight": 100.0,  # Below threshold
                "last_support_time": "2025-01-01T12:00:00",
                "last_support_epoch": 0,  # Very old
            }
        }
        state["locks"] = {}  # No active support

        result_key, result_value = s_process_expired_initiatives(
            params=self.params, substep=1, state_history=[], previous_state=state, policy_input={}
        )

        assert result_key == "expired_initiatives"
        assert "init1" in result_value


class TestTimeSUFs:
    """Test time-related SUFs."""

    def test_s_update_current_epoch(self):
        """Test epoch update SUF."""
        initial_state = {"current_epoch": 5}

        result_key, result_value = s_update_current_epoch(
            params={}, substep=1, state_history=[], previous_state=initial_state, policy_input={}
        )

        assert result_key == "current_epoch"
        assert result_value == 6

    def test_s_update_current_time(self):
        """Test time update SUF."""
        initial_time = datetime(2025, 1, 1, 12, 0, 0)
        initial_state = {"current_time": initial_time}

        result_key, result_value = s_update_current_time(
            params={}, substep=1, state_history=[], previous_state=initial_state, policy_input={}
        )

        assert result_key == "current_time"
        # The SUF returns a datetime object that should be later than the initial time
        if isinstance(result_value, str):
            result_datetime = datetime.fromisoformat(result_value.replace("Z", "+00:00"))
            assert result_datetime > initial_time
        else:
            assert result_value > initial_time  # Should advance by 1 day
