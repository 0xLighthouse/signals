#!/usr/bin/env python3
"""
Statistical Analysis Demo with Comprehensive Visualizations

This script demonstrates the complete statistical analysis framework including
comprehensive visualizations for governance system evaluation.
"""

import sys
import os
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from statistical_analysis.experiment_runner import ExperimentRunner, ExperimentConfig
from statistical_analysis.visualization import GovernanceVisualizer, plot_experiment_results
from statistical_analysis.metrics import GovernanceMetrics
import pandas as pd
import numpy as np


def create_demo_experiment() -> ExperimentConfig:
    """Create a demo experiment optimized for visualization."""
    return ExperimentConfig(
        name="governance_visualization_demo",
        description="Demo experiment for comprehensive governance visualization",
        # Focused parameter space for clear visualization
        parameter_sweeps={
            "acceptance_threshold": [1000, 3000, 5000],
            "decay_multiplier": [0.90, 0.95],
            "prob_create_initiative": [0.08, 0.12],
            "prob_support_initiative": [0.20, 0.30],
            "max_support_tokens_fraction": [0.4, 0.6],
        },
        # Diverse token distributions for comparison
        token_distributions=[
            {"type": "equal", "description": "Equal distribution"},
            {"type": "pareto", "alpha": 1.16, "description": "Pareto 80/20"},
            {"type": "pareto", "alpha": 0.96, "description": "Pareto 90/10"},
            {
                "type": "custom",
                "control_percent_users": 10,
                "control_percent_tokens": 75,
                "description": "10% control 75%",
            },
            {
                "type": "custom",
                "control_percent_users": 5,
                "control_percent_tokens": 50,
                "description": "5% control 50%",
            },
        ],
        # Sufficient runs for statistical significance
        num_monte_carlo_runs=8,
        confidence_level=0.95,
        num_epochs=30,
        num_users=75,
        total_supply=750_000,
        # Output configuration
        output_dir="demo_experiments",
        parallel_execution=True,
        max_workers=4,
    )


def run_experiment_and_visualize():
    """Run the experiment and create comprehensive visualizations."""

    print("🚀 GOVERNANCE SYSTEM ANALYSIS WITH VISUALIZATIONS")
    print("=" * 60)

    # Create and run experiment
    config = create_demo_experiment()
    runner = ExperimentRunner(config)

    print(f"🧪 Running experiment: {config.name}")
    print(f"📊 Total configurations: {len(runner.generate_experiment_matrix())}")

    # Run the experiment
    results_df = runner.run_experiments()

    if results_df.empty:
        print("❌ No results generated. Experiment failed.")
        return None

    # Filter successful runs
    successful_runs = results_df[results_df["success"] == True]
    success_rate = len(successful_runs) / len(results_df)

    print(f"\n✅ Experiment completed!")
    print(f"📈 Success rate: {success_rate:.1%} ({len(successful_runs)}/{len(results_df)})")

    if len(successful_runs) == 0:
        print("❌ No successful runs to visualize.")
        return None

    # Create visualizations
    print(f"\n🎨 Creating comprehensive visualizations...")

    # Create visualizer
    visualizer = GovernanceVisualizer(figsize=(12, 8), dpi=150)

    # Create output directory for plots
    plots_dir = "governance_analysis_plots"
    os.makedirs(plots_dir, exist_ok=True)

    # Generate all visualizations
    visualizer.create_comprehensive_report(successful_runs, plots_dir)

    # Also create some interactive plots for immediate viewing
    print(f"\n📊 Creating interactive plots...")

    # 1. Governance attributes comparison
    fig1 = visualizer.plot_governance_attributes_comparison(successful_runs)
    if fig1:
        plt.show()

    # 2. Distribution analysis (radar charts)
    fig2 = visualizer.plot_distribution_analysis(successful_runs)
    if fig2:
        plt.show()

    # 3. Parameter sensitivity for preference intensity
    fig3 = visualizer.plot_parameter_sensitivity(
        successful_runs, target_metric="metric_preference_intensity_score"
    )
    if fig3:
        plt.show()

    # 4. Statistical significance analysis
    fig4 = visualizer.plot_statistical_significance(
        successful_runs, metric="metric_inclusivity_score"
    )
    if fig4:
        plt.show()

    return successful_runs


def analyze_key_findings(results_df: pd.DataFrame):
    """Analyze and report key findings from the visualization."""

    print("\n" + "=" * 80)
    print("KEY FINDINGS FROM VISUALIZATION ANALYSIS")
    print("=" * 80)

    # Group by distribution
    dist_groups = results_df.groupby("dist_description")

    print("\n1. GOVERNANCE ATTRIBUTE PERFORMANCE BY DISTRIBUTION")
    print("-" * 60)

    key_metrics = [
        ("Preference Intensity", "metric_preference_intensity_score"),
        ("Opportunity Cost", "metric_opportunity_cost_score"),
        ("Sybil Resistance", "metric_sybil_resistance_score"),
        ("Inclusivity", "metric_inclusivity_score"),
    ]

    for attr_name, metric_col in key_metrics:
        if metric_col in results_df.columns:
            print(f"\n{attr_name}:")

            # Find best and worst performing distributions
            dist_means = dist_groups[metric_col].mean().sort_values(ascending=False)

            print(f"  🥇 Best: {dist_means.index[0]} ({dist_means.iloc[0]:.3f})")
            if len(dist_means) > 1:
                print(f"  🥉 Worst: {dist_means.index[-1]} ({dist_means.iloc[-1]:.3f})")

            # Calculate improvement potential
            if len(dist_means) > 1:
                improvement = (dist_means.iloc[0] - dist_means.iloc[-1]) / dist_means.iloc[-1] * 100
                print(f"  📈 Improvement potential: {improvement:.1f}%")

    print("\n2. PARAMETER SENSITIVITY INSIGHTS")
    print("-" * 40)

    # Analyze parameter impact on key metrics
    param_cols = [col for col in results_df.columns if col.startswith("param_")]

    for metric_name, metric_col in key_metrics:
        if metric_col in results_df.columns:
            print(f"\n{metric_name} sensitivity:")

            for param_col in param_cols:
                # Calculate correlation between parameter and metric
                correlation = results_df[param_col].corr(results_df[metric_col])
                if abs(correlation) > 0.1:  # Only show meaningful correlations
                    direction = "increases" if correlation > 0 else "decreases"
                    param_name = param_col.replace("param_", "").replace("_", " ").title()
                    print(f"  • {param_name}: {direction} score (r={correlation:.2f})")

    print("\n3. DISTRIBUTION INEQUALITY IMPACT")
    print("-" * 40)

    # Analyze how token inequality affects governance
    inequality_order = [
        "Equal distribution",
        "5% control 50%",
        "Pareto 80/20",
        "10% control 75%",
        "Pareto 90/10",
    ]

    available_dists = [d for d in inequality_order if d in results_df["dist_description"].values]

    if len(available_dists) >= 2:
        print("Token inequality impact on governance quality:")

        for metric_name, metric_col in key_metrics:
            if metric_col in results_df.columns:
                values_by_dist = []
                for dist in available_dists:
                    dist_data = results_df[results_df["dist_description"] == dist]
                    if not dist_data.empty:
                        mean_val = dist_data[metric_col].mean()
                        values_by_dist.append(mean_val)

                if len(values_by_dist) >= 2:
                    # Calculate trend
                    trend_slope = np.polyfit(range(len(values_by_dist)), values_by_dist, 1)[0]
                    trend_direction = "improves" if trend_slope > 0 else "degrades"
                    print(
                        f"  • {metric_name}: {trend_direction} with inequality (slope={trend_slope:.3f})"
                    )

    print("\n4. STATISTICAL SIGNIFICANCE SUMMARY")
    print("-" * 40)

    from statistical_analysis.metrics import StatisticalTests

    distributions = results_df["dist_description"].unique()

    if len(distributions) >= 2:
        print("Significant differences found between distributions:")

        for metric_name, metric_col in key_metrics:
            if metric_col in results_df.columns:
                significant_pairs = []

                for i, dist1 in enumerate(distributions):
                    for j, dist2 in enumerate(distributions[i + 1 :], i + 1):
                        data1 = (
                            results_df[results_df["dist_description"] == dist1][metric_col]
                            .dropna()
                            .tolist()
                        )
                        data2 = (
                            results_df[results_df["dist_description"] == dist2][metric_col]
                            .dropna()
                            .tolist()
                        )

                        if len(data1) >= 2 and len(data2) >= 2:
                            test_result = StatisticalTests.compare_distributions(data1, data2)
                            if test_result["significant"]:
                                effect_size = StatisticalTests.effect_size_cohens_d(data1, data2)
                                significant_pairs.append(
                                    (dist1, dist2, test_result["p_value"], effect_size)
                                )

                if significant_pairs:
                    print(f"\n  {metric_name}:")
                    for dist1, dist2, p_val, effect in significant_pairs:
                        effect_desc = (
                            "large"
                            if abs(effect) > 0.8
                            else "medium"
                            if abs(effect) > 0.5
                            else "small"
                        )
                        print(
                            f"    • {dist1} vs {dist2}: p={p_val:.3f}, effect={effect:.2f} ({effect_desc})"
                        )


def main():
    """Run the complete analysis with visualizations."""

    # Check if matplotlib backend supports display
    try:
        import matplotlib

        if matplotlib.get_backend() == "Agg":
            print(
                "⚠️  Note: Running in non-interactive mode. Plots will be saved but not displayed."
            )
    except:
        pass

    # Run experiment and create visualizations
    results_df = run_experiment_and_visualize()

    if results_df is not None:
        # Analyze findings
        analyze_key_findings(results_df)

        print("\n" + "=" * 80)
        print("VISUALIZATION SUMMARY")
        print("=" * 80)
        print("📁 All plots have been saved to: governance_analysis_plots/")
        print("📊 Generated visualizations include:")
        print("   • Governance attributes comparison (box plots)")
        print("   • Metric correlation matrix (heatmap)")
        print("   • Parameter sensitivity analysis (line plots)")
        print("   • Distribution performance profiles (radar charts)")
        print("   • Statistical significance tests (heatmaps)")
        print("\n🎯 Use these visualizations to:")
        print("   • Compare governance quality across token distributions")
        print("   • Identify optimal parameter configurations")
        print("   • Understand trade-offs between governance attributes")
        print("   • Validate statistical significance of findings")

        print(f"\n✅ Analysis complete! Check the plots directory for detailed visualizations.")

    else:
        print("❌ Analysis failed. Please check the experiment configuration.")


if __name__ == "__main__":
    main()
