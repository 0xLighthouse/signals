"""
Tests for the State class and core data structures.
"""

import pytest
from datetime import datetime, timedelta
from src.cadcad.state import State, Initiative, Support, generate_initial_state


class TestInitiative:
    """Test the Initiative dataclass."""

    def test_initiative_creation(self):
        """Test basic initiative creation."""
        initiative = Initiative(
            id="test-id",
            title="Test Initiative",
            description="A test initiative",
            created_at=datetime.now(),
        )

        assert initiative.id == "test-id"
        assert initiative.title == "Test Initiative"
        assert initiative.description == "A test initiative"
        assert initiative.weight == 0.0
        assert initiative.last_support_epoch == 0

    def test_initiative_weight_update(self):
        """Test initiative weight updates."""
        initiative = Initiative(
            id="test-id", title="Test", description="Test", created_at=datetime.now()
        )

        # Weight should be mutable
        initiative.weight = 200.0
        assert initiative.weight == 200.0


class TestSupport:
    """Test the Support dataclass."""

    def test_support_creation(self):
        """Test basic support creation."""
        support = Support(
            user_id="user1",
            initiative_id="init1",
            amount=1000.0,
            lock_duration_epochs=10,
            start_epoch=1,
        )

        assert support.user_id == "user1"
        assert support.initiative_id == "init1"
        assert support.amount == 1000.0
        assert support.lock_duration_epochs == 10
        assert support.start_epoch == 1
        # Check calculated fields
        assert support.initial_weight == 1000.0 * 10  # amount * lock_duration
        assert support.current_weight == support.initial_weight
        assert support.expiry_epoch == 1 + 10  # start_epoch + lock_duration

    def test_support_decay(self):
        """Test support decay mechanism."""
        support = Support(
            user_id="user1",
            initiative_id="init1",
            amount=1000.0,
            lock_duration_epochs=10,
            start_epoch=1,
        )

        original_weight = support.current_weight
        support.decay(0.95, 2)  # 95% decay at epoch 2

        assert support.current_weight < original_weight
        assert support.current_weight == original_weight * 0.95

    def test_support_expiry_logic(self):
        """Test support expiry logic."""
        support = Support(
            user_id="user1",
            initiative_id="init1",
            amount=1000.0,
            lock_duration_epochs=10,
            start_epoch=1,
        )

        # Should be active before expiry (epoch < expiry_epoch)
        assert 5 < support.expiry_epoch  # epoch 5 is before expiry
        assert 10 < support.expiry_epoch  # epoch 10 is before expiry

        # Should not be active after expiry (epoch >= expiry_epoch)
        assert 11 >= support.expiry_epoch  # epoch 11 is at or after expiry
        assert 15 >= support.expiry_epoch  # epoch 15 is after expiry


class TestState:
    """Test the State class."""

    def test_state_creation(self):
        """Test basic state creation."""
        state = State(
            current_epoch=0,
            current_time=datetime.now(),
            total_supply=1000000,
            circulating_supply=100000,
        )

        assert state.current_epoch == 0
        assert state.total_supply == 1000000
        assert state.circulating_supply == 100000
        assert len(state.initiatives) == 0
        assert len(state.supporters) == 0

    def test_add_initiative(self):
        """Test adding initiatives to state."""
        state = State(
            current_epoch=0,
            current_time=datetime.now(),
            total_supply=1000000,
            circulating_supply=100000,
        )

        initiative = Initiative(
            id="test-id", title="Test Initiative", description="Test", created_at=datetime.now()
        )

        state.initiatives["test-id"] = initiative
        assert len(state.initiatives) == 1
        assert state.initiatives["test-id"].title == "Test Initiative"

    def test_add_support(self):
        """Test adding support to state."""
        state = State(
            current_epoch=1,
            current_time=datetime.now(),
            total_supply=1000000,
            circulating_supply=100000,
        )

        support = Support(
            user_id="user1",
            initiative_id="init1",
            amount=1000.0,
            lock_duration_epochs=10,
            start_epoch=1,
        )

        state.supporters[("user1", "init1")] = support
        assert len(state.supporters) == 1
        assert state.supporters[("user1", "init1")].amount == 1000.0

    def test_update_initiative_weights(self):
        """Test initiative weight calculation."""
        state = State(
            current_epoch=1,
            current_time=datetime.now(),
            total_supply=1000000,
            circulating_supply=100000,
        )

        # Add initiative
        initiative = Initiative(
            id="init1", title="Test Initiative", description="Test", created_at=datetime.now()
        )
        state.initiatives["init1"] = initiative

        # Add support
        support = Support(
            user_id="user1",
            initiative_id="init1",
            amount=1000.0,
            lock_duration_epochs=10,
            start_epoch=1,
        )
        state.supporters[("user1", "init1")] = support

        # Update weights
        state.update_initiative_weights()

        # Initiative weight should equal sum of support weights
        expected_weight = 1000.0 * 10  # amount * lock_duration_epochs
        assert state.initiatives["init1"].weight == expected_weight

    def test_state_dict_conversion(self):
        """Test state conversion to dictionary."""
        state = State(
            current_epoch=0,
            current_time=datetime.now(),
            total_supply=1000000,
            circulating_supply=100000,
        )

        state_dict = state.__dict__()

        assert isinstance(state_dict, dict)
        assert state_dict["current_epoch"] == 0
        assert state_dict["total_supply"] == 1000000
        assert "initiatives" in state_dict
        assert "supporters" in state_dict


class TestGenerateInitialState:
    """Test the generate_initial_state function."""

    def test_generate_initial_state_basic(self):
        """Test basic initial state generation."""
        initial_state = generate_initial_state(
            num_users=10,
            total_supply=1000000,
            circulating_supply=1000000,  # Set circulating supply to match total
            randomize=False,
        )

        assert isinstance(initial_state, dict)
        assert initial_state["total_supply"] == 1000000
        assert initial_state["current_epoch"] == 0
        assert len(initial_state["balances"]) == 10

        # Check that balances sum to total supply (all tokens are distributed)
        total_user_balance = sum(initial_state["balances"].values())
        assert total_user_balance == initial_state["total_supply"]

    def test_generate_initial_state_randomized(self):
        """Test randomized initial state generation."""
        initial_state1 = generate_initial_state(num_users=10, total_supply=1000000, randomize=True)

        initial_state2 = generate_initial_state(num_users=10, total_supply=1000000, randomize=True)

        # Randomized states should be different
        assert initial_state1["balances"] != initial_state2["balances"]

    def test_generate_initial_state_constraints(self):
        """Test initial state generation constraints."""
        initial_state = generate_initial_state(num_users=5, total_supply=1000000, randomize=True)

        # All balances should be positive
        for balance in initial_state["balances"].values():
            assert balance > 0

        # Circulating supply should be reasonable fraction of total
        assert 0.05 <= initial_state["circulating_supply"] / initial_state["total_supply"] <= 0.2

        # Should have empty collections initially
        assert len(initial_state["initiatives"]) == 0
        assert len(initial_state["supporters"]) == 0
        assert len(initial_state["accepted_initiatives"]) == 0
        assert len(initial_state["expired_initiatives"]) == 0
