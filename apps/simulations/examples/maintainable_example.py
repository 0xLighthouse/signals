#!/usr/bin/env python3
"""
Example demonstrating the new maintainable architecture.

This example shows how the refactored codebase would work with:
- Centralized configuration
- Modular SUFs
- Modular visualization
- Better error handling and logging
"""

import sys
import os
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from cadcad.config import Config, SimulationConfig, VisualizationConfig
from cadcad.sufs.base import SUFBase, log_action, log_epoch_transition
from visualization.base import ChartBase, ColorPalette, DataProcessor


# Example: Creating a new SUF with the maintainable architecture
class ExampleUserActionSUF(SUFBase):
    """Example SUF showing the new architecture pattern."""

    def execute(self, params, substep, state_history, previous_state, policy_input):
        """Execute the SUF with clean, maintainable code."""
        # Use the common state reconstruction utility
        state = self.get_state_obj(previous_state)

        # Use consistent logging
        log_action(state.current_epoch, "process", "Processing user actions")

        # Your business logic here
        actions = policy_input.get("user_actions", [])
        processed_count = 0

        for action in actions:
            if action.get("type") == "example_action":
                # Process the action
                processed_count += 1
                log_action(
                    state.current_epoch,
                    "create",
                    f"Processed example action for user {action.get('user_id')}",
                )

        # Return in cadCAD-compatible format
        return ("processed_actions_count", processed_count)


# Example: Creating a new chart with the maintainable architecture
class ExampleChart(ChartBase):
    """Example chart showing the new architecture pattern."""

    @property
    def chart_name(self) -> str:
        return "example_chart"

    @property
    def default_figsize(self) -> tuple:
        return (12, 8)

    def create(self, df, summary):
        """Create chart with consistent styling and utilities."""
        # Use the base class utilities
        fig = self.setup_figure()
        ax = fig.add_subplot(111)

        # Use data processing utilities
        processed_df = DataProcessor.add_derived_columns(df, summary)
        epoch_data = DataProcessor.group_by_epoch(processed_df, {"processed_actions_count": "sum"})

        # Use consistent colors
        colors = ColorPalette.get_status_colors()

        # Create the plot
        ax.plot(
            epoch_data["current_epoch"],
            epoch_data["processed_actions_count"],
            color=colors["accepted"],
            linewidth=2,
            marker="o",
        )

        # Use consistent styling utilities
        self.add_grid(ax)
        ax.set_xlabel("Epoch")
        ax.set_ylabel("Processed Actions")
        ax.set_title("Example Chart: Actions Processed Over Time")

        return fig


def demonstrate_configuration():
    """Demonstrate the centralized configuration system."""
    print("🔧 Configuration System Demo")
    print("=" * 40)

    # Create custom configuration
    config = Config()
    config.simulation.num_epochs = 5
    config.simulation.acceptance_threshold = 500.0
    config.visualization.figure_dpi = 150

    print(f"Simulation epochs: {config.simulation.num_epochs}")
    print(f"Acceptance threshold: {config.simulation.acceptance_threshold}")
    print(f"Visualization DPI: {config.visualization.figure_dpi}")

    # Convert to cadCAD parameters
    cadcad_params = config.simulation.to_cadcad_params()
    print(f"\nCadCAD parameters: {cadcad_params['M']['acceptance_threshold']}")

    # Environment variable override example
    os.environ["SIM_NUM_EPOCHS"] = "15"
    env_config = Config.load_from_env()
    print(f"From environment: {env_config.simulation.num_epochs} epochs")


def demonstrate_suf_architecture():
    """Demonstrate the modular SUF architecture."""
    print("\n🏗️ SUF Architecture Demo")
    print("=" * 40)

    # Example state and policy input
    mock_state = {
        "current_epoch": 1,
        "initiatives": {},
        "supporters": {},
        "current_time": "2025-01-01T00:00:00",
        "balances": {"user1": 1000, "user2": 2000},
        "circulating_supply": 100000,
        "accepted_initiatives": set(),
        "expired_initiatives": set(),
    }

    mock_policy_input = {
        "user_actions": [
            {"type": "example_action", "user_id": "user1"},
            {"type": "example_action", "user_id": "user2"},
        ]
    }

    # Create and execute SUF
    suf = ExampleUserActionSUF()
    result = suf.execute({}, 1, [], mock_state, mock_policy_input)

    print(f"SUF result: {result}")
    print("✅ SUF executed successfully with clean architecture")


def demonstrate_visualization_architecture():
    """Demonstrate the modular visualization architecture."""
    print("\n📊 Visualization Architecture Demo")
    print("=" * 40)

    # Mock data
    import pandas as pd

    mock_df = pd.DataFrame(
        {
            "current_epoch": [0, 1, 2, 3],
            "processed_actions_count": [0, 2, 5, 3],
            "circulating_supply": [100000, 99000, 98000, 97000],
        }
    )

    mock_summary = {"token_statistics": {"total_supply": 100000}}

    # Create chart
    chart = ExampleChart()
    print(f"Chart name: {chart.chart_name}")
    print(f"Default figure size: {chart.default_figsize}")

    # In a real scenario, you would call chart.create(mock_df, mock_summary)
    print("✅ Chart architecture demonstrated (plotting skipped in example)")


def demonstrate_error_handling():
    """Demonstrate improved error handling."""
    print("\n🚨 Error Handling Demo")
    print("=" * 40)

    try:
        # Example of robust error handling in state reconstruction
        invalid_state = {
            "initiatives": {
                "init1": "invalid_data"  # This should be a dict
            }
        }

        suf = ExampleUserActionSUF()
        state = suf.get_state_obj(invalid_state)

    except TypeError as e:
        print(f"✅ Caught expected error with clear message: {e}")

    # Example of consistent logging
    print("\n📝 Logging Examples:")
    log_action(1, "create", "User created new initiative")
    log_action(1, "support", "User supported initiative with 1000 tokens")
    log_action(1, "accept", "Initiative reached acceptance threshold")


def main():
    """Main demonstration function."""
    print("🎯 Maintainable Architecture Demonstration")
    print("=" * 50)

    demonstrate_configuration()
    demonstrate_suf_architecture()
    demonstrate_visualization_architecture()
    demonstrate_error_handling()

    print("\n🎉 Architecture Benefits Summary:")
    print("✅ Centralized configuration management")
    print("✅ Modular, testable SUF components")
    print("✅ Consistent visualization framework")
    print("✅ Improved error handling and logging")
    print("✅ Clear separation of concerns")
    print("✅ Easy to extend and maintain")

    print("\n📚 Next Steps:")
    print("1. Migrate existing SUFs to new architecture")
    print("2. Implement modular visualization components")
    print("3. Update tests for new structure")
    print("4. Add configuration file support")


if __name__ == "__main__":
    main()
