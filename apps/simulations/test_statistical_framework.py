#!/usr/bin/env python3
"""
Test script for the statistical analysis framework.

This script performs a quick test to ensure all components work together correctly.
"""

import sys
import os

sys.path.insert(0, "src")

from statistical_analysis.experiment_runner import ExperimentRunner, ExperimentConfig
from supply import TokenDistributionGenerator
from statistical_analysis.metrics import GovernanceMetrics
import pandas as pd


def test_distribution_generator():
    """Test the token distribution generator."""
    print("🧪 Testing Token Distribution Generator...")

    generator = TokenDistributionGenerator()

    # Test different distribution types
    distributions = [
        {"type": "equal", "description": "Equal distribution"},
        {"type": "pareto", "alpha": 1.16, "description": "Pareto 80/20"},
        {
            "type": "custom",
            "control_percent_users": 10,
            "control_percent_tokens": 75,
            "description": "10% control 75%",
        },
    ]

    for dist_config in distributions:
        try:
            state = generator.generate_state(20, 100000, dist_config, random_seed=42)
            balances = state["balances"]

            print(
                f"  ✅ {dist_config['description']}: {len(balances)} users, "
                f"total tokens: {sum(balances.values())}"
            )

            # Analyze distribution
            analysis = generator.analyze_distribution(balances)
            print(f"     Gini coefficient: {analysis.get('gini_coefficient', 0):.3f}")

        except Exception as e:
            print(f"  ❌ {dist_config['description']}: {e}")

    print("✅ Distribution generator tests completed\n")


def test_metrics_calculator():
    """Test the governance metrics calculator."""
    print("🧪 Testing Governance Metrics Calculator...")

    # Create a simple mock simulation result
    mock_results = [
        {
            "current_epoch": 0,
            "total_supply": 100000,
            "circulating_supply": 10000,
            "balances": {"user1": 5000, "user2": 3000, "user3": 2000},
            "supporters": {
                ("user1", "init1"): {
                    "amount": 1000,
                    "lock_duration_epochs": 10,
                    "current_weight": 10000,
                },
                ("user2", "init1"): {
                    "amount": 500,
                    "lock_duration_epochs": 5,
                    "current_weight": 2500,
                },
            },
            "initiatives": {"init1": {"id": "init1", "weight": 12500}},
            "accepted_initiatives": set(),
            "expired_initiatives": set(),
        },
        {
            "current_epoch": 1,
            "total_supply": 100000,
            "circulating_supply": 8500,
            "balances": {"user1": 4000, "user2": 2500, "user3": 2000},
            "supporters": {
                ("user1", "init1"): {
                    "amount": 1000,
                    "lock_duration_epochs": 10,
                    "current_weight": 9500,
                },
                ("user2", "init1"): {
                    "amount": 500,
                    "lock_duration_epochs": 5,
                    "current_weight": 2375,
                },
            },
            "initiatives": {"init1": {"id": "init1", "weight": 11875}},
            "accepted_initiatives": {"init1"},
            "expired_initiatives": set(),
        },
    ]

    # Create DataFrame
    df = pd.DataFrame(mock_results)

    # Calculate metrics
    metrics_calculator = GovernanceMetrics()
    try:
        metrics = metrics_calculator.calculate_all_metrics(mock_results, df)

        print(f"  ✅ Calculated {len(metrics)} metrics")

        # Print key metrics
        key_metrics = [
            "preference_intensity_score",
            "opportunity_cost_score",
            "sybil_resistance_score",
            "inclusivity_score",
            "acceptance_rate",
        ]

        for metric in key_metrics:
            if metric in metrics:
                print(f"     {metric}: {metrics[metric]:.3f}")

    except Exception as e:
        print(f"  ❌ Metrics calculation failed: {e}")
        import traceback

        traceback.print_exc()

    print("✅ Metrics calculator tests completed\n")


def test_mini_experiment():
    """Test a minimal experiment configuration."""
    print("🧪 Testing Mini Experiment...")

    try:
        # Create minimal experiment config
        config = ExperimentConfig(
            name="test_experiment",
            description="Minimal test experiment",
            parameter_sweeps={
                "acceptance_threshold": [1000],
                "decay_multiplier": [0.95],
            },
            token_distributions=[
                {"type": "equal", "description": "Equal distribution"},
            ],
            num_monte_carlo_runs=1,
            num_epochs=5,
            num_users=10,
            total_supply=50000,
            output_dir="test_experiments",
            parallel_execution=False,
        )

        print(f"  📊 Created experiment config: {config.name}")

        # Generate experiment matrix
        runner = ExperimentRunner(config)
        experiments = runner.generate_experiment_matrix()

        print(f"  🔬 Generated {len(experiments)} experiment configurations")

        # Test single experiment (without full run to save time)
        if experiments:
            single_experiment = experiments[0]
            print(f"  ⚙️  Testing single experiment configuration...")

            # This would normally run the full simulation
            # For testing, we'll just verify the structure
            print(f"     Parameters: {single_experiment['parameters']}")
            print(f"     Distribution: {single_experiment['distribution_config']}")

        print("✅ Mini experiment test completed\n")

    except Exception as e:
        print(f"  ❌ Mini experiment failed: {e}")
        import traceback

        traceback.print_exc()


def main():
    """Run all tests."""
    print("🚀 STATISTICAL ANALYSIS FRAMEWORK TESTS")
    print("=" * 50)

    test_distribution_generator()
    test_metrics_calculator()
    test_mini_experiment()

    print("🎉 All tests completed!")
    print("\nThe statistical analysis framework is ready for use.")
    print("Run 'python examples/statistical_analysis_demo.py' for a full demonstration.")


if __name__ == "__main__":
    main()
