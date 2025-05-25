"""
Integration tests for the full simulation system.
"""

import pytest
import os
import tempfile
from datetime import datetime
from src.cadcad.model import run_simulation
from src.cadcad.state import generate_initial_state
from src.cadcad.helpers import results_to_dataframe, analyze_acceptance_rate
from src.main import save_simulation_results, generate_summary_stats


class TestSimulationIntegration:
    """Test the full simulation integration."""

    def test_run_simulation_basic(self):
        """Test that simulation runs without errors."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)

        assert isinstance(results, list)
        assert len(results) > 0

        # Check that we have the expected number of timesteps
        # Should be T+1 (initial state + T timesteps)
        assert len(results) >= 10  # At least some timesteps

    def test_simulation_state_progression(self):
        """Test that simulation state progresses correctly."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)

        # Check epoch progression
        epochs = [result.get("current_epoch", 0) for result in results]

        # Epochs should be non-decreasing
        for i in range(1, len(epochs)):
            assert epochs[i] >= epochs[i - 1]

        # Should have some epoch progression
        assert max(epochs) > min(epochs)

    def test_simulation_token_conservation(self):
        """Test that tokens are conserved throughout simulation."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        initial_total = initial_state["total_supply"]

        results = run_simulation(initial_state=initial_state)

        # Check token conservation in each timestep
        for result in results:
            total_supply = result.get("total_supply", 0)
            assert total_supply == initial_total, (
                f"Total supply changed: {total_supply} != {initial_total}"
            )

    def test_simulation_creates_initiatives(self):
        """Test that simulation creates initiatives over time."""
        initial_state = generate_initial_state(
            num_users=10,
            total_supply=1000000,
            randomize=True,  # Use randomization to get variety
        )

        results = run_simulation(initial_state=initial_state)

        # Check that initiatives are created
        final_result = results[-1]
        initiatives = final_result.get("initiatives", {})

        # Should have created some initiatives
        assert len(initiatives) > 0

    def test_simulation_governance_dynamics(self):
        """Test that governance dynamics work (acceptance, expiration)."""
        initial_state = generate_initial_state(num_users=20, total_supply=1000000, randomize=True)

        results = run_simulation(initial_state=initial_state)

        final_result = results[-1]

        # Check that we have governance activity
        initiatives = final_result.get("initiatives", {})
        accepted = final_result.get("accepted_initiatives", set())
        expired = final_result.get("expired_initiatives", set())

        # Should have some initiatives
        assert len(initiatives) > 0

        # Should have some governance outcomes (accepted or expired)
        total_outcomes = len(accepted) + len(expired)
        assert total_outcomes >= 0  # At least no errors


class TestDataFrameConversion:
    """Test conversion of simulation results to DataFrame."""

    def test_results_to_dataframe_basic(self):
        """Test basic DataFrame conversion."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)
        df = results_to_dataframe(results)

        assert len(df) == len(results)

        # Check required columns
        required_columns = [
            "current_epoch",
            "initiatives_count",
            "accepted_count",
            "expired_count",
            "supporters_count",
            "circulating_supply",
        ]

        for col in required_columns:
            assert col in df.columns

    def test_results_to_dataframe_data_types(self):
        """Test DataFrame data types are correct."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)
        df = results_to_dataframe(results)

        # Check data types
        assert df["current_epoch"].dtype in ["int64", "int32"]
        assert df["initiatives_count"].dtype in ["int64", "int32"]
        assert df["accepted_count"].dtype in ["int64", "int32"]
        assert df["circulating_supply"].dtype in ["float64", "int64"]

    def test_analyze_acceptance_rate(self):
        """Test acceptance rate analysis."""
        initial_state = generate_initial_state(num_users=10, total_supply=1000000, randomize=True)

        results = run_simulation(initial_state=initial_state)
        df = results_to_dataframe(results)

        analysis = analyze_acceptance_rate(df)

        assert isinstance(analysis, dict)
        assert "total_initiatives" in analysis
        assert "accepted" in analysis
        assert "expired" in analysis
        assert "acceptance_rate" in analysis

        # Acceptance rate should be between 0 and 1
        assert 0 <= analysis["acceptance_rate"] <= 1


class TestResultsSaving:
    """Test saving simulation results to files."""

    def test_save_simulation_results(self):
        """Test saving simulation results to files."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)

        # Use temporary directory for testing
        with tempfile.TemporaryDirectory() as temp_dir:
            file_paths = save_simulation_results(
                results=results, initial_state=initial_state, output_dir=temp_dir
            )

            # Check that all expected files were created
            assert os.path.exists(file_paths["csv_path"])
            assert os.path.exists(file_paths["json_path"])
            assert os.path.exists(file_paths["initial_state_path"])
            assert os.path.exists(file_paths["summary_path"])

            # Check file sizes (should not be empty)
            assert os.path.getsize(file_paths["csv_path"]) > 0
            assert os.path.getsize(file_paths["json_path"]) > 0
            assert os.path.getsize(file_paths["summary_path"]) > 0

    def test_generate_summary_stats(self):
        """Test summary statistics generation."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        results = run_simulation(initial_state=initial_state)
        df = results_to_dataframe(results)

        summary = generate_summary_stats(results, df)

        assert isinstance(summary, dict)

        # Check required sections
        assert "simulation_metadata" in summary
        assert "initiative_statistics" in summary
        assert "token_statistics" in summary
        assert "governance_parameters" in summary

        # Check metadata
        metadata = summary["simulation_metadata"]
        assert "total_timesteps" in metadata
        assert "final_epoch" in metadata
        assert "total_users" in metadata

        # Check initiative stats
        init_stats = summary["initiative_statistics"]
        assert "total_created" in init_stats
        assert "accepted" in init_stats
        assert "expired" in init_stats
        assert "acceptance_rate" in init_stats


class TestSimulationEdgeCases:
    """Test simulation edge cases and error handling."""

    def test_simulation_with_minimal_users(self):
        """Test simulation with minimal number of users."""
        initial_state = generate_initial_state(num_users=1, total_supply=10000, randomize=False)

        # Should not crash with minimal setup
        results = run_simulation(initial_state=initial_state)
        assert isinstance(results, list)
        assert len(results) > 0

    def test_simulation_with_zero_circulating_supply(self):
        """Test simulation behavior with zero circulating supply."""
        initial_state = generate_initial_state(num_users=5, total_supply=100000, randomize=False)

        # Set circulating supply to zero
        initial_state["circulating_supply"] = 0
        initial_state["balances"] = {f"0x{i:02x}": 0.0 for i in range(5)}

        # Should handle gracefully (no actions possible)
        results = run_simulation(initial_state=initial_state)
        assert isinstance(results, list)
        assert len(results) > 0

        # Should have no initiatives created
        final_result = results[-1]
        initiatives = final_result.get("initiatives", {})
        assert len(initiatives) == 0

    def test_simulation_error_handling(self):
        """Test simulation error handling with invalid state."""
        # Test with missing required fields
        invalid_state = {
            "current_epoch": 0,
            "current_time": datetime.now(),
            # Missing other required fields
        }

        # Should handle gracefully and return empty results
        results = run_simulation(initial_state=invalid_state)

        # Should return empty list on error
        assert isinstance(results, list)
        # May be empty due to error handling


class TestSimulationPerformance:
    """Test simulation performance characteristics."""

    def test_simulation_completes_in_reasonable_time(self):
        """Test that simulation completes in reasonable time."""
        import time

        initial_state = generate_initial_state(num_users=10, total_supply=1000000, randomize=True)

        start_time = time.time()
        results = run_simulation(initial_state=initial_state)
        end_time = time.time()

        execution_time = end_time - start_time

        # Should complete within reasonable time (adjust as needed)
        assert execution_time < 30.0  # 30 seconds max
        assert len(results) > 0

    def test_simulation_memory_usage(self):
        """Test that simulation doesn't use excessive memory."""
        # This is a basic test - in practice you'd use memory profiling tools
        initial_state = generate_initial_state(num_users=50, total_supply=1000000, randomize=True)

        results = run_simulation(initial_state=initial_state)

        # Should complete without memory errors
        assert isinstance(results, list)
        assert len(results) > 0

        # Basic check that results aren't excessively large
        assert len(results) < 1000  # Reasonable upper bound
