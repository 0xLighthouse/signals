"""
Timeline chart for initiative creation and acceptance.
"""

import matplotlib.pyplot as plt
import pandas as pd
from typing import Dict, Any, Tuple

from ..base import ChartBase, ColorPalette, DataProcessor


class TimelineChart(ChartBase):
    """Chart showing initiative timeline with creation and acceptance events."""

    @property
    def chart_name(self) -> str:
        return "timeline"

    @property
    def default_figsize(self) -> Tuple[int, int]:
        return self.config.timeline_figsize

    def create(self, df: pd.DataFrame, summary: Dict[str, Any]) -> plt.Figure:
        """Create the timeline chart."""
        fig = self.setup_figure()

        # Create subplots
        gs = fig.add_gridspec(2, 2, height_ratios=[2, 1], hspace=0.3, wspace=0.3)
        ax1 = fig.add_subplot(gs[0, :])  # Main timeline
        ax2 = fig.add_subplot(gs[1, 0])  # Initiative counts
        ax3 = fig.add_subplot(gs[1, 1])  # Acceptance rate

        # Get epoch-level data
        epoch_data = DataProcessor.group_by_epoch(
            df,
            {
                "num_initiatives": "last",
                "num_accepted": "last",
                "num_expired": "last",
            },
        )

        colors = ColorPalette.get_status_colors()

        # Main timeline plot
        ax1.plot(
            epoch_data["current_epoch"],
            epoch_data["num_initiatives"],
            marker="o",
            linewidth=2,
            label="Total Initiatives",
            color=ColorPalette.PRIMARY_BLUE,
        )
        ax1.plot(
            epoch_data["current_epoch"],
            epoch_data["num_accepted"],
            marker="s",
            linewidth=2,
            label="Accepted",
            color=colors["accepted"],
        )
        ax1.plot(
            epoch_data["current_epoch"],
            epoch_data["num_expired"],
            marker="^",
            linewidth=2,
            label="Expired",
            color=colors["expired"],
        )

        ax1.set_xlabel("Epoch")
        ax1.set_ylabel("Number of Initiatives")
        ax1.set_title("Initiative Timeline: Creation, Acceptance, and Expiration")
        ax1.legend()
        self.add_grid(ax1)

        # Initiative counts bar chart
        categories = ["Created", "Accepted", "Expired"]
        counts = [
            summary.get("initiative_statistics", {}).get("total_created", 0),
            summary.get("initiative_statistics", {}).get("total_accepted", 0),
            summary.get("initiative_statistics", {}).get("total_expired", 0),
        ]
        bar_colors = [ColorPalette.PRIMARY_BLUE, colors["accepted"], colors["expired"]]

        bars = ax2.bar(categories, counts, color=bar_colors, alpha=0.7)
        ax2.set_ylabel("Total Count")
        ax2.set_title("Initiative Summary")

        # Add value labels on bars
        for bar, count in zip(bars, counts):
            height = bar.get_height()
            ax2.text(
                bar.get_x() + bar.get_width() / 2.0,
                height + 0.1,
                f"{count}",
                ha="center",
                va="bottom",
            )

        # Acceptance rate over time
        epoch_data["acceptance_rate"] = (
            epoch_data["num_accepted"] / epoch_data["num_initiatives"].replace(0, 1) * 100
        )

        ax3.plot(
            epoch_data["current_epoch"],
            epoch_data["acceptance_rate"],
            marker="o",
            linewidth=2,
            color=colors["accepted"],
        )
        ax3.set_xlabel("Epoch")
        ax3.set_ylabel("Acceptance Rate (%)")
        ax3.set_title("Acceptance Rate Over Time")
        ax3.set_ylim(0, 100)
        self.add_grid(ax3)

        plt.tight_layout()
        return fig
