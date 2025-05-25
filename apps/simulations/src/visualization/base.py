"""
Base classes and utilities for visualization components.
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Tuple
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

from ..cadcad.config import get_visualization_config


class ChartBase(ABC):
    """Base class for all chart types."""

    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """Initialize chart with optional configuration override."""
        self.config = get_visualization_config()
        if config:
            # Override default config with provided values
            for key, value in config.items():
                if hasattr(self.config, key):
                    setattr(self.config, key, value)

    @abstractmethod
    def create(self, df: pd.DataFrame, summary: Dict[str, Any]) -> plt.Figure:
        """Create the chart. Must be implemented by subclasses."""
        pass

    @property
    @abstractmethod
    def chart_name(self) -> str:
        """Return the name of this chart type."""
        pass

    @property
    @abstractmethod
    def default_figsize(self) -> Tuple[int, int]:
        """Return the default figure size for this chart."""
        pass

    def setup_figure(self, figsize: Optional[Tuple[int, int]] = None) -> plt.Figure:
        """Set up a figure with consistent styling."""
        if figsize is None:
            figsize = self.default_figsize

        fig = plt.figure(figsize=figsize)

        # Apply consistent styling
        plt.style.use(self.config.style)

        return fig

    def save_chart(self, fig: plt.Figure, output_path: Path) -> None:
        """Save chart with consistent settings."""
        fig.savefig(
            output_path,
            dpi=self.config.figure_dpi,
            bbox_inches="tight",
            format=self.config.figure_format,
        )

    def add_grid(self, ax: plt.Axes, alpha: float = 0.3) -> None:
        """Add consistent grid styling."""
        ax.grid(True, alpha=alpha)

    def format_large_numbers(self, value: float) -> str:
        """Format large numbers for display."""
        if value >= 1_000_000:
            return f"{value / 1_000_000:.1f}M"
        elif value >= 1_000:
            return f"{value / 1_000:.1f}K"
        else:
            return f"{value:.0f}"


class DataProcessor:
    """Utility class for common data processing operations."""

    @staticmethod
    def group_by_epoch(df: pd.DataFrame, agg_columns: Dict[str, str]) -> pd.DataFrame:
        """Group data by epoch with specified aggregations."""
        return df.groupby("current_epoch").agg(agg_columns).reset_index()

    @staticmethod
    def calculate_percentages(df: pd.DataFrame, total_column: str, *columns: str) -> pd.DataFrame:
        """Calculate percentage columns based on a total."""
        df_copy = df.copy()
        total = df_copy[total_column]

        for col in columns:
            if col in df_copy.columns:
                df_copy[f"{col}_percentage"] = (df_copy[col] / total) * 100

        return df_copy

    @staticmethod
    def add_derived_columns(df: pd.DataFrame, summary: Dict[str, Any]) -> pd.DataFrame:
        """Add commonly used derived columns."""
        df_copy = df.copy()
        total_supply = summary["token_statistics"]["total_supply"]

        # Add locked tokens
        df_copy["locked_tokens"] = total_supply - df_copy["circulating_supply"]

        # Add percentages
        df_copy["circulating_percentage"] = (df_copy["circulating_supply"] / total_supply) * 100
        df_copy["locked_percentage"] = (df_copy["locked_tokens"] / total_supply) * 100

        return df_copy


class ColorPalette:
    """Consistent color palette for all charts."""

    # Primary colors
    PRIMARY_BLUE = "#3498db"
    PRIMARY_GREEN = "#2ecc71"
    PRIMARY_RED = "#e74c3c"
    PRIMARY_ORANGE = "#f39c12"
    PRIMARY_PURPLE = "#9b59b6"

    # Secondary colors
    LIGHT_BLUE = "#85c1e9"
    LIGHT_GREEN = "#82e5aa"
    LIGHT_RED = "#f1948a"
    LIGHT_ORANGE = "#f8c471"
    LIGHT_PURPLE = "#bb8fce"

    # Status colors
    SUCCESS = "#2ecc71"
    WARNING = "#f39c12"
    DANGER = "#e74c3c"
    INFO = "#3498db"

    @classmethod
    def get_status_colors(cls) -> Dict[str, str]:
        """Get colors for different statuses."""
        return {
            "accepted": cls.SUCCESS,
            "pending": cls.WARNING,
            "expired": cls.DANGER,
        }

    @classmethod
    def get_token_colors(cls) -> Dict[str, str]:
        """Get colors for token-related visualizations."""
        return {
            "circulating": cls.PRIMARY_BLUE,
            "locked": cls.PRIMARY_PURPLE,
        }
