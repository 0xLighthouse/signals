"""
User behavior chart for showing user activity and balance distributions.
"""

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from typing import Dict, Any, Tuple

from ..base import ChartBase, ColorPalette, DataProcessor


class UserBehaviorChart(ChartBase):
    """Chart showing user behavior patterns and balance distributions."""

    @property
    def chart_name(self) -> str:
        return "user_behavior"

    @property
    def default_figsize(self) -> Tuple[int, int]:
        return self.config.user_behavior_figsize

    def create(self, df: pd.DataFrame, summary: Dict[str, Any]) -> plt.Figure:
        """Create the user behavior chart."""
        fig = self.setup_figure()

        # Create subplots
        gs = fig.add_gridspec(1, 2, wspace=0.3)
        ax1 = fig.add_subplot(gs[0, 0])  # Balance distribution
        ax2 = fig.add_subplot(gs[0, 1])  # Activity metrics

        # Extract balance data from the last epoch
        if "balances" in df.columns and len(df) > 0:
            last_balances = df["balances"].iloc[-1]
            if isinstance(last_balances, dict):
                balance_values = list(last_balances.values())

                # Balance distribution histogram
                ax1.hist(
                    balance_values,
                    bins=20,
                    alpha=0.7,
                    color=ColorPalette.PRIMARY_BLUE,
                    edgecolor="black",
                )
                ax1.set_xlabel("Token Balance")
                ax1.set_ylabel("Number of Users")
                ax1.set_title("User Balance Distribution")
                self.add_grid(ax1)

                # Format x-axis with large numbers
                ax1.xaxis.set_major_formatter(
                    plt.FuncFormatter(lambda x, p: self.format_large_numbers(x))
                )
            else:
                ax1.text(
                    0.5,
                    0.5,
                    "No balance data\navailable",
                    ha="center",
                    va="center",
                    transform=ax1.transAxes,
                )
                ax1.set_title("User Balance Distribution")
        else:
            ax1.text(
                0.5,
                0.5,
                "No balance data\navailable",
                ha="center",
                va="center",
                transform=ax1.transAxes,
            )
            ax1.set_title("User Balance Distribution")

        # Activity metrics
        epoch_data = DataProcessor.group_by_epoch(
            df,
            {
                "num_supporters": "last",
                "num_initiatives": "last",
            },
        )

        # Calculate activity metrics
        total_users = (
            len(last_balances)
            if "balances" in df.columns
            and len(df) > 0
            and isinstance(df["balances"].iloc[-1], dict)
            else 50
        )
        max_supporters = epoch_data["num_supporters"].max() if len(epoch_data) > 0 else 0
        participation_rate = (max_supporters / total_users * 100) if total_users > 0 else 0

        # Activity summary bar chart
        metrics = ["Total Users", "Max Active\nSupporters", "Participation\nRate (%)"]
        values = [total_users, max_supporters, participation_rate]
        colors_list = [
            ColorPalette.PRIMARY_BLUE,
            ColorPalette.PRIMARY_GREEN,
            ColorPalette.PRIMARY_ORANGE,
        ]

        bars = ax2.bar(metrics, values, color=colors_list, alpha=0.7)
        ax2.set_ylabel("Count / Percentage")
        ax2.set_title("User Activity Summary")

        # Add value labels on bars
        for bar, value in zip(bars, values):
            height = bar.get_height()
            ax2.text(
                bar.get_x() + bar.get_width() / 2.0,
                height + max(values) * 0.01,
                f"{value:.1f}",
                ha="center",
                va="bottom",
            )

        plt.tight_layout()
        return fig
