"""
Centralized configuration management for the cadCAD simulation.

This module provides a single source of truth for all simulation parameters,
making it easy to modify behavior without hunting through multiple files.
"""

from dataclasses import dataclass, field
from typing import Dict, Any, Optional
import os
from pathlib import Path


@dataclass
class SimulationConfig:
    """Main simulation configuration."""

    # Time parameters
    num_epochs: int = 10
    num_monte_carlo_runs: int = 1

    # User parameters
    num_users: int = 50
    randomize_balances: bool = True

    # Token parameters
    total_supply: int = 1_000_000
    initiative_creation_stake: float = 10.0

    # Governance parameters
    acceptance_threshold: float = 1000.0
    decay_multiplier: float = 0.95
    inactivity_period: int = 10

    # User behavior parameters
    prob_create_initiative: float = 0.08
    prob_support_initiative: float = 0.2
    max_support_tokens_fraction: float = 0.5
    min_lock_duration_epochs: int = 5
    max_lock_duration_epochs: int = 20

    # Output parameters
    results_dir: str = "results"
    enable_debug_logging: bool = True
    save_raw_results: bool = True
    save_visualizations: bool = True

    def to_cadcad_params(self) -> Dict[str, Any]:
        """Convert to cadCAD-compatible parameter dictionary."""
        return {
            "T": range(self.num_epochs),
            "N": self.num_monte_carlo_runs,
            "M": {
                "acceptance_threshold": self.acceptance_threshold,
                "decay_multiplier": self.decay_multiplier,
                "initiative_creation_stake": self.initiative_creation_stake,
                "prob_create_initiative": self.prob_create_initiative,
                "prob_support_initiative": self.prob_support_initiative,
                "max_support_tokens_fraction": self.max_support_tokens_fraction,
                "min_lock_duration_epochs": self.min_lock_duration_epochs,
                "max_lock_duration_epochs": self.max_lock_duration_epochs,
                "inactivity_period": self.inactivity_period,
            },
        }

    def to_initial_state_params(self) -> Dict[str, Any]:
        """Convert to initial state generation parameters."""
        return {
            "num_users": self.num_users,
            "total_supply": self.total_supply,
            "randomize": self.randomize_balances,
        }


@dataclass
class VisualizationConfig:
    """Configuration for visualization generation."""

    # Chart parameters
    figure_dpi: int = 300
    figure_format: str = "png"
    style: str = "seaborn-v0_8"
    color_palette: str = "husl"

    # Chart sizes
    timeline_figsize: tuple = (12, 10)
    governance_figsize: tuple = (15, 10)
    user_behavior_figsize: tuple = (15, 6)
    token_flux_figsize: tuple = (16, 8)

    # Output parameters
    output_dir: str = "results/visualizations"
    save_analysis_report: bool = True
    show_plots: bool = True


@dataclass
class TestConfig:
    """Configuration for testing."""

    # Test data parameters
    test_num_users: int = 5
    test_total_supply: int = 10000
    test_num_epochs: int = 3

    # Test behavior
    enable_test_logging: bool = False
    use_fixed_random_seed: bool = True
    random_seed: int = 42


@dataclass
class Config:
    """Master configuration container."""

    simulation: SimulationConfig = field(default_factory=SimulationConfig)
    visualization: VisualizationConfig = field(default_factory=VisualizationConfig)
    testing: TestConfig = field(default_factory=TestConfig)

    @classmethod
    def load_from_env(cls) -> "Config":
        """Load configuration from environment variables."""
        config = cls()

        # Simulation config from env
        if os.getenv("SIM_NUM_EPOCHS"):
            config.simulation.num_epochs = int(os.getenv("SIM_NUM_EPOCHS"))
        if os.getenv("SIM_NUM_USERS"):
            config.simulation.num_users = int(os.getenv("SIM_NUM_USERS"))
        if os.getenv("SIM_TOTAL_SUPPLY"):
            config.simulation.total_supply = int(os.getenv("SIM_TOTAL_SUPPLY"))
        if os.getenv("SIM_ACCEPTANCE_THRESHOLD"):
            config.simulation.acceptance_threshold = float(os.getenv("SIM_ACCEPTANCE_THRESHOLD"))
        if os.getenv("SIM_DECAY_MULTIPLIER"):
            config.simulation.decay_multiplier = float(os.getenv("SIM_DECAY_MULTIPLIER"))

        # Visualization config from env
        if os.getenv("VIZ_OUTPUT_DIR"):
            config.visualization.output_dir = os.getenv("VIZ_OUTPUT_DIR")
        if os.getenv("VIZ_DPI"):
            config.visualization.figure_dpi = int(os.getenv("VIZ_DPI"))

        return config

    @classmethod
    def load_from_file(cls, config_path: str) -> "Config":
        """Load configuration from a file (future enhancement)."""
        # TODO: Implement YAML/JSON config file loading
        raise NotImplementedError("File-based config loading not yet implemented")

    def save_to_file(self, config_path: str) -> None:
        """Save configuration to a file (future enhancement)."""
        # TODO: Implement config file saving
        raise NotImplementedError("Config file saving not yet implemented")


# Global configuration instance
_config: Optional[Config] = None


def get_config() -> Config:
    """Get the global configuration instance."""
    global _config
    if _config is None:
        _config = Config.load_from_env()
    return _config


def set_config(config: Config) -> None:
    """Set the global configuration instance."""
    global _config
    _config = config


def reset_config() -> None:
    """Reset configuration to defaults."""
    global _config
    _config = None


# Convenience functions for common config access
def get_simulation_config() -> SimulationConfig:
    """Get simulation configuration."""
    return get_config().simulation


def get_visualization_config() -> VisualizationConfig:
    """Get visualization configuration."""
    return get_config().visualization


def get_test_config() -> TestConfig:
    """Get test configuration."""
    return get_config().testing
