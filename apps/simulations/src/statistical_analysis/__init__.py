"""
Statistical Analysis Package for Signals Governance Simulation

This package provides comprehensive statistical analysis capabilities for
evaluating governance system performance across different configurations.

Key Features:
- Multi-dimensional parameter sweeps
- Statistical significance testing
- Governance quality metrics
- Comparative analysis across token distributions
- Hypothesis testing for governance properties
"""

from .experiment_runner import ExperimentRunner, ExperimentConfig
from .metrics import GovernanceMetrics, StatisticalTests
from supply import TokenDistributionGenerator
from .visualization import GovernanceVisualizer, plot_experiment_results, quick_plot

__all__ = [
    "ExperimentRunner",
    "ExperimentConfig",
    "GovernanceMetrics",
    "StatisticalTests",
    "TokenDistributionGenerator",
    "GovernanceVisualizer",
    "plot_experiment_results",
    "quick_plot",
]
