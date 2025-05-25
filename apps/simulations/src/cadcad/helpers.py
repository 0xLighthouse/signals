from typing import Dict, List
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime


def results_to_dataframe(results: List[Dict]) -> pd.DataFrame:
    """Convert simulation results to a pandas DataFrame."""
    try:
        # Extract just the fields we need to avoid serialization issues
        processed_results = []
        for row in results:
            processed_row = {
                "current_epoch": row.get("current_epoch", 0),
                "current_time": row.get("current_time", datetime.now()),
                "initiatives_count": len(row.get("initiatives", {})),
                "accepted_count": len(row.get("accepted_initiatives", set())),
                "expired_count": len(row.get("expired_initiatives", set())),
                "supporters_count": len(row.get("supporters", {})),
                "acceptance_threshold": row.get("acceptance_threshold", 0),
                "initiatives": row.get("initiatives", {}),  # Keep full object for metrics
                "accepted_initiatives": row.get("accepted_initiatives", set()),  # Keep full object for metrics
                "expired_initiatives": row.get("expired_initiatives", set()),  # Keep full object for metrics
                "supporters": row.get("supporters", {}),  # Keep full object for metrics
            }
            processed_results.append(processed_row)
            
        df = pd.DataFrame(processed_results)
        df["timestamp"] = pd.to_datetime(df["current_time"])
        return df
    except Exception as e:
        print(f"Error converting results to DataFrame: {e}")
        import traceback
        traceback.print_exc()
        # Return minimal DataFrame to avoid breaking downstream code
        return pd.DataFrame({
            "current_epoch": [0],
            "timestamp": [datetime.now()],
            "initiatives": [{}],
            "accepted_initiatives": [set()],
            "expired_initiatives": [set()],
            "supporters": [{}],
        })


def plot_initiative_weights(df: pd.DataFrame, initiative_ids: List[str] = None) -> None:
    """Plot the weight evolution of initiatives over time."""
    plt.figure(figsize=(12, 6))

    if initiative_ids is None:
        # Get all initiative IDs from the first row
        initiative_ids = list(df["initiatives"].iloc[0].keys())

    for initiative_id in initiative_ids:
        weights = df["initiatives"].apply(lambda x: x.get(initiative_id, {}).get("weight", 0))
        plt.plot(df["timestamp"], weights, label=f"Initiative {initiative_id[:8]}")

    plt.title("Initiative Weights Over Time")
    plt.xlabel("Time")
    plt.ylabel("Weight")
    plt.legend()
    plt.grid(True)
    plt.show()


def plot_support_distribution(df: pd.DataFrame, timestep: int = -1) -> None:
    """Plot the distribution of support across initiatives at a given timestep."""
    if timestep < 0:
        timestep = len(df) + timestep

    supporters = df["supporters"].iloc[timestep]
    initiative_support = {}

    for (_, initiative_id), support in supporters.items():
        if initiative_id not in initiative_support:
            initiative_support[initiative_id] = 0
        initiative_support[initiative_id] += support["amount"]

    plt.figure(figsize=(10, 6))
    plt.bar([f"Initiative {k[:8]}" for k in initiative_support.keys()], initiative_support.values())
    plt.title(f"Support Distribution at Timestep {timestep}")
    plt.xlabel("Initiative")
    plt.ylabel("Total Support (Tokens)")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()


def analyze_acceptance_rate(df: pd.DataFrame) -> Dict:
    """Analyze the rate of initiative acceptance."""
    try:
        if len(df) == 0 or "initiatives" not in df.columns or len(df["initiatives"]) == 0:
            # Return default metrics if dataframe is empty
            return {
                "total_initiatives": 0,
                "accepted": 0,
                "expired": 0,
                "active": 0,
                "acceptance_rate": 0,
            }
            
        total_initiatives = len(df["initiatives"].iloc[0])
        accepted = len(df["accepted_initiatives"].iloc[-1])
        expired = len(df["expired_initiatives"].iloc[-1])
        active = total_initiatives - accepted - expired

        return {
            "total_initiatives": total_initiatives,
            "accepted": accepted,
            "expired": expired,
            "active": active,
            "acceptance_rate": accepted / total_initiatives if total_initiatives > 0 else 0,
        }
    except Exception as e:
        print(f"Error analyzing acceptance rate: {e}")
        import traceback
        traceback.print_exc()
        # Return default metrics on error
        return {
            "total_initiatives": 0,
            "accepted": 0,
            "expired": 0,
            "active": 0,
            "acceptance_rate": 0,
        }
