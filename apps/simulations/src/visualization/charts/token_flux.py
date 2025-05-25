"""
Token flux chart for showing token distribution and circulation.
"""

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from typing import Dict, Any, Tuple

from ..base import ChartBase, ColorPalette, DataProcessor


class TokenFluxChart(ChartBase):
    """Chart showing token flux between circulating and locked states."""

    @property
    def chart_name(self) -> str:
        return "token_flux"

    @property
    def default_figsize(self) -> Tuple[int, int]:
        return self.config.token_flux_figsize

    def create(self, df: pd.DataFrame, summary: Dict[str, Any]) -> plt.Figure:
        """Create the token flux chart."""
        fig = self.setup_figure()

        # Create subplots
        gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
        ax1 = fig.add_subplot(gs[0, :])  # Main flux timeline
        ax2 = fig.add_subplot(gs[1, 0])  # Distribution violin plot
        ax3 = fig.add_subplot(gs[1, 1])  # Final state pie chart

        # Add derived columns
        df_processed = DataProcessor.add_derived_columns(df, summary)

        # Get epoch-level data
        epoch_data = DataProcessor.group_by_epoch(
            df_processed,
            {
                "circulating_supply": "last",
                "locked_tokens": "last",
                "circulating_percentage": "last",
                "locked_percentage": "last",
            },
        )

        colors = ColorPalette.get_token_colors()

        # Main flux timeline
        ax1.fill_between(
            epoch_data["current_epoch"],
            0,
            epoch_data["circulating_supply"],
            alpha=0.7,
            color=colors["circulating"],
            label="Circulating",
        )
        ax1.fill_between(
            epoch_data["current_epoch"],
            epoch_data["circulating_supply"],
            epoch_data["circulating_supply"] + epoch_data["locked_tokens"],
            alpha=0.7,
            color=colors["locked"],
            label="Locked",
        )

        ax1.set_xlabel("Epoch")
        ax1.set_ylabel("Token Amount")
        ax1.set_title("Token Distribution Over Time")
        ax1.legend()
        self.add_grid(ax1)

        # Format y-axis with large numbers
        ax1.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: self.format_large_numbers(x)))

        # Distribution violin plot
        if len(df_processed) > 1:
            # Create violin plot data
            circulating_data = df_processed["circulating_supply"].values
            locked_data = df_processed["locked_tokens"].values

            # Create violin plot
            violin_data = [circulating_data, locked_data]
            violin_labels = ["Circulating", "Locked"]
            violin_colors = [colors["circulating"], colors["locked"]]

            parts = ax2.violinplot(violin_data, positions=[1, 2], showmeans=True, showmedians=True)

            # Color the violin plots
            for i, (pc, color) in enumerate(zip(parts["bodies"], violin_colors)):
                pc.set_facecolor(color)
                pc.set_alpha(0.7)

            ax2.set_xticks([1, 2])
            ax2.set_xticklabels(violin_labels)
            ax2.set_ylabel("Token Amount")
            ax2.set_title("Token Distribution Density")
            self.add_grid(ax2)

            # Format y-axis
            ax2.yaxis.set_major_formatter(
                plt.FuncFormatter(lambda x, p: self.format_large_numbers(x))
            )
        else:
            ax2.text(
                0.5,
                0.5,
                "Insufficient data\nfor distribution plot",
                ha="center",
                va="center",
                transform=ax2.transAxes,
            )
            ax2.set_title("Token Distribution Density")

        # Final state pie chart
        final_circulating = epoch_data["circulating_supply"].iloc[-1]
        final_locked = epoch_data["locked_tokens"].iloc[-1]

        if final_circulating + final_locked > 0:
            sizes = [final_circulating, final_locked]
            labels = ["Circulating", "Locked"]
            pie_colors = [colors["circulating"], colors["locked"]]

            wedges, texts, autotexts = ax3.pie(
                sizes, labels=labels, colors=pie_colors, autopct="%1.1f%%", startangle=90
            )

            # Format the percentage text
            for autotext in autotexts:
                autotext.set_color("white")
                autotext.set_fontweight("bold")
        else:
            ax3.text(
                0.5,
                0.5,
                "No token data\navailable",
                ha="center",
                va="center",
                transform=ax3.transAxes,
            )

        ax3.set_title("Final Token Distribution")

        plt.tight_layout()
        return fig
