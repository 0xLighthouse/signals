import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# Minimal, modern style
colors = {
    "gray": "#9E9E9E",
    "light_gray": "#DFDFDF",
    "dark_gray": "#848484",
    "black": "#040404",
    "orange": "#FF5B00",
}

theme = {
    "yaxis.labelcolor": colors["gray"],
    "yaxis.linecolor": colors["light_gray"],
    "yaxis.labelsize": 16,
    "xaxis.labelcolor": colors["light_gray"],
    "xaxis.linecolor": colors["light_gray"],
    "xaxis.labelsize": 16,
    "title.labelsize": 18,
    "highlight": colors["orange"],
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
days = np.arange(0, 365)
ACCEPTANCE_THRESHOLD = 25000


# Helper to generate exponential decay
def generate_exp_decay_curve(weight, start, decay_rate):
    curve = np.zeros_like(days, dtype=float)
    for i, day in enumerate(days):
        if day >= start:
            curve[i] = weight * (decay_rate ** (day - start))
    return curve


# Scenario definitions
scenario_a_locks = [
    {"weight": 9000, "start": 0, "rate": 0.995},
    {"weight": 8000, "start": 2, "rate": 0.995},
    {"weight": 7000, "start": 4, "rate": 0.995},
    {"weight": 6000, "start": 6, "rate": 0.995},
    {"weight": 5000, "start": 8, "rate": 0.995},
]
scenario_b_locks = [
    {"weight": 4000, "start": 0, "rate": 0.98},
    {"weight": 3500, "start": 17, "rate": 0.98},
    {"weight": 3000, "start": 41, "rate": 0.98},
    {"weight": 5000, "start": 65, "rate": 0.98},
    {"weight": 2000, "start": 110, "rate": 0.98},
    {"weight": 2500, "start": 150, "rate": 0.98},
    {"weight": 1800, "start": 200, "rate": 0.98},
    {"weight": 2200, "start": 240, "rate": 0.98},
    {"weight": 1200, "start": 290, "rate": 0.98},
    {"weight": 900, "start": 340, "rate": 0.98},
]
scenario_c_locks = [
    {"weight": 4000, "start": 0, "rate": 0.99},
    {"weight": 3500, "start": 10, "rate": 0.99},
    {"weight": 3000, "start": 20, "rate": 0.99},
    {"weight": 12000, "start": 250, "rate": 0.995},
    {"weight": 8000, "start": 270, "rate": 0.995},
]


def plot_scenario(locks, title, filename, highlight_color="#FF5B00"):
    weights_matrix = []
    for lock in locks:
        weights_matrix.append(generate_exp_decay_curve(lock["weight"], lock["start"], lock["rate"]))
    weights_matrix = np.array(weights_matrix)
    total_support = np.sum(weights_matrix, axis=0)

    fig, ax = plt.subplots(figsize=(12, 6))
    # Stacked area (mid-tones)
    ax.stackplot(days, weights_matrix, alpha=0.85, edgecolor="none")

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
    # Threshold line (soft gray, dotted)
    ax.axhline(
        y=ACCEPTANCE_THRESHOLD, color=colors["gray"], linestyle="dotted", linewidth=2, zorder=2
    )
    # Threshold label (soft gray)
    ax.text(
        days[-1],
        ACCEPTANCE_THRESHOLD + 1000,
        "Threshold",
        color=colors["light_gray"],
        fontsize=12,
        ha="right",
        va="bottom",
        fontweight="bold",
    )
    # Threshold crossing marker (brand color)
    threshold_crossed = np.where(total_support >= ACCEPTANCE_THRESHOLD)[0]
    if len(threshold_crossed) > 0:
        first_cross = threshold_crossed[0]
        ax.plot(
            days[first_cross],
            total_support[first_cross],
            "o",
            color=highlight_color,
            markersize=14,
            zorder=4,
        )
        ax.annotate(
            f"Threshold crossed\n(day {days[first_cross]})",
            xy=(days[first_cross], total_support[first_cross]),
            xytext=(days[first_cross] + 20, total_support[first_cross] + 3000),
            arrowprops=dict(arrowstyle="->", color=highlight_color, lw=2),
            fontsize=14,
            color=highlight_color,
            fontweight="bold",
        )
    # Minimal axes
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(theme["yaxis.linecolor"])
    ax.spines["bottom"].set_color(theme["xaxis.linecolor"])
    ax.tick_params(
        left=True, bottom=False, labelleft=True, labelbottom=True, colors=theme["yaxis.labelcolor"]
    )
    ax.set_ylabel(
        "Weight",
        fontsize=theme["yaxis.labelsize"],
        labelpad=10,
        color=theme["yaxis.labelcolor"],
    )
    ax.set_xticks(np.linspace(0, 360, 6))
    ax.margins(x=0, y=0)
    # Title
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
    # Remove legend for minimalism
    ax.legend().set_visible(False)
    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close()


# Generate all three scenarios with different highlight colors
plot_scenario(
    scenario_a_locks,
    "Scenario A: Quick Strong Support",
    "scenario_a_quick_support.png",
    highlight_color=theme["highlight"],
)
plot_scenario(
    scenario_b_locks,
    "Scenario B: Minimal Tapering Support",
    "scenario_b_minimal_support.png",
    highlight_color=theme["highlight"],
)
plot_scenario(
    scenario_c_locks,
    "Scenario C: Late Acceptance Support",
    "scenario_c_late_support.png",
    highlight_color=theme["highlight"],
)
