import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from itertools import groupby
from operator import itemgetter
import matplotlib.patches as mpatches

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

# Time range in days
days = np.arange(0, 90)
ACCEPTANCE_THRESHOLD = 25000


# Helper to generate exponential decay
def generate_exp_decay_curve(weight, start, decay_rate):
    curve = np.zeros_like(days, dtype=float)
    for i, day in enumerate(days):
        if day >= start:
            curve[i] = weight * (decay_rate ** (day - start))
    return curve


# Scenario definitions (all within 90 days, adjusted decay rates)
scenario_a_locks = [
    {"weight": 9000, "start": 0, "rate": 0.97},
    {"weight": 8000, "start": 3, "rate": 0.97},
    {"weight": 8000, "start": 6, "rate": 0.97},
    {"weight": 6000, "start": 10, "rate": 0.97},
    {"weight": 5000, "start": 15, "rate": 0.97},
    {"weight": 20000, "start": 45, "rate": 0.97},
]
scenario_b_locks = [
    {"weight": 8000, "start": 0, "rate": 0.94},
    {"weight": 5000, "start": 25, "rate": 0.94},
    {"weight": 3600, "start": 60, "rate": 0.94},
    {"weight": 3000, "start": 70, "rate": 0.94},
    {"weight": 2400, "start": 80, "rate": 0.94},
]
scenario_c_locks = [
    {"weight": 4000, "start": 0, "rate": 0.96},
    {"weight": 3500, "start": 8, "rate": 0.96},
    {"weight": 3000, "start": 16, "rate": 0.96},
    # Long period of inactivity
    {"weight": 12000, "start": 60, "rate": 0.98},
    {"weight": 8000, "start": 65, "rate": 0.98},
    {"weight": 8000, "start": 66, "rate": 0.98},
]

scenario_d_locks = [
    {"weight": 10000, "start": 0, "rate": 0.98},
    {"weight": 1500, "start": 1, "rate": 0.96},
    {"weight": 1500, "start": 2, "rate": 0.96},
    {"weight": 1500, "start": 3, "rate": 0.96},
    {"weight": 1500, "start": 4, "rate": 0.96},
    {"weight": 1500, "start": 5, "rate": 0.96},
    {"weight": 1500, "start": 6, "rate": 0.96},
    {"weight": 1500, "start": 7, "rate": 0.96},
    {"weight": 1500, "start": 8, "rate": 0.96},
    {"weight": 1500, "start": 9, "rate": 0.96},
    {"weight": 1500, "start": 10, "rate": 0.96},
    {"weight": 1500, "start": 11, "rate": 0.96},
    {"weight": 1500, "start": 12, "rate": 0.96},
    {"weight": 1500, "start": 13, "rate": 0.96},
    {"weight": 1500, "start": 14, "rate": 0.96},
    {"weight": 1500, "start": 15, "rate": 0.96},
    {"weight": 1500, "start": 16, "rate": 0.96},
    {"weight": 1500, "start": 17, "rate": 0.96},
    {"weight": 1000, "start": 18, "rate": 0.96},
    {"weight": 1000, "start": 19, "rate": 0.96},
    {"weight": 1000, "start": 20, "rate": 0.96},
    {"weight": 1000, "start": 21, "rate": 0.96},
    {"weight": 1000, "start": 22, "rate": 0.96},
    {"weight": 1000, "start": 23, "rate": 0.96},
    {"weight": 1000, "start": 24, "rate": 0.96},
    {"weight": 1000, "start": 25, "rate": 0.96},
    {"weight": 1000, "start": 26, "rate": 0.96},
]


def plot_scenario(locks, title, filename, highlight_color="#FF5B00"):
    weights_matrix = []
    for lock in locks:
        weights_matrix.append(generate_exp_decay_curve(lock["weight"], lock["start"], lock["rate"]))
    weights_matrix = np.array(weights_matrix)
    total_support = np.sum(weights_matrix, axis=0)

    fig, ax = plt.subplots(figsize=(12, 6))

    # Visually clean, harmonious palette for stacked area
    clean_palette = [
        "#BFD7EA",  # pale blue
        "#A6C8B3",  # soft green
        "#F6EAC2",  # pale sand
        "#E2C2C6",  # muted rose
        "#C2D4DD",  # light steel blue
        "#B5B9D6",  # lavender blue
        "#D6C2E2",  # pale purple
        "#C2E2DF",  # minty teal
    ]
    colors_list = clean_palette[: len(locks)]

    # Stacked area (clean harmonious palette)
    ax.stackplot(days, weights_matrix, colors=colors_list, alpha=0.75, edgecolor="none")

    # Total support line (brand color, very prominent)
    ax.plot(
        days,
        total_support,
        color=highlight_color,
        linewidth=3,
        label="Support",
        zorder=3,
        solid_capstyle="round",
    )
    acceptance_patch = None
    # Highlight area(s) above threshold and label each acceptance window
    above = total_support > ACCEPTANCE_THRESHOLD
    if np.any(above):
        # Find contiguous regions above threshold
        indices = np.where(above)[0]
        # Group indices into contiguous regions
        for k, g in groupby(enumerate(indices), lambda ix: ix[0] - ix[1]):
            group = list(map(itemgetter(1), g))
            start_idx, end_idx = group[0], group[-1]
            start_day, end_day = int(days[start_idx]), int(days[end_idx])
            # Highlight this window
            ax.fill_between(
                days[start_idx : end_idx + 1],
                ACCEPTANCE_THRESHOLD,
                total_support[start_idx : end_idx + 1],
                color=colors["black"],
                alpha=0.65,
                hatch="//",
                edgecolor=highlight_color,
                linewidth=0.0,
                zorder=2,
                label=None,  # Don't add to legend here
            )
            # Create proxy patch for legend (only once)
            if acceptance_patch is None:
                acceptance_patch = mpatches.Patch(
                    facecolor=colors["black"],
                    alpha=0.65,
                    hatch="//",
                    edgecolor=highlight_color,
                    label="Acceptance window",
                )
    # Threshold line (soft gray, dotted)
    ax.axhline(
        y=ACCEPTANCE_THRESHOLD, color=colors["dark_gray"], linestyle="dotted", linewidth=2, zorder=2
    )
    # Threshold label (soft gray)
    ax.text(
        days[-1],
        ACCEPTANCE_THRESHOLD - 1000,
        "Threshold",
        color=colors["dark_gray"],
        fontsize=12,
        ha="right",
        va="top",
        fontweight="bold",
    )

    # Minimal axes
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(theme["yaxis.linecolor"])
    ax.spines["bottom"].set_color(theme["xaxis.linecolor"])

    # Set tick parameters with custom colors
    ax.tick_params(
        left=True,
        bottom=True,
        labelleft=True,
        labelbottom=True,
    )

    # Set tick label colors separately
    ax.tick_params(axis="x", labelcolor=theme["xtick.labelcolor"], colors=theme["xtick.labelcolor"])
    ax.tick_params(axis="y", labelcolor=theme["ytick.labelcolor"], colors=theme["ytick.labelcolor"])

    ax.set_ylabel(
        "Support",
        fontsize=theme["yaxis.labelsize"],
        labelpad=10,
        color=theme["xaxis.labelcolor"],
    )
    ax.set_xticks(np.linspace(0, 90, 7))
    ax.margins(x=0, y=0)

    # => Title
    ax.set_title(
        title,
        loc="left",
        fontsize=theme["title.labelsize"],
        fontweight="bold",
        color=colors["black"],
        pad=20,
    )
    ax.set_xlabel(
        "Time", fontsize=theme["xaxis.labelsize"], labelpad=10, color=theme["xaxis.labelcolor"]
    )

    # => Add legend for acceptance window if needed
    handles, labels = ax.get_legend_handles_labels()
    if acceptance_patch is not None:
        handles.append(acceptance_patch)
        labels.append("Acceptance window")
    ax.legend(handles, labels, loc="upper right", fontsize=13, frameon=False)

    # => Create buffer for acceptance window label
    y_max = max(total_support.max(), ACCEPTANCE_THRESHOLD)
    ax.set_ylim(0, y_max * 1.15)

    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close()


def plot_weight_duration_curves():
    """Plot weight vs duration curves for different exponent values."""
    # Parameters
    T = 100  # Fixed token amount
    durations = np.linspace(1, 100, 500)  # Duration in days
    k_values = [1.0, 1.1, 1.2, 1.3]  # Exponent values to plot

    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot each curve
    for i, k in enumerate(k_values):
        weight = T * durations**k
        ax.plot(
            durations,
            weight,
            label=f"k={k}",
            linewidth=2,
            solid_capstyle="round",
        )

    # Minimal axes styling
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(theme["yaxis.linecolor"])
    ax.spines["bottom"].set_color(theme["xaxis.linecolor"])

    # Set tick parameters with custom colors
    ax.tick_params(
        left=True,
        bottom=True,
        labelleft=True,
        labelbottom=True,
    )

    # Set tick label colors
    ax.tick_params(axis="x", labelcolor=theme["xtick.labelcolor"], colors=theme["xtick.labelcolor"])
    ax.tick_params(axis="y", labelcolor=theme["ytick.labelcolor"], colors=theme["ytick.labelcolor"])

    # Labels with consistent styling
    ax.set_xlabel(
        "Lock Duration (Epochs)",
        fontsize=theme["xaxis.labelsize"],
        labelpad=10,
        color=theme["xaxis.labelcolor"],
    )
    ax.set_ylabel(
        "Starting Amount of Support",
        fontsize=theme["yaxis.labelsize"],
        labelpad=10,
        color=theme["yaxis.labelcolor"],
    )

    # Title
    ax.set_title(
        "Example k values",
        loc="left",
        fontsize=theme["title.labelsize"],
        fontweight="bold",
        color=colors["black"],
        pad=20,
    )

    # Grid with subtle styling
    ax.grid(True, color=colors["light_gray"], alpha=0.5, linewidth=0.8)

    # Legend
    ax.legend(loc="upper left", fontsize=13, frameon=False)

    # Margins
    ax.margins(x=0.02, y=0.02)

    plt.tight_layout()
    plt.savefig("weight_duration_curves.png", dpi=150)
    plt.close()


# Generate all three scenarios with different highlight colors
plot_scenario(
    scenario_a_locks,
    "Quick Strong Support",
    "scenario_a_quick_support.png",
    highlight_color=theme["highlight"],
)
plot_scenario(
    scenario_b_locks,
    "Low Wavering Support",
    "scenario_b_low_wavering_support.png",
    highlight_color=theme["highlight"],
)
plot_scenario(
    scenario_c_locks,
    "Late Acceptance Support",
    "scenario_c_late_acceptance_support.png",
    highlight_color=theme["highlight"],
)
plot_scenario(
    scenario_d_locks,
    "Micro Coalition",
    "scenario_d_micro_coalition.png",
    highlight_color=theme["highlight"],
)

# Generate the weight vs duration curves plot
plot_weight_duration_curves()
