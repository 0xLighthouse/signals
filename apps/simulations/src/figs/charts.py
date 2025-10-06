import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
import pandas as pd
from datetime import datetime

# Minimal, modern style
colors = {
    "gray": "#9E9E9E",
    "light_gray": "#DFDFDF",
    "dark_gray": "#848484",
    "black": "#040404",
    "red": "#FF0000",
    "orange": "#FF5B00",
}

theme = {
    "yaxis.labelcolor": colors["black"],
    "yaxis.linecolor": colors["light_gray"],
    "yaxis.labelsize": 16,
    "xaxis.labelcolor": colors["black"],
    "xaxis.linecolor": colors["light_gray"],
    "xaxis.labelsize": 16,
    "title.labelsize": 18,
    "highlight": colors["orange"],
    "xtick.labelcolor": colors["dark_gray"],
    "ytick.labelcolor": colors["dark_gray"],
}

sns.set_theme(style="white")
plt.rcParams.update(
    {
        "axes.edgecolor": "#E0E0E0",
        "axes.linewidth": 1.2,
        "axes.titlesize": 24,
        "axes.titleweight": "bold",
        "axes.labelsize": 16,
        "xtick.labelsize": 14,
        "ytick.labelsize": 14,
        "font.family": "Matter",
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "legend.frameon": False,
    }
)


def plot_op_token_price():
    """Plot OP token price data from the CSV file."""
    # Load the data
    df = pd.read_csv("/Users/arnold/Downloads/OP_1Y_graph_coinmarketcap.csv", delimiter=";")

    # Convert timestamp to datetime (handle mixed formats)
    df["timestamp"] = pd.to_datetime(df["timestamp"], format="mixed")

    # Sort by date to ensure proper line plotting
    df = df.sort_values("timestamp")

    # Create the plot
    fig, ax = plt.subplots(figsize=(14, 8))

    # Plot closing price
    ax.plot(
        df["timestamp"], df["close"], linewidth=2.5, color=colors["orange"], solid_capstyle="round"
    )

    # Fill area under the curve
    ax.fill_between(df["timestamp"], df["close"], alpha=0.2, color=colors["orange"])

    # Minimal axes styling
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(theme["yaxis.linecolor"])
    ax.spines["bottom"].set_color(theme["xaxis.linecolor"])

    # Set tick parameters
    ax.tick_params(
        left=True,
        bottom=True,
        labelleft=True,
        labelbottom=True,
    )

    # Set tick label colors
    ax.tick_params(axis="x", labelcolor=theme["xtick.labelcolor"], colors=theme["xtick.labelcolor"])
    ax.tick_params(axis="y", labelcolor=theme["ytick.labelcolor"], colors=theme["ytick.labelcolor"])

    # Labels
    ax.set_xlabel(
        "Date",
        fontsize=theme["xaxis.labelsize"],
        labelpad=10,
        color=theme["xaxis.labelcolor"],
    )
    ax.set_ylabel(
        "Price (USD)",
        fontsize=theme["yaxis.labelsize"],
        labelpad=10,
        color=theme["yaxis.labelcolor"],
    )

    # Title
    ax.set_title(
        "Grant streaming vs Market Price",
        loc="left",
        fontsize=theme["title.labelsize"],
        fontweight="bold",
        color=colors["black"],
        pad=20,
    )

    # Grid
    ax.grid(True, color=colors["light_gray"], alpha=0.5, linewidth=0.8)

    # Format y-axis to show price with $ symbol
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f"${x:.2f}"))

    # Rotate x-axis labels for better readability
    plt.xticks(rotation=45, ha="right")

    # Add annotations for key events
    grant_date = pd.to_datetime("2024-09-26")
    stream_start_date = pd.to_datetime("2025-01-15")
    stream_end_date = pd.to_datetime("2025-04-17")

    # Make dates timezone-aware to match the data
    if df["timestamp"].dt.tz is not None:
        grant_date = grant_date.tz_localize("UTC")
        stream_start_date = stream_start_date.tz_localize("UTC")
        stream_end_date = stream_end_date.tz_localize("UTC")

    # Find closest data points
    grant_idx = (df["timestamp"] - grant_date).abs().idxmin()
    grant_price = df.loc[grant_idx, "close"]

    stream_start_idx = (df["timestamp"] - stream_start_date).abs().idxmin()
    stream_start_price = df.loc[stream_start_idx, "close"]

    stream_end_idx = (df["timestamp"] - stream_end_date).abs().idxmin()
    stream_end_price = df.loc[stream_end_idx, "close"]

    # Add vertical lines
    ax.axvline(x=grant_date, color=colors["red"], linestyle="--", alpha=0.7, linewidth=2)
    ax.axvline(x=stream_start_date, color=colors["orange"], linestyle="--", alpha=0.7, linewidth=2)
    ax.axvline(x=stream_end_date, color=colors["gray"], linestyle="--", alpha=0.7, linewidth=2)

    # Annotate grant issuance
    ax.annotate(
        "Grant Issued\nSep 26, 2024",
        xy=(grant_date, grant_price),
        xytext=(grant_date, grant_price + 0.25),
        ha="center",
        fontsize=12,
        color=colors["black"],
        bbox=dict(
            boxstyle="round,pad=0.3", facecolor="white", edgecolor=colors["red"], linewidth=1.5
        ),
        arrowprops=dict(arrowstyle="->", color=colors["red"], lw=1.5),
    )

    # Annotate stream start
    ax.annotate(
        "Stream Started\nJan 15, 2025",
        xy=(stream_start_date, stream_start_price),
        xytext=(stream_start_date, stream_start_price + 0.25),
        ha="center",
        fontsize=12,
        color=colors["black"],
        bbox=dict(
            boxstyle="round,pad=0.3", facecolor="white", edgecolor=colors["orange"], linewidth=1.5
        ),
        arrowprops=dict(arrowstyle="->", color=colors["orange"], lw=1.5),
    )

    # Annotate stream end
    ax.annotate(
        "Stream Ended\nApr 16, 2025",
        xy=(stream_end_date, stream_end_price),
        xytext=(stream_end_date, stream_end_price + 0.25),
        ha="center",
        fontsize=12,
        color=colors["black"],
        bbox=dict(
            boxstyle="round,pad=0.3", facecolor="white", edgecolor=colors["gray"], linewidth=1.5
        ),
        arrowprops=dict(arrowstyle="->", color=colors["gray"], lw=1.5),
    )

    # Margins
    ax.margins(x=0.02, y=0.05)

    plt.tight_layout()
    plt.savefig("op_token_price.png", dpi=150, bbox_inches="tight")
    plt.show()


if __name__ == "__main__":
    # Generate the OP token price plot
    plot_op_token_price()
