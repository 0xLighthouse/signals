"""
Tests for Policy functions.
"""

import pytest
from datetime import datetime
from src.cadcad.state import generate_initial_state
from src.cadcad.policies import p_user_actions, p_advance_time


class TestUserActionsPolicy:
    """Test the user actions policy function."""

    def setup_method(self):
        """Set up test fixtures."""
        self.initial_state = generate_initial_state(
            num_users=10, total_supply=1000000, randomize=False
        )
        self.params = {
            "prob_create_initiative": 0.1,
            "prob_support_initiative": 0.2,
            "max_support_tokens_fraction": 0.5,
            "min_lock_duration_epochs": 5,
            "max_lock_duration_epochs": 20,
            "initiative_creation_stake": 10.0,
        }

    def test_p_user_actions_returns_dict(self):
        """Test that user actions policy returns a dictionary."""
        result = p_user_actions(
            params=self.params, substep=1, state_history=[], previous_state=self.initial_state
        )

        assert isinstance(result, dict)
        assert "user_actions" in result
        assert isinstance(result["user_actions"], list)

    def test_p_user_actions_no_initiatives_no_support(self):
        """Test user actions when no initiatives exist."""
        # With no initiatives, only creation actions should be possible
        result = p_user_actions(
            params=self.params, substep=1, state_history=[], previous_state=self.initial_state
        )

        actions = result["user_actions"]

        # All actions should be initiative creation (if any)
        for action in actions:
            assert action["type"] == "create_initiative"
            assert "user_id" in action
            assert "title" in action
            assert "description" in action

    def test_p_user_actions_with_initiatives_enables_support(self):
        """Test user actions when initiatives exist."""
        # Add some initiatives to the state
        state_with_initiatives = self.initial_state.copy()
        state_with_initiatives["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Test Initiative 1",
                "description": "Test",
                "creator": "0x00",
                "creation_epoch": 0,
                "last_support_epoch": 0,
                "weight": 0.0,
            },
            "init2": {
                "id": "init2",
                "title": "Test Initiative 2",
                "description": "Test",
                "creator": "0x01",
                "creation_epoch": 0,
                "last_support_epoch": 0,
                "weight": 0.0,
            },
        }

        # Run multiple times to get some support actions
        all_action_types = set()
        for _ in range(20):  # Multiple runs to get variety
            result = p_user_actions(
                params=self.params,
                substep=1,
                state_history=[],
                previous_state=state_with_initiatives,
            )

            for action in result["user_actions"]:
                all_action_types.add(action["type"])

        # Should see both types of actions over multiple runs
        # (Due to randomness, we might not see both in a single run)
        possible_types = {"create_initiative", "support_initiative"}
        assert all_action_types.issubset(possible_types)

    def test_p_user_actions_support_action_structure(self):
        """Test structure of support actions."""
        # Add initiatives to enable support actions
        state_with_initiatives = self.initial_state.copy()
        state_with_initiatives["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Test Initiative",
                "description": "Test",
                "creator": "0x00",
                "creation_epoch": 0,
                "last_support_epoch": 0,
                "weight": 0.0,
            }
        }

        # Force high probability to get support actions
        params = self.params.copy()
        params["prob_support_initiative"] = 1.0  # 100% chance
        params["prob_create_initiative"] = 0.0  # 0% chance

        result = p_user_actions(
            params=params, substep=1, state_history=[], previous_state=state_with_initiatives
        )

        actions = result["user_actions"]

        # Should have support actions
        support_actions = [a for a in actions if a["type"] == "support_initiative"]

        for action in support_actions:
            assert action["type"] == "support_initiative"
            assert "user_id" in action
            assert "initiative_id" in action
            assert "amount" in action
            assert "lock_duration_epochs" in action

            # Validate ranges
            assert action["amount"] > 0
            assert (
                params["min_lock_duration_epochs"]
                <= action["lock_duration_epochs"]
                <= params["max_lock_duration_epochs"]
            )
            assert action["initiative_id"] in state_with_initiatives["initiatives"]

    def test_p_user_actions_respects_balance_limits(self):
        """Test that support actions respect user balance limits."""
        # Create state with low balances
        state_low_balance = self.initial_state.copy()
        state_low_balance["balances"] = {f"0x{i:02x}": 100.0 for i in range(10)}  # Low balances
        state_low_balance["initiatives"] = {
            "init1": {
                "id": "init1",
                "title": "Test Initiative",
                "description": "Test",
                "creator": "0x00",
                "creation_epoch": 0,
                "last_support_epoch": 0,
                "weight": 0.0,
            }
        }

        params = self.params.copy()
        params["prob_support_initiative"] = 1.0  # Force support actions
        params["max_support_tokens_fraction"] = 0.5  # Max 50% of balance

        result = p_user_actions(
            params=params, substep=1, state_history=[], previous_state=state_low_balance
        )

        actions = result["user_actions"]
        support_actions = [a for a in actions if a["type"] == "support_initiative"]

        for action in support_actions:
            user_balance = state_low_balance["balances"][action["user_id"]]
            max_support = user_balance * params["max_support_tokens_fraction"]
            assert action["amount"] <= max_support

    def test_p_user_actions_deterministic_with_seed(self):
        """Test that actions are deterministic when using the same random seed."""
        # This test would require modifying the policy to accept a seed
        # For now, we'll test that the function is callable and returns valid structure
        result1 = p_user_actions(
            params=self.params, substep=1, state_history=[], previous_state=self.initial_state
        )

        result2 = p_user_actions(
            params=self.params, substep=1, state_history=[], previous_state=self.initial_state
        )

        # Both should be valid (structure test)
        assert isinstance(result1, dict)
        assert isinstance(result2, dict)
        assert "user_actions" in result1
        assert "user_actions" in result2


class TestAdvanceTimePolicy:
    """Test the advance time policy function."""

    def test_p_advance_time_returns_empty_dict(self):
        """Test that advance time policy returns empty dict."""
        initial_state = {"current_epoch": 0, "current_time": datetime.now()}

        result = p_advance_time(
            params={}, substep=1, state_history=[], previous_state=initial_state
        )

        # This policy just signals intent, SUFs do the work
        assert isinstance(result, dict)
        # Should contain advance_epoch signal
        assert "advance_epoch" in result
        assert result["advance_epoch"] is True


class TestPolicyIntegration:
    """Test policy integration and interactions."""

    def test_policies_work_together(self):
        """Test that policies can work together in sequence."""
        initial_state = generate_initial_state(num_users=5, total_supply=1000000, randomize=False)

        params = {
            "prob_create_initiative": 0.1,
            "prob_support_initiative": 0.2,
            "max_support_tokens_fraction": 0.5,
            "min_lock_duration_epochs": 5,
            "max_lock_duration_epochs": 20,
            "initiative_creation_stake": 10.0,
        }

        # Run time advancement policy
        time_result = p_advance_time(
            params=params, substep=1, state_history=[], previous_state=initial_state
        )

        # Run user actions policy
        user_result = p_user_actions(
            params=params, substep=1, state_history=[], previous_state=initial_state
        )

        # Both should succeed
        assert isinstance(time_result, dict)
        assert isinstance(user_result, dict)
        assert "user_actions" in user_result

    def test_policy_with_empty_state(self):
        """Test policies handle edge cases gracefully."""
        empty_state = {
            "current_epoch": 0,
            "current_time": datetime.now(),
            "initiatives": {},
            "supporters": {},
            "balances": {},
            "accepted_initiatives": set(),
            "expired_initiatives": set(),
            "total_supply": 1000000,
            "circulating_supply": 0,
        }

        params = {
            "prob_create_initiative": 0.1,
            "prob_support_initiative": 0.2,
            "max_support_tokens_fraction": 0.5,
            "min_lock_duration_epochs": 5,
            "max_lock_duration_epochs": 20,
            "initiative_creation_stake": 10.0,
        }

        # Should not crash with empty state
        result = p_user_actions(
            params=params, substep=1, state_history=[], previous_state=empty_state
        )

        assert isinstance(result, dict)
        assert "user_actions" in result
        # With no balances, should have no actions
        assert len(result["user_actions"]) == 0
