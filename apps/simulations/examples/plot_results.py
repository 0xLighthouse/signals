#!/usr/bin/env python3
"""
Plot Results from Statistical Analysis

Simple script to create visualizations from the experiment results.
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import os

# Set style
plt.style.use("default")
sns.set_palette("husl")


def load_latest_results():
    """Load the latest experiment results."""
    # Find the latest CSV file
    csv_files = [f for f in os.listdir("quick_experiments") if f.endswith(".csv")]
    if not csv_files:
        print("No CSV files found in quick_experiments/")
        return None

    latest_csv = max(csv_files, key=lambda x: os.path.getctime(f"quick_experiments/{x}"))
    print(f"Loading: {latest_csv}")

    df = pd.read_csv(f"quick_experiments/{latest_csv}")
    return df


def create_governance_attributes_plot(df):
    """Create a plot comparing the four governance attributes."""
    # Filter successful runs
    df_success = df[df["success"] == True].copy()

    # Create the plot
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle("Governance System Analysis: Four Key Attributes", fontsize=16, fontweight="bold")

    # 1. Preference Intensity Score
    ax1 = axes[0, 0]
    sns.boxplot(
        data=df_success, x="dist_description", y="metric_preference_intensity_score", ax=ax1
    )
    ax1.set_title("Voter Preference Intensity")
    ax1.set_xlabel("Token Distribution")
    ax1.set_ylabel("Preference Intensity Score")
    ax1.tick_params(axis="x", rotation=45)

    # 2. Opportunity Cost Score
    ax2 = axes[0, 1]
    sns.boxplot(data=df_success, x="dist_description", y="metric_opportunity_cost_score", ax=ax2)
    ax2.set_title("Opportunity Cost as Risk")
    ax2.set_xlabel("Token Distribution")
    ax2.set_ylabel("Opportunity Cost Score")
    ax2.tick_params(axis="x", rotation=45)

    # 3. Sybil Resistance Score
    ax3 = axes[1, 0]
    sns.boxplot(data=df_success, x="dist_description", y="metric_sybil_resistance_score", ax=ax3)
    ax3.set_title("Sybil Resistance")
    ax3.set_xlabel("Token Distribution")
    ax3.set_ylabel("Sybil Resistance Score")
    ax3.tick_params(axis="x", rotation=45)

    # 4. Inclusivity Score
    ax4 = axes[1, 1]
    sns.boxplot(data=df_success, x="dist_description", y="metric_inclusivity_score", ax=ax4)
    ax4.set_title("Small Holder Inclusivity")
    ax4.set_xlabel("Token Distribution")
    ax4.set_ylabel("Inclusivity Score")
    ax4.tick_params(axis="x", rotation=45)

    plt.tight_layout()
    return fig


def create_parameter_sensitivity_plot(df):
    """Create a plot showing parameter sensitivity."""
    df_success = df[df["success"] == True].copy()

    fig, axes = plt.subplots(1, 2, figsize=(15, 6))
    fig.suptitle("Parameter Sensitivity Analysis", fontsize=16, fontweight="bold")

    # Acceptance Threshold vs Acceptance Rate
    ax1 = axes[0]
    for dist in df_success["dist_description"].unique():
        dist_data = df_success[df_success["dist_description"] == dist]
        ax1.scatter(
            dist_data["param_acceptance_threshold"],
            dist_data["metric_acceptance_rate"],
            label=dist,
            alpha=0.7,
            s=60,
        )

    ax1.set_xlabel("Acceptance Threshold")
    ax1.set_ylabel("Acceptance Rate")
    ax1.set_title("Acceptance Threshold vs Success Rate")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Decay Multiplier vs Preference Intensity
    ax2 = axes[1]
    for dist in df_success["dist_description"].unique():
        dist_data = df_success[df_success["dist_description"] == dist]
        ax2.scatter(
            dist_data["param_decay_multiplier"],
            dist_data["metric_preference_intensity_score"],
            label=dist,
            alpha=0.7,
            s=60,
        )

    ax2.set_xlabel("Decay Multiplier")
    ax2.set_ylabel("Preference Intensity Score")
    ax2.set_title("Decay Rate vs Preference Intensity")
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def create_distribution_comparison_plot(df):
    """Create a plot comparing token distributions."""
    df_success = df[df["success"] == True].copy()

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle("Token Distribution Impact Analysis", fontsize=16, fontweight="bold")

    # 1. Acceptance Rate by Distribution
    ax1 = axes[0, 0]
    dist_summary = (
        df_success.groupby("dist_description")["metric_acceptance_rate"]
        .agg(["mean", "std"])
        .reset_index()
    )
    bars = ax1.bar(
        dist_summary["dist_description"],
        dist_summary["mean"],
        yerr=dist_summary["std"],
        capsize=5,
        alpha=0.7,
    )
    ax1.set_title("Average Acceptance Rate by Distribution")
    ax1.set_ylabel("Acceptance Rate")
    ax1.tick_params(axis="x", rotation=45)

    # Add value labels on bars
    for bar, mean_val in zip(bars, dist_summary["mean"]):
        ax1.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.01,
            f"{mean_val:.3f}",
            ha="center",
            va="bottom",
        )

    # 2. Opportunity Cost by Distribution
    ax2 = axes[0, 1]
    sns.violinplot(data=df_success, x="dist_description", y="metric_opportunity_cost_score", ax=ax2)
    ax2.set_title("Opportunity Cost Distribution")
    ax2.set_ylabel("Opportunity Cost Score")
    ax2.tick_params(axis="x", rotation=45)

    # 3. Inclusivity vs Sybil Resistance
    ax3 = axes[1, 0]
    for dist in df_success["dist_description"].unique():
        dist_data = df_success[df_success["dist_description"] == dist]
        ax3.scatter(
            dist_data["metric_sybil_resistance_score"],
            dist_data["metric_inclusivity_score"],
            label=dist,
            alpha=0.7,
            s=60,
        )

    ax3.set_xlabel("Sybil Resistance Score")
    ax3.set_ylabel("Inclusivity Score")
    ax3.set_title("Sybil Resistance vs Inclusivity Trade-off")
    ax3.legend()
    ax3.grid(True, alpha=0.3)

    # 4. Total Initiatives vs Accepted
    ax4 = axes[1, 1]
    for dist in df_success["dist_description"].unique():
        dist_data = df_success[df_success["dist_description"] == dist]
        ax4.scatter(
            dist_data["metric_total_initiatives"],
            dist_data["metric_accepted_initiatives"],
            label=dist,
            alpha=0.7,
            s=60,
        )

    # Add diagonal line for reference
    max_initiatives = df_success["metric_total_initiatives"].max()
    ax4.plot(
        [0, max_initiatives], [0, max_initiatives], "k--", alpha=0.5, label="Perfect Acceptance"
    )

    ax4.set_xlabel("Total Initiatives")
    ax4.set_ylabel("Accepted Initiatives")
    ax4.set_title("Initiative Creation vs Acceptance")
    ax4.legend()
    ax4.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def print_summary_statistics(df):
    """Print summary statistics."""
    df_success = df[df["success"] == True].copy()

    print("\n" + "=" * 60)
    print("GOVERNANCE SYSTEM ANALYSIS SUMMARY")
    print("=" * 60)

    print(f"\n📊 Experiment Overview:")
    print(f"   Total experiments: {len(df)}")
    print(f"   Successful runs: {len(df_success)} ({len(df_success) / len(df) * 100:.1f}%)")
    print(f"   Distributions tested: {df_success['dist_description'].nunique()}")
    print(
        f"   Parameter combinations: {len(df_success.groupby(['param_acceptance_threshold', 'param_decay_multiplier']))}"
    )

    print(f"\n🎯 Key Findings by Distribution:")
    for dist in df_success["dist_description"].unique():
        dist_data = df_success[df_success["dist_description"] == dist]
        print(f"\n   {dist}:")
        print(
            f"      Acceptance Rate: {dist_data['metric_acceptance_rate'].mean():.3f} ± {dist_data['metric_acceptance_rate'].std():.3f}"
        )
        print(
            f"      Preference Intensity: {dist_data['metric_preference_intensity_score'].mean():.3f} ± {dist_data['metric_preference_intensity_score'].std():.3f}"
        )
        print(
            f"      Opportunity Cost: {dist_data['metric_opportunity_cost_score'].mean():.3f} ± {dist_data['metric_opportunity_cost_score'].std():.3f}"
        )
        print(
            f"      Sybil Resistance: {dist_data['metric_sybil_resistance_score'].mean():.3f} ± {dist_data['metric_sybil_resistance_score'].std():.3f}"
        )
        print(
            f"      Inclusivity: {dist_data['metric_inclusivity_score'].mean():.3f} ± {dist_data['metric_inclusivity_score'].std():.3f}"
        )

    print(f"\n📈 Parameter Impact:")
    print(
        f"   Acceptance Threshold range: {df_success['param_acceptance_threshold'].min()} - {df_success['param_acceptance_threshold'].max()}"
    )
    print(
        f"   Decay Multiplier range: {df_success['param_decay_multiplier'].min()} - {df_success['param_decay_multiplier'].max()}"
    )

    # Correlation analysis
    print(f"\n🔗 Key Correlations:")
    corr_threshold_acceptance = df_success["param_acceptance_threshold"].corr(
        df_success["metric_acceptance_rate"]
    )
    corr_decay_intensity = df_success["param_decay_multiplier"].corr(
        df_success["metric_preference_intensity_score"]
    )
    print(f"   Acceptance Threshold ↔ Acceptance Rate: {corr_threshold_acceptance:.3f}")
    print(f"   Decay Multiplier ↔ Preference Intensity: {corr_decay_intensity:.3f}")


def main():
    """Main function to create all plots."""
    print("🎨 GOVERNANCE ANALYSIS VISUALIZATION")
    print("=" * 40)

    # Load data
    df = load_latest_results()
    if df is None:
        return

    print(f"📊 Loaded {len(df)} experiment results")

    # Create output directory
    os.makedirs("plots", exist_ok=True)

    # Print summary statistics
    print_summary_statistics(df)

    # Create plots
    print(f"\n🎨 Creating visualizations...")

    # 1. Governance attributes comparison
    print("   📊 Governance attributes comparison...")
    fig1 = create_governance_attributes_plot(df)
    fig1.savefig("plots/governance_attributes.png", dpi=300, bbox_inches="tight")
    plt.close(fig1)

    # 2. Parameter sensitivity
    print("   📈 Parameter sensitivity analysis...")
    fig2 = create_parameter_sensitivity_plot(df)
    fig2.savefig("plots/parameter_sensitivity.png", dpi=300, bbox_inches="tight")
    plt.close(fig2)

    # 3. Distribution comparison
    print("   🎯 Distribution comparison...")
    fig3 = create_distribution_comparison_plot(df)
    fig3.savefig("plots/distribution_comparison.png", dpi=300, bbox_inches="tight")
    plt.close(fig3)

    print(f"\n✅ Visualization complete!")
    print(f"📁 Plots saved to: plots/")
    print(f"   - governance_attributes.png")
    print(f"   - parameter_sensitivity.png")
    print(f"   - distribution_comparison.png")


if __name__ == "__main__":
    main()
