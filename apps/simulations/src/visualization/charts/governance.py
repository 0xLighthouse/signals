"""
Governance metrics chart for showing governance-related statistics.
"""

import matplotlib.pyplot as plt
import pandas as pd
from typing import Dict, Any, Tuple

from ..base import ChartBase, ColorPalette, DataProcessor


class GovernanceMetricsChart(ChartBase):
    """Chart showing governance metrics and participation."""

    @property
    def chart_name(self) -> str:
        return "governance_metrics"

    @property
    def default_figsize(self) -> Tuple[int, int]:
        return self.config.governance_figsize

    def create(self, df: pd.DataFrame, summary: Dict[str, Any]) -> plt.Figure:
        """Create the governance metrics chart."""
        fig = self.setup_figure()

        # Create subplots
        gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
        ax1 = fig.add_subplot(gs[0, 0])  # Participation over time
        ax2 = fig.add_subplot(gs[0, 1])  # Success rates
        ax3 = fig.add_subplot(gs[1, :])  # Support activity

        # Get epoch-level data
        epoch_data = DataProcessor.group_by_epoch(
            df,
            {
                "num_supporters": "last",
                "num_initiatives": "last",
                "num_accepted": "last",
                "num_expired": "last",
            },
        )

        colors = ColorPalette.get_status_colors()

        # Participation over time
        ax1.plot(
            epoch_data["current_epoch"],
            epoch_data["num_supporters"],
            marker="o",
            linewidth=2,
            color=ColorPalette.PRIMARY_PURPLE,
        )
        ax1.set_xlabel("Epoch")
        ax1.set_ylabel("Active Supporters")
        ax1.set_title("Participation Over Time")
        self.add_grid(ax1)

        # Success rates
        total_initiatives = summary.get("initiative_statistics", {}).get("total_created", 1)
        accepted = summary.get("initiative_statistics", {}).get("total_accepted", 0)
        expired = summary.get("initiative_statistics", {}).get("total_expired", 0)
        pending = total_initiatives - accepted - expired

        sizes = [accepted, expired, pending]
        labels = ["Accepted", "Expired", "Pending"]
        pie_colors = [colors["accepted"], colors["expired"], colors["pending"]]

        # Filter out zero values
        non_zero_data = [
            (size, label, color)
            for size, label, color in zip(sizes, labels, pie_colors)
            if size > 0
        ]
        if non_zero_data:
            sizes, labels, pie_colors = zip(*non_zero_data)
            ax2.pie(sizes, labels=labels, colors=pie_colors, autopct="%1.1f%%", startangle=90)
        ax2.set_title("Initiative Outcomes")

        # Support activity
        ax3.plot(
            epoch_data["current_epoch"],
            epoch_data["num_supporters"],
            marker="s",
            linewidth=2,
            label="Active Supports",
            color=ColorPalette.PRIMARY_GREEN,
        )
        ax3.plot(
            epoch_data["current_epoch"],
            epoch_data["num_initiatives"],
            marker="o",
            linewidth=2,
            label="Total Initiatives",
            color=ColorPalette.PRIMARY_BLUE,
        )

        ax3.set_xlabel("Epoch")
        ax3.set_ylabel("Count")
        ax3.set_title("Support Activity vs Initiative Creation")
        ax3.legend()
        self.add_grid(ax3)

        plt.tight_layout()
        return fig
