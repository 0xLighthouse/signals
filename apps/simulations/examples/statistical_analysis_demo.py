#!/usr/bin/env python3
"""
Statistical Analysis Demo

This script demonstrates how to use the statistical analysis framework
to rigorously test governance system properties across different token distributions.

The demo showcases the four key governance attributes:
1. Capturing voter preference intensity
2. Opportunity cost as sufficient risk
3. Locking mechanisms improving sybil resistance
4. Empowering smaller voting blocks increases inclusivity
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from statistical_analysis.experiment_runner import ExperimentRunner, ExperimentConfig
from supply import create_distribution_test_suite
from statistical_analysis.metrics import GovernanceMetrics
import pandas as pd
import numpy as np


def create_quick_demo_experiment() -> ExperimentConfig:
    """Create a quick demo experiment for testing."""
    return ExperimentConfig(
        name="governance_demo",
        description="Quick demo of governance system analysis across token distributions",
        # Smaller parameter space for demo
        parameter_sweeps={
            "acceptance_threshold": [1000, 5000],
            "decay_multiplier": [0.90, 0.95],
            "prob_create_initiative": [0.08, 0.12],
            "prob_support_initiative": [0.20, 0.30],
            "max_support_tokens_fraction": [0.4, 0.7],
        },
        # Test key distribution types
        token_distributions=[
            {"type": "equal", "description": "Equal distribution"},
            {"type": "pareto", "alpha": 1.16, "description": "Pareto 80/20"},
            {
                "type": "custom",
                "control_percent_users": 10,
                "control_percent_tokens": 75,
                "description": "10% control 75%",
            },
        ],
        # Smaller scale for demo
        num_monte_carlo_runs=5,
        confidence_level=0.95,
        num_epochs=25,
        num_users=50,
        total_supply=500_000,
        # Demo output
        output_dir="demo_experiments",
        parallel_execution=False,  # Sequential for demo
    )


def analyze_governance_attributes(results_df: pd.DataFrame) -> None:
    """Analyze the four key governance attributes from experiment results."""
    print("\n" + "=" * 80)
    print("GOVERNANCE ATTRIBUTES ANALYSIS")
    print("=" * 80)

    # Group by distribution type for comparison
    distribution_groups = results_df.groupby("dist_description")

    print("\n1. VOTER PREFERENCE INTENSITY CAPTURE")
    print("-" * 50)
    print("Measures how well the system allows users to express varying preference levels")
    print("Key metrics: preference_intensity_score, support_amount_cv, lock_duration_cv")

    for dist_name, group in distribution_groups:
        if group["success"].all():
            intensity_scores = group["metric_preference_intensity_score"].dropna()
            amount_cv = group["metric_support_amount_cv"].dropna()
            duration_cv = group["metric_lock_duration_cv"].dropna()

            print(f"\n{dist_name}:")
            print(
                f"  Preference Intensity Score: {intensity_scores.mean():.3f} ± {intensity_scores.std():.3f}"
            )
            print(f"  Support Amount Variation: {amount_cv.mean():.3f} ± {amount_cv.std():.3f}")
            print(f"  Lock Duration Variation: {duration_cv.mean():.3f} ± {duration_cv.std():.3f}")

    print("\n2. OPPORTUNITY COST AS SUFFICIENT RISK")
    print("-" * 50)
    print("Measures whether token locking creates meaningful economic risk")
    print("Key metrics: opportunity_cost_score, avg_user_lock_ratio, avg_locked_token_ratio")

    for dist_name, group in distribution_groups:
        if group["success"].all():
            opp_cost_scores = group["metric_opportunity_cost_score"].dropna()
            user_lock_ratios = group["metric_avg_user_lock_ratio"].dropna()
            token_lock_ratios = group["metric_avg_locked_token_ratio"].dropna()

            print(f"\n{dist_name}:")
            print(
                f"  Opportunity Cost Score: {opp_cost_scores.mean():.3f} ± {opp_cost_scores.std():.3f}"
            )
            print(
                f"  Avg User Lock Ratio: {user_lock_ratios.mean():.3f} ± {user_lock_ratios.std():.3f}"
            )
            print(
                f"  Avg Token Lock Ratio: {token_lock_ratios.mean():.3f} ± {token_lock_ratios.std():.3f}"
            )

    print("\n3. SYBIL RESISTANCE THROUGH LOCKING")
    print("-" * 50)
    print("Measures how well locking mechanisms prevent sybil attacks")
    print("Key metrics: sybil_resistance_score, holdings_influence_correlation")

    for dist_name, group in distribution_groups:
        if group["success"].all():
            sybil_scores = group["metric_sybil_resistance_score"].dropna()
            correlations = group["metric_holdings_influence_correlation"].dropna()
            influence_gini = group["metric_influence_gini"].dropna()

            print(f"\n{dist_name}:")
            print(f"  Sybil Resistance Score: {sybil_scores.mean():.3f} ± {sybil_scores.std():.3f}")
            print(
                f"  Holdings-Influence Correlation: {correlations.mean():.3f} ± {correlations.std():.3f}"
            )
            print(
                f"  Influence Gini Coefficient: {influence_gini.mean():.3f} ± {influence_gini.std():.3f}"
            )

    print("\n4. EMPOWERING SMALLER VOTING BLOCKS")
    print("-" * 50)
    print("Measures how well the system enables smaller holders to have influence")
    print("Key metrics: inclusivity_score, small_holder_participation, small_holder_influence")

    for dist_name, group in distribution_groups:
        if group["success"].all():
            inclusivity_scores = group["metric_inclusivity_score"].dropna()
            participation = group["metric_small_holder_participation"].dropna()
            influence = group["metric_small_holder_influence"].dropna()

            print(f"\n{dist_name}:")
            print(
                f"  Inclusivity Score: {inclusivity_scores.mean():.3f} ± {inclusivity_scores.std():.3f}"
            )
            print(
                f"  Small Holder Participation: {participation.mean():.3f} ± {participation.std():.3f}"
            )
            print(f"  Small Holder Influence: {influence.mean():.3f} ± {influence.std():.3f}")


def compare_distributions(results_df: pd.DataFrame) -> None:
    """Compare governance performance across different token distributions."""
    print("\n" + "=" * 80)
    print("DISTRIBUTION COMPARISON ANALYSIS")
    print("=" * 80)

    # Key composite metrics for comparison
    key_metrics = [
        "metric_preference_intensity_score",
        "metric_opportunity_cost_score",
        "metric_sybil_resistance_score",
        "metric_inclusivity_score",
        "metric_acceptance_rate",
    ]

    distribution_groups = results_df.groupby("dist_description")

    print("\nComposite Governance Quality Scores:")
    print("(Higher scores generally indicate better governance properties)")
    print("-" * 70)

    summary_data = []

    for dist_name, group in distribution_groups:
        if group["success"].all():
            row_data = {"Distribution": dist_name}

            for metric in key_metrics:
                if metric in group.columns:
                    values = group[metric].dropna()
                    if len(values) > 0:
                        mean_val = values.mean()
                        std_val = values.std()
                        row_data[metric.replace("metric_", "").title()] = (
                            f"{mean_val:.3f} ± {std_val:.3f}"
                        )
                    else:
                        row_data[metric.replace("metric_", "").title()] = "N/A"
                else:
                    row_data[metric.replace("metric_", "").title()] = "N/A"

            summary_data.append(row_data)

    # Create summary table
    summary_df = pd.DataFrame(summary_data)
    print(summary_df.to_string(index=False))

    # Statistical significance tests
    print("\n\nStatistical Significance Tests:")
    print("-" * 40)

    distributions = list(distribution_groups.groups.keys())
    if len(distributions) >= 2:
        from statistical_analysis.metrics import StatisticalTests

        for metric in key_metrics:
            if metric in results_df.columns:
                print(f"\n{metric.replace('metric_', '').title()}:")

                for i in range(len(distributions)):
                    for j in range(i + 1, len(distributions)):
                        dist1_name = distributions[i]
                        dist2_name = distributions[j]

                        group1 = distribution_groups.get_group(dist1_name)
                        group2 = distribution_groups.get_group(dist2_name)

                        values1 = group1[metric].dropna().tolist()
                        values2 = group2[metric].dropna().tolist()

                        if len(values1) >= 2 and len(values2) >= 2:
                            test_result = StatisticalTests.compare_distributions(values1, values2)
                            significance = "***" if test_result["significant"] else ""

                            print(
                                f"  {dist1_name} vs {dist2_name}: "
                                f"p={test_result['p_value']:.4f} {significance}"
                            )


def main():
    """Run the statistical analysis demo."""
    print("🧪 GOVERNANCE SYSTEM STATISTICAL ANALYSIS DEMO")
    print("=" * 60)
    print("This demo tests governance system properties across different token distributions")
    print("to validate the four key attributes of the Signals governance system.")

    # Create and run experiment
    config = create_quick_demo_experiment()
    runner = ExperimentRunner(config)

    print(
        f"\n📊 Running experiment with {len(runner.generate_experiment_matrix())} configurations..."
    )
    results_df = runner.run_experiments()

    # Analyze results
    if not results_df.empty:
        print(f"\n✅ Experiment completed successfully!")
        print(f"📈 Collected {len(results_df)} data points")

        # Filter successful runs
        successful_runs = results_df[results_df["success"] == True]
        print(
            f"📊 Success rate: {len(successful_runs)}/{len(results_df)} ({len(successful_runs) / len(results_df):.1%})"
        )

        if len(successful_runs) > 0:
            # Analyze governance attributes
            analyze_governance_attributes(successful_runs)

            # Compare distributions
            compare_distributions(successful_runs)

            print("\n" + "=" * 80)
            print("CONCLUSIONS")
            print("=" * 80)
            print("This analysis demonstrates how the statistical framework can:")
            print("1. Quantify voter preference intensity capture across distributions")
            print("2. Measure opportunity cost effectiveness in preventing frivolous participation")
            print("3. Evaluate sybil resistance through economic commitment requirements")
            print("4. Assess inclusivity and empowerment of smaller voting blocks")
            print("\nThe framework enables rigorous, evidence-based evaluation of")
            print("governance system design choices across different token distributions.")

        else:
            print("❌ No successful runs to analyze. Check simulation parameters.")
    else:
        print("❌ Experiment failed to generate results.")


if __name__ == "__main__":
    main()
