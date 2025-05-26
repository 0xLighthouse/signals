"""
Visualization Module for Statistical Analysis

This module provides comprehensive plotting capabilities for governance
system analysis results, including distribution comparisons, metric
analysis, and statistical significance visualization.
"""

import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional, Tuple
import warnings
from pathlib import Path

# Set style
plt.style.use("default")
sns.set_palette("husl")
warnings.filterwarnings("ignore", category=FutureWarning)


class GovernanceVisualizer:
    """Create comprehensive visualizations for governance analysis results."""

    def __init__(self, figsize: Tuple[int, int] = (12, 8), dpi: int = 100):
        self.figsize = figsize
        self.dpi = dpi
        self.colors = sns.color_palette("husl", 10)

    def plot_governance_attributes_comparison(
        self, results_df: pd.DataFrame, save_path: Optional[str] = None
    ) -> plt.Figure:
        """Plot comparison of the four key governance attributes across distributions."""

        # Filter successful runs
        df = results_df[results_df["success"] == True].copy()

        if df.empty:
            print("No successful runs to plot")
            return None

        # Key governance metrics
        governance_metrics = {
            "Preference Intensity": "metric_preference_intensity_score",
            "Opportunity Cost": "metric_opportunity_cost_score",
            "Sybil Resistance": "metric_sybil_resistance_score",
            "Inclusivity": "metric_inclusivity_score",
        }

        # Create subplot figure
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle(
            "Governance Attributes Across Token Distributions", fontsize=16, fontweight="bold"
        )

        axes = axes.flatten()

        for idx, (attr_name, metric_col) in enumerate(governance_metrics.items()):
            ax = axes[idx]

            if metric_col in df.columns:
                # Create box plot
                sns.boxplot(data=df, x="dist_description", y=metric_col, ax=ax, palette="Set2")

                # Add mean points
                means = df.groupby("dist_description")[metric_col].mean()
                for i, (dist, mean_val) in enumerate(means.items()):
                    ax.scatter(
                        i,
                        mean_val,
                        color="red",
                        s=100,
                        marker="D",
                        zorder=5,
                        label="Mean" if i == 0 else "",
                    )

                ax.set_title(f"{attr_name}", fontweight="bold", fontsize=12)
                ax.set_xlabel("Token Distribution", fontsize=10)
                ax.set_ylabel("Score", fontsize=10)
                ax.tick_params(axis="x", rotation=45)

                if idx == 0:
                    ax.legend()
            else:
                ax.text(
                    0.5,
                    0.5,
                    f"No data for\n{attr_name}",
                    ha="center",
                    va="center",
                    transform=ax.transAxes,
                )
                ax.set_title(f"{attr_name} (No Data)", fontweight="bold", fontsize=12)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches="tight")
            print(f"Governance attributes plot saved to: {save_path}")

        return fig

    def plot_metric_correlations(
        self, results_df: pd.DataFrame, save_path: Optional[str] = None
    ) -> plt.Figure:
        """Plot correlation matrix of governance metrics."""

        df = results_df[results_df["success"] == True].copy()

        if df.empty:
            print("No successful runs to plot")
            return None

        # Select metric columns
        metric_cols = [col for col in df.columns if col.startswith("metric_")]

        if len(metric_cols) < 2:
            print("Not enough metrics for correlation analysis")
            return None

        # Calculate correlation matrix
        corr_data = df[metric_cols].corr()

        # Clean up column names for display
        clean_names = [col.replace("metric_", "").replace("_", " ").title() for col in metric_cols]
        corr_data.columns = clean_names
        corr_data.index = clean_names

        # Create heatmap
        fig, ax = plt.subplots(figsize=(12, 10))

        mask = np.triu(np.ones_like(corr_data, dtype=bool))

        sns.heatmap(
            corr_data,
            mask=mask,
            annot=True,
            cmap="RdBu_r",
            center=0,
            square=True,
            fmt=".2f",
            cbar_kws={"shrink": 0.8},
            ax=ax,
        )

        ax.set_title("Governance Metrics Correlation Matrix", fontweight="bold", fontsize=14)
        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches="tight")
            print(f"Correlation matrix saved to: {save_path}")

        return fig

    def plot_parameter_sensitivity(
        self,
        results_df: pd.DataFrame,
        target_metric: str = "metric_preference_intensity_score",
        save_path: Optional[str] = None,
    ) -> plt.Figure:
        """Plot parameter sensitivity analysis."""

        df = results_df[results_df["success"] == True].copy()

        if df.empty or target_metric not in df.columns:
            print(f"No data available for {target_metric}")
            return None

        # Find parameter columns
        param_cols = [col for col in df.columns if col.startswith("param_")]

        if len(param_cols) == 0:
            print("No parameter columns found")
            return None

        # Create subplots for each parameter
        n_params = len(param_cols)
        n_cols = min(3, n_params)
        n_rows = (n_params + n_cols - 1) // n_cols

        fig, axes = plt.subplots(n_rows, n_cols, figsize=(5 * n_cols, 4 * n_rows))
        if n_params == 1:
            axes = [axes]
        elif n_rows == 1:
            axes = axes.reshape(1, -1)

        fig.suptitle(
            f"Parameter Sensitivity: {target_metric.replace('metric_', '').replace('_', ' ').title()}",
            fontsize=14,
            fontweight="bold",
        )

        for idx, param_col in enumerate(param_cols):
            row = idx // n_cols
            col = idx % n_cols
            ax = axes[row, col] if n_rows > 1 else axes[col]

            # Group by parameter value and calculate statistics
            param_stats = (
                df.groupby(param_col)[target_metric].agg(["mean", "std", "count"]).reset_index()
            )

            # Plot with error bars
            ax.errorbar(
                param_stats[param_col],
                param_stats["mean"],
                yerr=param_stats["std"],
                marker="o",
                capsize=5,
                capthick=2,
                linewidth=2,
                markersize=8,
            )

            ax.set_xlabel(param_col.replace("param_", "").replace("_", " ").title())
            ax.set_ylabel("Score")
            ax.set_title(f"{param_col.replace('param_', '').replace('_', ' ').title()}")
            ax.grid(True, alpha=0.3)

        # Hide empty subplots
        for idx in range(n_params, n_rows * n_cols):
            row = idx // n_cols
            col = idx % n_cols
            if n_rows > 1:
                axes[row, col].set_visible(False)
            elif n_cols > 1:
                axes[col].set_visible(False)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches="tight")
            print(f"Parameter sensitivity plot saved to: {save_path}")

        return fig

    def plot_distribution_analysis(
        self, results_df: pd.DataFrame, save_path: Optional[str] = None
    ) -> plt.Figure:
        """Plot detailed analysis of different token distributions."""

        df = results_df[results_df["success"] == True].copy()

        if df.empty:
            print("No successful runs to plot")
            return None

        # Key metrics for distribution comparison
        key_metrics = [
            "metric_acceptance_rate",
            "metric_avg_user_lock_ratio",
            "metric_small_holder_participation",
            "metric_holdings_influence_correlation",
        ]

        available_metrics = [m for m in key_metrics if m in df.columns]

        if len(available_metrics) == 0:
            print("No key metrics available for distribution analysis")
            return None

        # Create radar chart for each distribution
        distributions = df["dist_description"].unique()
        n_metrics = len(available_metrics)

        fig, axes = plt.subplots(
            1,
            len(distributions),
            figsize=(6 * len(distributions), 6),
            subplot_kw=dict(projection="polar"),
        )

        if len(distributions) == 1:
            axes = [axes]

        fig.suptitle("Token Distribution Performance Profiles", fontsize=16, fontweight="bold")

        # Angles for radar chart
        angles = np.linspace(0, 2 * np.pi, n_metrics, endpoint=False).tolist()
        angles += angles[:1]  # Complete the circle

        for idx, dist in enumerate(distributions):
            ax = axes[idx]

            # Get mean values for this distribution
            dist_data = df[df["dist_description"] == dist]
            values = []

            for metric in available_metrics:
                mean_val = dist_data[metric].mean()
                # Normalize to 0-1 scale for radar chart
                max_val = df[metric].max()
                min_val = df[metric].min()
                if max_val > min_val:
                    normalized = (mean_val - min_val) / (max_val - min_val)
                else:
                    normalized = 0.5
                values.append(normalized)

            values += values[:1]  # Complete the circle

            # Plot
            ax.plot(angles, values, "o-", linewidth=2, label=dist)
            ax.fill(angles, values, alpha=0.25)

            # Customize
            ax.set_xticks(angles[:-1])
            ax.set_xticklabels(
                [m.replace("metric_", "").replace("_", " ").title() for m in available_metrics]
            )
            ax.set_ylim(0, 1)
            ax.set_title(dist, fontweight="bold", pad=20)
            ax.grid(True)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches="tight")
            print(f"Distribution analysis plot saved to: {save_path}")

        return fig

    def plot_statistical_significance(
        self,
        results_df: pd.DataFrame,
        metric: str = "metric_preference_intensity_score",
        save_path: Optional[str] = None,
    ) -> plt.Figure:
        """Plot statistical significance tests between distributions."""

        df = results_df[results_df["success"] == True].copy()

        if df.empty or metric not in df.columns:
            print(f"No data available for {metric}")
            return None

        from .metrics import StatisticalTests

        distributions = df["dist_description"].unique()
        n_dists = len(distributions)

        if n_dists < 2:
            print("Need at least 2 distributions for comparison")
            return None

        # Create significance matrix
        p_values = np.ones((n_dists, n_dists))
        effect_sizes = np.zeros((n_dists, n_dists))

        for i in range(n_dists):
            for j in range(i + 1, n_dists):
                dist1_data = (
                    df[df["dist_description"] == distributions[i]][metric].dropna().tolist()
                )
                dist2_data = (
                    df[df["dist_description"] == distributions[j]][metric].dropna().tolist()
                )

                if len(dist1_data) >= 2 and len(dist2_data) >= 2:
                    # Statistical test
                    test_result = StatisticalTests.compare_distributions(dist1_data, dist2_data)
                    p_values[i, j] = test_result["p_value"]
                    p_values[j, i] = test_result["p_value"]

                    # Effect size
                    effect_size = StatisticalTests.effect_size_cohens_d(dist1_data, dist2_data)
                    effect_sizes[i, j] = effect_size
                    effect_sizes[j, i] = -effect_size

        # Create plots
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

        # P-values heatmap
        sns.heatmap(
            p_values,
            annot=True,
            fmt=".3f",
            cmap="RdYlBu_r",
            xticklabels=distributions,
            yticklabels=distributions,
            ax=ax1,
            cbar_kws={"label": "p-value"},
        )
        ax1.set_title("Statistical Significance (p-values)", fontweight="bold")

        # Effect sizes heatmap
        sns.heatmap(
            effect_sizes,
            annot=True,
            fmt=".2f",
            cmap="RdBu_r",
            center=0,
            xticklabels=distributions,
            yticklabels=distributions,
            ax=ax2,
            cbar_kws={"label": "Cohen's d"},
        )
        ax2.set_title("Effect Sizes (Cohen's d)", fontweight="bold")

        fig.suptitle(
            f"Statistical Analysis: {metric.replace('metric_', '').replace('_', ' ').title()}",
            fontsize=14,
            fontweight="bold",
        )

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches="tight")
            print(f"Statistical significance plot saved to: {save_path}")

        return fig

    def create_comprehensive_report(
        self, results_df: pd.DataFrame, output_dir: str = "plots"
    ) -> None:
        """Create a comprehensive set of plots for the analysis results."""

        # Create output directory
        Path(output_dir).mkdir(exist_ok=True)

        print(f"🎨 Creating comprehensive visualization report in {output_dir}/")

        # 1. Governance attributes comparison
        print("📊 Creating governance attributes comparison...")
        self.plot_governance_attributes_comparison(
            results_df, save_path=f"{output_dir}/governance_attributes.png"
        )

        # 2. Metric correlations
        print("🔗 Creating metric correlations...")
        self.plot_metric_correlations(results_df, save_path=f"{output_dir}/metric_correlations.png")

        # 3. Parameter sensitivity for key metrics
        key_metrics = [
            "metric_preference_intensity_score",
            "metric_opportunity_cost_score",
            "metric_sybil_resistance_score",
            "metric_inclusivity_score",
        ]

        for metric in key_metrics:
            if metric in results_df.columns:
                metric_name = metric.replace("metric_", "").replace("_", " ").title()
                print(f"📈 Creating parameter sensitivity for {metric_name}...")
                self.plot_parameter_sensitivity(
                    results_df,
                    target_metric=metric,
                    save_path=f"{output_dir}/sensitivity_{metric.replace('metric_', '')}.png",
                )

        # 4. Distribution analysis
        print("🎯 Creating distribution analysis...")
        self.plot_distribution_analysis(
            results_df, save_path=f"{output_dir}/distribution_analysis.png"
        )

        # 5. Statistical significance for key metrics
        for metric in key_metrics:
            if metric in results_df.columns:
                metric_name = metric.replace("metric_", "").replace("_", " ").title()
                print(f"📊 Creating statistical significance for {metric_name}...")
                self.plot_statistical_significance(
                    results_df,
                    metric=metric,
                    save_path=f"{output_dir}/significance_{metric.replace('metric_', '')}.png",
                )

        print(f"✅ Comprehensive report created in {output_dir}/")
        print(f"📁 Generated plots:")
        for file in Path(output_dir).glob("*.png"):
            print(f"   - {file.name}")


def plot_experiment_results(results_df: pd.DataFrame, output_dir: str = "plots") -> None:
    """Convenience function to create all plots for experiment results."""
    visualizer = GovernanceVisualizer()
    visualizer.create_comprehensive_report(results_df, output_dir)


def quick_plot(results_df: pd.DataFrame, plot_type: str = "governance_attributes") -> plt.Figure:
    """Quick plotting function for interactive use."""
    visualizer = GovernanceVisualizer()

    if plot_type == "governance_attributes":
        return visualizer.plot_governance_attributes_comparison(results_df)
    elif plot_type == "correlations":
        return visualizer.plot_metric_correlations(results_df)
    elif plot_type == "distributions":
        return visualizer.plot_distribution_analysis(results_df)
    elif plot_type == "sensitivity":
        return visualizer.plot_parameter_sensitivity(results_df)
    else:
        print(f"Unknown plot type: {plot_type}")
        print("Available types: governance_attributes, correlations, distributions, sensitivity")
        return None
