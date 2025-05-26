#!/usr/bin/env python3
"""
Quick Visualization Demo

A minimal demo to generate results for testing the visualization framework.
"""

import sys
import os
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from statistical_analysis.experiment_runner import ExperimentRunner, ExperimentConfig
from statistical_analysis.visualization import GovernanceVisualizer
import pandas as pd


def create_quick_experiment() -> ExperimentConfig:
    """Create a minimal experiment for quick testing."""
    return ExperimentConfig(
        name="quick_visualization_test",
        description="Minimal experiment for visualization testing",
        # Very small parameter space
        parameter_sweeps={
            "acceptance_threshold": [1000, 5000],
            "decay_multiplier": [0.90, 0.95],
        },
        # Just 2 distributions for comparison
        token_distributions=[
            {"type": "equal", "description": "Equal distribution"},
            {"type": "pareto", "alpha": 1.16, "description": "Pareto 80/20"},
        ],
        # Minimal runs for speed
        num_monte_carlo_runs=3,
        num_epochs=10,
        num_users=20,
        total_supply=100_000,
        output_dir="quick_experiments",
        parallel_execution=False,  # Sequential for debugging
    )


def main():
    """Run quick experiment and create visualizations."""
    print("🚀 QUICK VISUALIZATION DEMO")
    print("=" * 40)

    # Create and run experiment
    config = create_quick_experiment()
    runner = ExperimentRunner(config)

    print(f"🧪 Running quick experiment: {config.name}")
    print(f"📊 Total configurations: {len(runner.generate_experiment_matrix())}")

    # Run the experiment
    results_df = runner.run_experiments()

    if results_df.empty:
        print("❌ No results generated.")
        return

    # Filter successful runs
    successful_runs = results_df[results_df["success"] == True]
    success_rate = len(successful_runs) / len(results_df)

    print(f"\n✅ Experiment completed!")
    print(f"📈 Success rate: {success_rate:.1%} ({len(successful_runs)}/{len(results_df)})")

    if len(successful_runs) == 0:
        print("❌ No successful runs to visualize.")
        return

    # Create visualizations
    print(f"\n🎨 Creating visualizations...")

    visualizer = GovernanceVisualizer(figsize=(10, 6), dpi=100)

    # Create plots directory
    plots_dir = "quick_plots"
    os.makedirs(plots_dir, exist_ok=True)

    # 1. Governance attributes comparison
    print("📊 Creating governance attributes plot...")
    fig1 = visualizer.plot_governance_attributes_comparison(
        successful_runs, save_path=f"{plots_dir}/governance_attributes.png"
    )

    # 2. Parameter sensitivity
    print("📈 Creating parameter sensitivity plot...")
    fig2 = visualizer.plot_parameter_sensitivity(
        successful_runs,
        target_metric="metric_preference_intensity_score",
        save_path=f"{plots_dir}/parameter_sensitivity.png",
    )

    # 3. Distribution comparison
    print("🎯 Creating distribution comparison...")
    fig3 = visualizer.plot_distribution_analysis(
        successful_runs, save_path=f"{plots_dir}/distribution_analysis.png"
    )

    # Show summary
    print(f"\n✅ Visualization demo completed!")
    print(f"📁 Plots saved to: {plots_dir}/")
    print(f"📊 Generated {len(successful_runs)} data points")

    # Print some basic statistics
    print(f"\n📈 Quick Results Summary:")
    for dist in successful_runs["dist_description"].unique():
        dist_data = successful_runs[successful_runs["dist_description"] == dist]
        if "metric_preference_intensity_score" in dist_data.columns:
            mean_score = dist_data["metric_preference_intensity_score"].mean()
            print(f"   {dist}: Preference Intensity = {mean_score:.3f}")


if __name__ == "__main__":
    main()
