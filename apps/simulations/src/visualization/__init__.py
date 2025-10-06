"""
Modular visualization package for cadCAD simulation results.

This package organizes visualization functionality into logical modules:
- data_loader: Loading and preprocessing simulation data
- charts: Individual chart generation functions
- analysis: Analysis report generation
- main: Main visualization orchestration
"""

from .data_loader import SimulationDataLoader
from .charts import (
    TimelineChart,
    GovernanceMetricsChart,
    UserBehaviorChart,
    TokenFluxChart,
)
from .analysis import AnalysisReportGenerator
from .main import VisualizationPipeline

__all__ = [
    "SimulationDataLoader",
    "TimelineChart",
    "GovernanceMetricsChart",
    "UserBehaviorChart",
    "TokenFluxChart",
    "AnalysisReportGenerator",
    "VisualizationPipeline",
]
