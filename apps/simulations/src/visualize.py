#!/usr/bin/env python3
"""
Visualization and analysis script for Initiative Dynamics Simulation results.

This script loads simulation results from the file system and generates
comprehensive visualizations and analysis of the governance dynamics.
"""

import json
import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import numpy as np

# Set up plotting style
plt.style.use("seaborn-v0_8")
sns.set_palette("husl")


def find_latest_results(results_dir="results") -> Optional[Dict[str, str]]:
    """Find the most recent simulation results."""
    if not os.path.exists(results_dir):
        print(f"❌ Results directory '{results_dir}' not found. Run the simulation first!")
        return None

    # Find all CSV files and get the latest one
    csv_files = glob.glob(os.path.join(results_dir, "simulation_results_*.csv"))
    if not csv_files:
        print(f"❌ No simulation results found in '{results_dir}'. Run the simulation first!")
        return None

    # Get the latest file based on timestamp in filename
    latest_csv = max(csv_files, key=os.path.getctime)
    # Extract timestamp from filename like "simulation_results_20250525_121516.csv"
    filename = os.path.basename(latest_csv)
    timestamp = filename.replace("simulation_results_", "").replace(".csv", "")

    # Build paths for all related files
    base_path = latest_csv  # Use the actual found path
    summary_path = os.path.join(results_dir, f"summary_{timestamp}.json")
    raw_path = os.path.join(results_dir, f"simulation_raw_{timestamp}.json")

    return {
        "csv_path": base_path,
        "summary_path": summary_path,
        "raw_path": raw_path,
        "timestamp": timestamp,
    }


def load_simulation_data(file_paths: Dict[str, str]) -> Tuple[pd.DataFrame, Dict, List]:
    """Load simulation data from files."""
    # Load CSV data
    df = pd.read_csv(file_paths["csv_path"])

    # Load summary statistics
    with open(file_paths["summary_path"], "r") as f:
        summary = json.load(f)

    # Load raw results
    with open(file_paths["raw_path"], "r") as f:
        raw_results = json.load(f)

    print(f"📊 Loaded simulation data from {file_paths['timestamp']}")
    print(f"   - {len(df)} timesteps")
    print(f"   - {summary['simulation_metadata']['total_users']} users")
    print(f"   - {summary['initiative_statistics']['total_created']} initiatives created")

    return df, summary, raw_results


def create_initiative_timeline(df: pd.DataFrame, summary: Dict) -> plt.Figure:
    """Create a timeline showing initiative creation and acceptance."""
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))

    # Use the count columns directly from the CSV
    # Group by current_epoch to get the progression over epochs
    epoch_data = (
        df.groupby("current_epoch")
        .agg({"initiatives_count": "max", "accepted_count": "max", "supporters_count": "max"})
        .reset_index()
    )

    # Plot 1: Initiative progression over epochs
    ax1.plot(
        epoch_data["current_epoch"],
        epoch_data["initiatives_count"],
        label="Total Initiatives",
        linewidth=2,
        marker="o",
    )
    ax1.plot(
        epoch_data["current_epoch"],
        epoch_data["accepted_count"],
        label="Accepted Initiatives",
        linewidth=2,
        marker="s",
    )
    ax1.fill_between(epoch_data["current_epoch"], epoch_data["accepted_count"], alpha=0.3)
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Number of Initiatives")
    ax1.set_title("Initiative Creation and Acceptance Timeline")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Plot 2: Circulating supply over time
    # Use timestep for more granular view
    ax2.plot(
        range(len(df)),
        df["circulating_supply"],
        label="Circulating Supply",
        linewidth=2,
        color="green",
        marker="d",
        markersize=3,
    )
    ax2.set_xlabel("Timestep")
    ax2.set_ylabel("Circulating Supply")
    ax2.set_title("Token Circulating Supply Over Time")
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def create_governance_metrics(summary: Dict) -> plt.Figure:
    """Create governance effectiveness metrics visualization."""
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

    # Plot 1: Initiative Status Distribution
    initiative_stats = summary["initiative_statistics"]
    statuses = ["Accepted", "Pending", "Expired"]
    counts = [
        initiative_stats["accepted"],
        initiative_stats["pending"],
        initiative_stats["expired"],
    ]
    colors = ["#2ecc71", "#f39c12", "#e74c3c"]

    ax1.pie(counts, labels=statuses, autopct="%1.1f%%", colors=colors, startangle=90)
    ax1.set_title("Initiative Status Distribution")

    # Plot 2: Token Distribution
    token_stats = summary["token_statistics"]
    token_labels = ["Circulating", "Locked"]
    token_values = [token_stats["circulating_supply"], token_stats["locked_tokens"]]

    ax2.pie(
        token_values,
        labels=token_labels,
        autopct="%1.1f%%",
        colors=["#3498db", "#9b59b6"],
        startangle=90,
    )
    ax2.set_title("Token Distribution")

    # Plot 3: Governance Parameters
    params = summary["governance_parameters"]
    param_names = ["Acceptance\nThreshold", "Inactivity\nPeriod", "Decay\nMultiplier"]
    param_values = [
        params["acceptance_threshold"],
        params["inactivity_period"],
        params["decay_multiplier"],
    ]

    bars = ax3.bar(param_names, param_values, color=["#e67e22", "#1abc9c", "#8e44ad"])
    ax3.set_title("Governance Parameters")
    ax3.set_ylabel("Value")

    # Add value labels on bars
    for bar, value in zip(bars, param_values):
        height = bar.get_height()
        ax3.text(
            bar.get_x() + bar.get_width() / 2.0,
            height + height * 0.01,
            f"{value}",
            ha="center",
            va="bottom",
        )

    # Plot 4: Key Metrics Summary
    metrics = {
        "Acceptance Rate": f"{initiative_stats['acceptance_rate']:.1%}",
        "Total Users": summary["simulation_metadata"]["total_users"],
        "Final Epoch": summary["simulation_metadata"]["final_epoch"],
        "Avg User Balance": f"{token_stats['average_user_balance']:,.0f}",
    }

    ax4.axis("off")
    y_pos = 0.8
    for metric, value in metrics.items():
        ax4.text(0.1, y_pos, f"{metric}:", fontsize=12, fontweight="bold")
        ax4.text(0.6, y_pos, str(value), fontsize=12)
        y_pos -= 0.15
    ax4.set_title("Key Metrics Summary", fontsize=14, fontweight="bold")

    plt.tight_layout()
    return fig


def create_token_flux_violin(df: pd.DataFrame, summary: Dict) -> plt.Figure:
    """Create violin plot showing token flux between circulating and locked over epochs."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))

    # Prepare data for violin plot
    # Calculate locked tokens as total_supply - circulating_supply
    total_supply = summary["token_statistics"]["total_supply"]
    df_copy = df.copy()
    df_copy["locked_tokens"] = total_supply - df_copy["circulating_supply"]
    df_copy["locked_percentage"] = (df_copy["locked_tokens"] / total_supply) * 100
    df_copy["circulating_percentage"] = (df_copy["circulating_supply"] / total_supply) * 100

    # Group by epoch to get distributions
    epoch_data = (
        df_copy.groupby("current_epoch")
        .agg(
            {
                "circulating_supply": ["mean", "std", "min", "max"],
                "locked_tokens": ["mean", "std", "min", "max"],
                "circulating_percentage": ["mean", "std", "min", "max"],
                "locked_percentage": ["mean", "std", "min", "max"],
            }
        )
        .reset_index()
    )

    # Flatten column names
    epoch_data.columns = ["_".join(col).strip("_") for col in epoch_data.columns]

    # Create violin plot data - we'll simulate distributions for each epoch
    violin_data_circ = []
    violin_data_locked = []
    epochs = []

    for _, row in epoch_data.iterrows():
        epoch = int(row["current_epoch"])
        epochs.append(epoch)

        # Get epoch-specific data
        epoch_subset = df_copy[df_copy["current_epoch"] == epoch]

        if len(epoch_subset) > 1:
            # Use actual data points if we have multiple timesteps per epoch
            violin_data_circ.extend(
                [(epoch, val) for val in epoch_subset["circulating_percentage"]]
            )
            violin_data_locked.extend([(epoch, val) for val in epoch_subset["locked_percentage"]])
        else:
            # If only one data point, create a small distribution around it
            mean_circ = row["circulating_percentage_mean"]
            mean_locked = row["locked_percentage_mean"]
            std_circ = max(row["circulating_percentage_std"], 0.1)  # Minimum std for visualization
            std_locked = max(row["locked_percentage_std"], 0.1)

            # Generate small distribution around the mean
            for _ in range(10):  # Create 10 synthetic points
                violin_data_circ.append((epoch, np.random.normal(mean_circ, std_circ)))
                violin_data_locked.append((epoch, np.random.normal(mean_locked, std_locked)))

    # Convert to DataFrame for seaborn
    circ_df = pd.DataFrame(violin_data_circ, columns=["Epoch", "Circulating %"])
    locked_df = pd.DataFrame(violin_data_locked, columns=["Epoch", "Locked %"])

    # Plot 1: Circulating Token Distribution by Epoch
    if len(circ_df) > 0:
        sns.violinplot(data=circ_df, x="Epoch", y="Circulating %", ax=ax1, color="lightblue")
        ax1.set_title("Circulating Token Distribution by Epoch", fontsize=14, fontweight="bold")
        ax1.set_ylabel("Circulating Tokens (%)")
        ax1.grid(True, alpha=0.3)

        # Add mean line
        epoch_means_circ = df_copy.groupby("current_epoch")["circulating_percentage"].mean()
        ax1.plot(
            range(len(epoch_means_circ)),
            epoch_means_circ.values,
            color="red",
            linewidth=2,
            marker="o",
            label="Mean",
        )
        ax1.legend()

    # Plot 2: Locked Token Distribution by Epoch
    if len(locked_df) > 0:
        sns.violinplot(data=locked_df, x="Epoch", y="Locked %", ax=ax2, color="lightcoral")
        ax2.set_title("Locked Token Distribution by Epoch", fontsize=14, fontweight="bold")
        ax2.set_ylabel("Locked Tokens (%)")
        ax2.grid(True, alpha=0.3)

        # Add mean line
        epoch_means_locked = df_copy.groupby("current_epoch")["locked_percentage"].mean()
        ax2.plot(
            range(len(epoch_means_locked)),
            epoch_means_locked.values,
            color="darkred",
            linewidth=2,
            marker="s",
            label="Mean",
        )
        ax2.legend()

    # Add summary statistics as text
    final_circ_pct = df_copy["circulating_percentage"].iloc[-1]
    final_locked_pct = df_copy["locked_percentage"].iloc[-1]

    fig.suptitle(
        f"Token Flux Analysis - Final State: {final_circ_pct:.1f}% Circulating, {final_locked_pct:.1f}% Locked",
        fontsize=16,
        fontweight="bold",
    )

    plt.tight_layout()
    return fig


def create_user_behavior_analysis(df: pd.DataFrame) -> plt.Figure:
    """Analyze user behavior patterns."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

    # Plot 1: Supporter Activity Over Time
    epoch_data = (
        df.groupby("current_epoch")
        .agg({"supporters_count": "max", "initiatives_count": "max"})
        .reset_index()
    )

    ax1.plot(
        epoch_data["current_epoch"],
        epoch_data["supporters_count"],
        label="Active Supporters",
        linewidth=2,
        marker="o",
        color="orange",
    )
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Number of Active Supporters")
    ax1.set_title("User Participation Over Time")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Plot 2: Governance Activity Ratio
    # Calculate ratio of supporters to initiatives
    epoch_data["participation_ratio"] = epoch_data["supporters_count"] / (
        epoch_data["initiatives_count"] + 1
    )  # +1 to avoid division by zero

    ax2.plot(
        epoch_data["current_epoch"],
        epoch_data["participation_ratio"],
        linewidth=2,
        marker="s",
        color="purple",
    )
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Supporters per Initiative")
    ax2.set_title("Governance Engagement Ratio")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def create_reward_analysis(df: pd.DataFrame, summary: Dict) -> plt.Figure:
    """Create visualizations for reward distribution and patterns."""
    fig = plt.figure(figsize=(20, 15))
    gs = fig.add_gridspec(3, 2)

    # Extract reward data from summary
    reward_stats = summary.get("reward_statistics", {})
    if not reward_stats:
        print("⚠️ No reward statistics available in the summary")
        return fig

    # Plot 1: Reward Distribution by Initiative Weight
    ax1 = fig.add_subplot(gs[0, 0])
    reward_by_weight = reward_stats.get("reward_by_initiative_weight", {})
    if reward_by_weight:
        weights = sorted(reward_by_weight.keys())
        rewards = [reward_by_weight[w] for w in weights]
        ax1.bar(weights, rewards, color="skyblue", alpha=0.7)
        ax1.set_xlabel("Initiative Weight (% of threshold)")
        ax1.set_ylabel("Total Rewards Distributed")
        ax1.set_title("Reward Distribution by Initiative Weight")
        ax1.grid(True, alpha=0.3)

    # Plot 2: Reward Distribution by Lock Duration
    ax2 = fig.add_subplot(gs[0, 1])
    reward_by_lock = reward_stats.get("reward_by_lock_duration", {})
    if reward_by_lock:
        locks = sorted(reward_by_lock.keys())
        rewards = [reward_by_lock[l] for l in locks]
        ax2.bar(locks, rewards, color="lightgreen", alpha=0.7)
        ax2.set_xlabel("Lock Duration (hours)")
        ax2.set_ylabel("Total Rewards Distributed")
        ax2.set_title("Reward Distribution by Lock Duration")
        ax2.grid(True, alpha=0.3)

    # Plot 3: Top Reward Earners
    ax3 = fig.add_subplot(gs[1, :])
    top_earners = reward_stats.get("top_reward_earners", {})
    if top_earners:
        users = list(top_earners.keys())[:10]  # Top 10 earners
        earnings = [top_earners[u] for u in users]
        # Shorten user IDs for better display
        short_users = [f"{u[:6]}...{u[-4:]}" for u in users]
        ax3.barh(short_users, earnings, color="salmon", alpha=0.7)
        ax3.set_xlabel("Total Rewards Earned")
        ax3.set_title("Top 10 Reward Earners")
        ax3.grid(True, alpha=0.3)

    # Plot 4: Reward Concentration Analysis
    ax4 = fig.add_subplot(gs[2, 0])
    concentration = reward_stats.get("reward_concentration", 0)
    ax4.bar(["Reward Concentration"], [concentration], color="purple", alpha=0.7)
    ax4.set_ylim(0, 1)
    ax4.set_ylabel("Concentration Score (0=Equal, 1=Concentrated)")
    ax4.set_title("Reward Distribution Concentration")
    ax4.grid(True, alpha=0.3)

    # Plot 5: Reward Statistics Summary
    ax5 = fig.add_subplot(gs[2, 1])
    ax5.axis("off")
    stats_text = [
        f"Total Rewards: {reward_stats.get('total_rewards_distributed', 0):,.2f}",
        f"Users Earning Rewards: {reward_stats.get('users_earning_rewards', 0)}",
        f"Average Reward: {reward_stats.get('average_reward_per_user', 0):,.2f}",
        f"Median Reward: {reward_stats.get('median_reward', 0):,.2f}",
    ]
    y_pos = 0.8
    for stat in stats_text:
        ax5.text(0.1, y_pos, stat, fontsize=12)
        y_pos -= 0.15
    ax5.set_title("Reward Statistics Summary", fontsize=14, fontweight="bold")

    plt.tight_layout()
    return fig


def create_reward_correlation_analysis(df: pd.DataFrame, summary: Dict) -> plt.Figure:
    """Create visualizations showing correlations between rewards and other metrics."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

    # Extract reward history from the last state
    reward_history = summary.get("reward_statistics", {}).get("reward_history", [])
    if not reward_history:
        print("⚠️ No reward history available for correlation analysis")
        return fig

    # Convert reward history to DataFrame for easier analysis
    reward_df = pd.DataFrame(reward_history)
    if reward_df.empty:
        print("⚠️ Empty reward history DataFrame")
        return fig

    # Plot 1: Reward vs Balance Correlation
    if "user_balance_before" in reward_df.columns and "reward_amount" in reward_df.columns:
        ax1.scatter(
            reward_df["user_balance_before"], reward_df["reward_amount"], alpha=0.5, color="blue"
        )
        ax1.set_xlabel("User Balance Before Reward")
        ax1.set_ylabel("Reward Amount")
        ax1.set_title("Reward Amount vs User Balance")
        ax1.grid(True, alpha=0.3)

    # Plot 2: Reward Rate vs Initiative Weight
    if all(
        col in reward_df.columns for col in ["weight_percentage", "reward_amount", "support_amount"]
    ):
        # Calculate reward rate (reward/support)
        reward_df["reward_rate"] = reward_df["reward_amount"] / reward_df["support_amount"]
        ax2.scatter(
            reward_df["weight_percentage"], reward_df["reward_rate"], alpha=0.5, color="green"
        )
        ax2.set_xlabel("Initiative Weight (% of threshold)")
        ax2.set_ylabel("Reward Rate (Reward/Support)")
        ax2.set_title("Reward Rate vs Initiative Weight")
        ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def generate_analysis_report(summary: Dict, df: pd.DataFrame) -> str:
    """Generate a text-based analysis report."""
    report = []
    report.append("=" * 60)
    report.append("INITIATIVE DYNAMICS SIMULATION - ANALYSIS REPORT")
    report.append("=" * 60)
    report.append("")

    # Simulation Overview
    meta = summary["simulation_metadata"]
    report.append("📊 SIMULATION OVERVIEW")
    report.append("-" * 30)
    report.append(f"Simulation completed: {meta['simulation_completed']}")
    report.append(f"Total timesteps: {meta['total_timesteps']}")
    report.append(f"Final epoch: {meta['final_epoch']}")
    report.append(f"Total users: {meta['total_users']}")
    report.append("")

    # Initiative Statistics
    init_stats = summary["initiative_statistics"]
    report.append("🏛️  GOVERNANCE EFFECTIVENESS")
    report.append("-" * 30)
    report.append(f"Total initiatives created: {init_stats['total_created']}")
    report.append(f"Initiatives accepted: {init_stats['accepted']}")
    report.append(f"Initiatives expired: {init_stats['expired']}")
    report.append(f"Initiatives pending: {init_stats['pending']}")
    report.append(f"Acceptance rate: {init_stats['acceptance_rate']:.1%}")
    report.append("")

    # Token Economics
    token_stats = summary["token_statistics"]
    report.append("💰 TOKEN ECONOMICS")
    report.append("-" * 30)
    report.append(f"Total supply: {token_stats['total_supply']:,}")
    report.append(f"Circulating supply: {token_stats['circulating_supply']:,.0f}")
    report.append(f"Locked tokens: {token_stats['locked_tokens']:,.0f}")
    report.append(f"Average user balance: {token_stats['average_user_balance']:,.0f}")
    report.append("")

    # Governance Parameters
    params = summary["governance_parameters"]
    report.append("⚙️  GOVERNANCE PARAMETERS")
    report.append("-" * 30)
    report.append(f"Acceptance threshold: {params['acceptance_threshold']:,}")
    report.append(f"Inactivity period: {params['inactivity_period']} epochs")
    report.append(f"Decay multiplier: {params['decay_multiplier']}")
    report.append("")

    # Key Insights
    report.append("🔍 KEY INSIGHTS")
    report.append("-" * 30)

    if init_stats["acceptance_rate"] > 0.8:
        report.append("• High acceptance rate suggests effective community coordination")
    elif init_stats["acceptance_rate"] < 0.3:
        report.append("• Low acceptance rate may indicate high standards or poor proposals")
    else:
        report.append("• Moderate acceptance rate shows balanced governance")

    locked_percentage = token_stats["locked_tokens"] / token_stats["total_supply"]
    if locked_percentage > 0.1:
        report.append("• Significant token locking shows active governance participation")
        report.append(f"• {locked_percentage:.1%} of total supply is locked in governance")
    else:
        report.append("• Low token locking suggests limited governance engagement")

    # Add token flux insights
    circ_percentage = token_stats["circulating_supply"] / token_stats["total_supply"]
    report.append(
        f"• Token distribution: {circ_percentage:.1%} circulating, {locked_percentage:.1%} locked"
    )

    if init_stats["expired"] == 0:
        report.append("• No expired initiatives indicates active community support")
    else:
        report.append(f"• {init_stats['expired']} expired initiatives show natural filtering")

    # Add Reward Analysis Section
    reward_stats = summary.get("reward_statistics", {})
    if reward_stats:
        report.append("🎁 REWARD SYSTEM ANALYSIS")
        report.append("-" * 30)
        report.append(
            f"Total rewards distributed: {reward_stats.get('total_rewards_distributed', 0):,.2f}"
        )
        report.append(f"Users earning rewards: {reward_stats.get('users_earning_rewards', 0)}")
        report.append(
            f"Average reward per user: {reward_stats.get('average_reward_per_user', 0):,.2f}"
        )
        report.append(f"Median reward: {reward_stats.get('median_reward', 0):,.2f}")
        report.append(f"Reward concentration: {reward_stats.get('reward_concentration', 0):.2f}")
        report.append("")

        # Add reward insights
        concentration = reward_stats.get("reward_concentration", 0)
        if concentration < 0.3:
            report.append("• Low reward concentration indicates fair distribution")
        elif concentration > 0.7:
            report.append(
                "• High reward concentration suggests rewards are concentrated among few users"
            )
        else:
            report.append("• Moderate reward concentration shows balanced distribution")

        # Analyze reward patterns
        reward_by_weight = reward_stats.get("reward_by_initiative_weight", {})
        if reward_by_weight:
            early_weight_rewards = sum(v for k, v in reward_by_weight.items() if k < 0.3)
            total_rewards = sum(reward_by_weight.values())
            if total_rewards > 0:
                early_percentage = early_weight_rewards / total_rewards
                report.append(
                    f"• {early_percentage:.1%} of rewards went to early supporters (weight < 30%)"
                )

    report.append("")
    report.append("=" * 60)

    return "\n".join(report)


def save_visualizations(
    figures: List[plt.Figure],
    file_paths: Dict[str, str],
    report: str,
    output_dir: str = "results/visualizations",
):
    """Save all visualizations and analysis to files."""
    # Create visualization directory
    os.makedirs(output_dir, exist_ok=True)
    timestamp = file_paths["timestamp"]

    # Save figures
    figure_names = [
        "timeline",
        "governance_metrics",
        "user_behavior",
        "token_flux",
        "reward_analysis",
        "reward_correlation",
    ]
    saved_files = []

    for i, (fig, name) in enumerate(zip(figures, figure_names)):
        if fig is not None:  # Only save if figure was created
            filename = f"{name}_{timestamp}.png"
            filepath = os.path.join(output_dir, filename)
            fig.savefig(filepath, dpi=300, bbox_inches="tight")
            saved_files.append(filepath)
            print(f"📊 Saved {name} chart: {filepath}")
        else:
            print(f"⚠️ Skipping {name} chart - no data available")

    # Save analysis report
    report_path = os.path.join(output_dir, f"analysis_report_{timestamp}.txt")
    with open(report_path, "w") as f:
        f.write(report)
    saved_files.append(report_path)
    print(f"📄 Saved analysis report: {report_path}")

    return saved_files


def main():
    """Main visualization function."""
    print("🎨 Starting visualization and analysis...")

    # Find and load latest results
    file_paths = find_latest_results()
    if not file_paths:
        return

    df, summary, raw_results = load_simulation_data(file_paths)

    # Create visualizations
    print("\n📊 Generating visualizations...")

    # Comment out plots to improve them one by one
    # fig1 = create_initiative_timeline(df, summary)
    # fig2 = create_governance_metrics(summary)
    # fig3 = create_user_behavior_analysis(df)
    # fig4 = create_token_flux_violin(df, summary)
    # fig5 = create_reward_analysis(df, summary)
    # fig6 = create_reward_correlation_analysis(df, summary)

    figures = []  # Empty for now while we improve plots

    # Generate analysis report
    print("📄 Generating analysis report...")
    report = generate_analysis_report(summary, df)
    print("\n" + report)

    # Save everything
    saved_files = save_visualizations(figures, file_paths, report)

    print(f"\n✅ Analysis complete! Generated {len(saved_files)} files:")
    for file in saved_files:
        print(f"   📁 {file}")

    # Show plots (if any)
    if figures:
        print("\n🖼️  Displaying charts...")
        plt.show()
    else:
        print("\n📊 No plots to display yet - ready to improve visualizations one by one!")


if __name__ == "__main__":
    main()
