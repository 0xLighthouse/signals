import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

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


def plot_reverse_s_curve():
    """Plot reverse S curves showing diminishing returns for longer lock durations."""
    # Parameters
    T = 100  # Fixed token amount
    durations = np.linspace(1, 100, 500)  # Duration in days

    # Different steepness values for the sigmoid curves
    steepness_values = [0.05, 0.08, 0.12, 0.15]
    midpoint = 50  # Where the curve inflects

    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot each reverse S curve
    for i, steepness in enumerate(steepness_values):
        # Reverse sigmoid: starts high, decreases with diminishing returns
        # Using: weight = T * (1 + max_multiplier) / (1 + exp(steepness * (duration - midpoint)))
        max_multiplier = 10  # Maximum weight multiplier at duration = 1
        weight = T * (1 + max_multiplier) / (1 + np.exp(steepness * (durations - midpoint)))

        ax.plot(
            durations,
            weight,
            label=f"k={steepness}",
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
        "When support was added",
        fontsize=theme["xaxis.labelsize"],
        labelpad=10,
        color=theme["xaxis.labelcolor"],
    )
    ax.set_ylabel(
        "Share of rewards",
        fontsize=theme["yaxis.labelsize"],
        labelpad=10,
        color=theme["yaxis.labelcolor"],
    )

    # Title
    ax.set_title(
        "Early support earns more rewards",
        loc="left",
        fontsize=theme["title.labelsize"],
        fontweight="bold",
        color=colors["black"],
        pad=20,
    )

    # Grid with subtle styling
    ax.grid(True, color=colors["light_gray"], alpha=0.5, linewidth=0.8)

    # Legend
    ax.legend(loc="upper right", fontsize=13, frameon=False)

    # Margins
    ax.margins(x=0.05, y=0.05)

    plt.tight_layout()
    plt.savefig("reverse_s_curve.png", dpi=150)
    plt.close()


def plot_contribution_flow():
    """Generate a Mermaid flowchart for the contribution flow diagram."""

    mermaid_chart = """
flowchart TD
    A["👤 User Contributions<br/>(allowlisted tokens)"] --> B["🔒 Escrow Contract"]

    B --> C["🧱 80% Initiative"]
    B --> D["🧍 15% Tribute"]
    B --> E["⚙️ 5% Protocol Fee"]

    C --> F["✅ If Accepted"]
    E --> G["❌ If Expired"]

    F --> H["📤 Funds auto-distributed"]
    G --> I["💰 Funds refundable<br/>to contributor"]

    style A fill:#DFDFDF,stroke:#848484,stroke-width:2px
    style B fill:#FFE0B2,stroke:#FF5B00,stroke-width:2px
    style C fill:#E8F5E8,stroke:#4CAF50,stroke-width:2px
    style D fill:#E3F2FD,stroke:#2196F3,stroke-width:2px
    style E fill:#F3E5F5,stroke:#9C27B0,stroke-width:2px
    style F fill:#E8F5E8,stroke:#4CAF50,stroke-width:2px
    style G fill:#FFEBEE,stroke:#F44336,stroke-width:2px
    style H fill:#E8F5E8,stroke:#4CAF50,stroke-width:2px
    style I fill:#FFEBEE,stroke:#F44336,stroke-width:2px
"""

    # Save the Mermaid chart to a file
    with open("contribution_flow.mmd", "w") as f:
        f.write(mermaid_chart)

    print("Mermaid chart saved to contribution_flow.mmd")
    print("\nTo render this chart:")
    print("1. Copy the content to https://mermaid.live/")
    print("2. Or use mermaid-cli: mmdc -i contribution_flow.mmd -o contribution_flow.png")
    print("\nMermaid chart content:")
    print(mermaid_chart)


# Generate the reverse S curve plot
plot_reverse_s_curve()

# Generate the contribution flow diagram
plot_contribution_flow()
