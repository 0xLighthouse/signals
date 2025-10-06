"""
Data loading and preprocessing for visualization.

This module handles loading simulation results from various formats
and preprocessing them for visualization.
"""

import json
import pandas as pd
from pathlib import Path
from typing import Dict, Any, Optional, Tuple, List
from datetime import datetime


class SimulationDataLoader:
    """Handles loading and preprocessing of simulation data."""

    def __init__(self, results_dir: str = "results"):
        """Initialize with results directory."""
        self.results_dir = Path(results_dir)

    def load_latest_results(self) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """Load the most recent simulation results."""
        # Find the latest CSV file
        csv_files = list(self.results_dir.glob("simulation_results_*.csv"))
        if not csv_files:
            raise FileNotFoundError(f"No simulation results found in {self.results_dir}")

        latest_csv = max(csv_files, key=lambda p: p.stat().st_mtime)

        # Load the corresponding summary file
        timestamp = latest_csv.stem.replace("simulation_results_", "")
        summary_file = self.results_dir / f"summary_{timestamp}.json"

        return self.load_results(latest_csv, summary_file)

    def load_results(
        self, csv_path: Path, summary_path: Optional[Path] = None
    ) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """Load simulation results from specific files."""
        # Load CSV data
        df = pd.read_csv(csv_path)

        # Load summary data if available
        summary = {}
        if summary_path and summary_path.exists():
            with open(summary_path, "r") as f:
                summary = json.load(f)
        else:
            # Generate basic summary from DataFrame
            summary = self._generate_basic_summary(df)

        # Preprocess the data
        df = self._preprocess_dataframe(df)

        return df, summary

    def _preprocess_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """Preprocess the DataFrame for visualization."""
        df_processed = df.copy()

        # Convert string columns to appropriate types
        if "current_time" in df_processed.columns:
            df_processed["current_time"] = pd.to_datetime(df_processed["current_time"])

        # Parse JSON columns if they exist as strings
        json_columns = ["initiatives", "locks", "accepted_initiatives", "expired_initiatives"]
        for col in json_columns:
            if col in df_processed.columns and df_processed[col].dtype == "object":
                try:
                    df_processed[col] = df_processed[col].apply(
                        lambda x: json.loads(x) if isinstance(x, str) else x
                    )
                except (json.JSONDecodeError, TypeError):
                    # If parsing fails, keep original values
                    pass

        # Add derived columns
        df_processed = self._add_derived_columns(df_processed)

        return df_processed

    def _add_derived_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        """Add commonly used derived columns."""
        df_derived = df.copy()

        # Add initiative counts
        if "initiatives" in df_derived.columns:
            df_derived["num_initiatives"] = df_derived["initiatives"].apply(
                lambda x: len(x) if isinstance(x, dict) else 0
            )

        # Add supporter counts
        if "locks" in df_derived.columns:
            df_derived["num_locks"] = df_derived["locks"].apply(
                lambda x: len(x) if isinstance(x, dict) else 0
            )

        # Add accepted/expired counts
        if "accepted_initiatives" in df_derived.columns:
            df_derived["num_accepted"] = df_derived["accepted_initiatives"].apply(
                lambda x: len(x) if isinstance(x, (list, set)) else 0
            )

        if "expired_initiatives" in df_derived.columns:
            df_derived["num_expired"] = df_derived["expired_initiatives"].apply(
                lambda x: len(x) if isinstance(x, (list, set)) else 0
            )

        # Add token metrics if total_supply is available
        if "circulating_supply" in df_derived.columns:
            # Try to get total_supply from the first row or assume a default
            total_supply = df_derived.get(
                "total_supply", pd.Series([1_000_000] * len(df_derived))
            ).iloc[0]
            if pd.isna(total_supply):
                total_supply = 1_000_000  # Default value

            df_derived["locked_tokens"] = total_supply - df_derived["circulating_supply"]
            df_derived["circulating_percentage"] = (
                df_derived["circulating_supply"] / total_supply
            ) * 100
            df_derived["locked_percentage"] = (df_derived["locked_tokens"] / total_supply) * 100

        return df_derived

    def _generate_basic_summary(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Generate a basic summary from the DataFrame."""
        summary = {
            "simulation_info": {
                "total_epochs": len(df),
                "start_time": df["current_time"].iloc[0] if "current_time" in df.columns else None,
                "end_time": df["current_time"].iloc[-1] if "current_time" in df.columns else None,
            },
            "token_statistics": {
                "total_supply": df.get("total_supply", pd.Series([1_000_000])).iloc[0],
                "final_circulating_supply": df["circulating_supply"].iloc[-1]
                if "circulating_supply" in df.columns
                else 0,
            },
            "initiative_statistics": {
                "total_created": df["num_initiatives"].max()
                if "num_initiatives" in df.columns
                else 0,
                "total_accepted": df["num_accepted"].max() if "num_accepted" in df.columns else 0,
                "total_expired": df["num_expired"].max() if "num_expired" in df.columns else 0,
            },
            "support_statistics": {
                "max_concurrent_supports": df["num_locks"].max()
                if "num_locks" in df.columns
                else 0,
            },
        }

        return summary

    def get_epoch_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Get data grouped by epoch."""
        if "current_epoch" not in df.columns:
            raise ValueError("DataFrame must contain 'current_epoch' column")

        return df.groupby("current_epoch").last().reset_index()

    def get_initiative_timeline(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Extract initiative timeline data."""
        timeline = []

        for _, row in df.iterrows():
            epoch = row["current_epoch"]
            initiatives = row.get("initiatives", {})

            if isinstance(initiatives, dict):
                for init_id, init_data in initiatives.items():
                    if isinstance(init_data, dict):
                        timeline.append(
                            {
                                "epoch": epoch,
                                "initiative_id": init_id,
                                "title": init_data.get("title", "Untitled"),
                                "weight": init_data.get("weight", 0),
                                "created_at": init_data.get("created_at"),
                            }
                        )

        return timeline

    def get_user_balance_data(self, df: pd.DataFrame) -> Dict[str, List[float]]:
        """Extract user balance evolution data."""
        balance_data = {}

        for _, row in df.iterrows():
            balances = row.get("balances", {})

            if isinstance(balances, dict):
                for user_id, balance in balances.items():
                    if user_id not in balance_data:
                        balance_data[user_id] = []
                    balance_data[user_id].append(balance)

        return balance_data
