"""
Experiment Runner for Statistical Analysis

This module provides the main framework for running comprehensive experiments
to test governance system properties across different configurations.
"""

import json
import os
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple, Iterator
from concurrent.futures import ProcessPoolExecutor, as_completed
import itertools
import numpy as np
import pandas as pd

from cadcad.model import run_simulation
from cadcad.state import generate_initial_state
from cadcad.helpers import results_to_dataframe
from supply import TokenDistributionGenerator
from .metrics import GovernanceMetrics


@dataclass
class ExperimentConfig:
    """Configuration for statistical experiments."""

    # Experiment metadata
    name: str
    description: str

    # Simulation parameters to sweep
    parameter_sweeps: Dict[str, List[Any]] = field(default_factory=dict)

    # Token distribution configurations
    token_distributions: List[Dict[str, Any]] = field(default_factory=list)

    # Statistical configuration
    num_monte_carlo_runs: int = 50
    confidence_level: float = 0.95

    # Simulation configuration
    num_epochs: int = 50
    num_users: int = 100
    total_supply: int = 1_000_000

    # Output configuration
    output_dir: str = "experiments"
    save_raw_data: bool = True
    parallel_execution: bool = True
    max_workers: Optional[int] = None


class ExperimentRunner:
    """Main class for running comprehensive statistical experiments."""

    def __init__(self, config: ExperimentConfig):
        self.config = config
        self.results: List[Dict[str, Any]] = []
        self.metrics_calculator = GovernanceMetrics()
        self.distribution_generator = TokenDistributionGenerator()

        # Create output directory
        os.makedirs(config.output_dir, exist_ok=True)

    def generate_experiment_matrix(self) -> List[Dict[str, Any]]:
        """Generate all parameter combinations for the experiment."""
        # Get all parameter combinations
        param_names = list(self.config.parameter_sweeps.keys())
        param_values = list(self.config.parameter_sweeps.values())
        param_combinations = list(itertools.product(*param_values))

        experiment_matrix = []

        for param_combo in param_combinations:
            param_dict = dict(zip(param_names, param_combo))

            for dist_config in self.config.token_distributions:
                for run_id in range(self.config.num_monte_carlo_runs):
                    experiment = {
                        "experiment_id": len(experiment_matrix),
                        "run_id": run_id,
                        "parameters": param_dict.copy(),
                        "distribution_config": dist_config.copy(),
                        "random_seed": np.random.randint(0, 2**32 - 1),
                    }
                    experiment_matrix.append(experiment)

        return experiment_matrix

    def run_single_experiment(self, experiment: Dict[str, Any]) -> Dict[str, Any]:
        """Run a single experiment configuration."""
        start_time = time.time()

        # Set random seed for reproducibility
        np.random.seed(experiment["random_seed"])

        try:
            # Generate initial state with specified distribution
            initial_state = self.distribution_generator.generate_state(
                num_users=self.config.num_users,
                total_supply=self.config.total_supply,
                distribution_config=experiment["distribution_config"],
                random_seed=experiment["random_seed"],
            )

            # Update initial state with experiment parameters
            initial_state.update(experiment["parameters"])

            # Run simulation with specified number of epochs
            results = run_simulation(initial_state=initial_state, num_epochs=self.config.num_epochs)

            # Calculate metrics
            df = results_to_dataframe(results)
            metrics = self.metrics_calculator.calculate_all_metrics(results, df)

            # Prepare result
            result = {
                "experiment_id": experiment["experiment_id"],
                "run_id": experiment["run_id"],
                "parameters": experiment["parameters"],
                "distribution_config": experiment["distribution_config"],
                "metrics": metrics,
                "execution_time": time.time() - start_time,
                "success": True,
                "error": None,
            }

            if self.config.save_raw_data:
                result["raw_results"] = results
                result["dataframe"] = df.to_dict("records")

            return result

        except Exception as e:
            return {
                "experiment_id": experiment["experiment_id"],
                "run_id": experiment["run_id"],
                "parameters": experiment["parameters"],
                "distribution_config": experiment["distribution_config"],
                "metrics": {},
                "execution_time": time.time() - start_time,
                "success": False,
                "error": str(e),
            }

    def run_experiments(self) -> pd.DataFrame:
        """Run all experiments and return results as DataFrame."""
        print(f"🧪 Starting experiment: {self.config.name}")
        print(f"📊 Description: {self.config.description}")

        # Generate experiment matrix
        experiments = self.generate_experiment_matrix()
        total_experiments = len(experiments)

        print(f"🔬 Generated {total_experiments} experiment configurations")
        print(
            f"   - Parameter combinations: {len(list(itertools.product(*self.config.parameter_sweeps.values())))}"
        )
        print(f"   - Token distributions: {len(self.config.token_distributions)}")
        print(f"   - Monte Carlo runs per config: {self.config.num_monte_carlo_runs}")

        start_time = time.time()

        if self.config.parallel_execution:
            # Run experiments in parallel
            max_workers = self.config.max_workers or min(32, os.cpu_count() + 4)
            print(f"🚀 Running experiments in parallel with {max_workers} workers")

            with ProcessPoolExecutor(max_workers=max_workers) as executor:
                # Submit all experiments
                future_to_experiment = {
                    executor.submit(self.run_single_experiment, exp): exp for exp in experiments
                }

                # Collect results as they complete
                completed = 0
                for future in as_completed(future_to_experiment):
                    result = future.result()
                    self.results.append(result)
                    completed += 1

                    if completed % 10 == 0 or completed == total_experiments:
                        elapsed = time.time() - start_time
                        rate = completed / elapsed
                        eta = (total_experiments - completed) / rate if rate > 0 else 0
                        print(
                            f"   Progress: {completed}/{total_experiments} ({completed / total_experiments:.1%}) "
                            f"- Rate: {rate:.1f}/s - ETA: {eta:.0f}s"
                        )
        else:
            # Run experiments sequentially
            print("🐌 Running experiments sequentially")
            for i, experiment in enumerate(experiments):
                result = self.run_single_experiment(experiment)
                self.results.append(result)

                if (i + 1) % 10 == 0 or (i + 1) == total_experiments:
                    elapsed = time.time() - start_time
                    rate = (i + 1) / elapsed
                    eta = (total_experiments - i - 1) / rate if rate > 0 else 0
                    print(
                        f"   Progress: {i + 1}/{total_experiments} ({(i + 1) / total_experiments:.1%}) "
                        f"- Rate: {rate:.1f}/s - ETA: {eta:.0f}s"
                    )

        total_time = time.time() - start_time
        success_rate = sum(1 for r in self.results if r["success"]) / len(self.results)

        print(f"✅ Experiments completed in {total_time:.1f}s")
        print(f"📈 Success rate: {success_rate:.1%}")

        # Convert results to DataFrame
        results_df = self._results_to_dataframe()

        # Save results
        self._save_results(results_df)

        return results_df

    def _results_to_dataframe(self) -> pd.DataFrame:
        """Convert experiment results to a structured DataFrame."""
        rows = []

        for result in self.results:
            # Flatten the result structure
            row = {
                "experiment_id": result["experiment_id"],
                "run_id": result["run_id"],
                "success": result["success"],
                "execution_time": result["execution_time"],
                "error": result["error"],
            }

            # Add parameters
            for param, value in result["parameters"].items():
                row[f"param_{param}"] = value

            # Add distribution config
            for key, value in result["distribution_config"].items():
                row[f"dist_{key}"] = value

            # Add metrics
            for metric, value in result["metrics"].items():
                row[f"metric_{metric}"] = value

            rows.append(row)

        return pd.DataFrame(rows)

    def _save_results(self, results_df: pd.DataFrame) -> None:
        """Save experiment results to files."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_filename = f"{self.config.name}_{timestamp}"

        # Save DataFrame as CSV
        csv_path = os.path.join(self.config.output_dir, f"{base_filename}.csv")
        results_df.to_csv(csv_path, index=False)
        print(f"📊 Results saved to: {csv_path}")

        # Save configuration
        config_path = os.path.join(self.config.output_dir, f"{base_filename}_config.json")
        config_dict = {
            "name": self.config.name,
            "description": self.config.description,
            "parameter_sweeps": self.config.parameter_sweeps,
            "token_distributions": self.config.token_distributions,
            "num_monte_carlo_runs": self.config.num_monte_carlo_runs,
            "confidence_level": self.config.confidence_level,
            "num_epochs": self.config.num_epochs,
            "num_users": self.config.num_users,
            "total_supply": self.config.total_supply,
            "timestamp": timestamp,
        }

        with open(config_path, "w") as f:
            json.dump(config_dict, f, indent=2)
        print(f"⚙️  Configuration saved to: {config_path}")

        # Save raw results if requested
        if self.config.save_raw_data:
            raw_path = os.path.join(self.config.output_dir, f"{base_filename}_raw.json")
            with open(raw_path, "w") as f:
                json.dump(self.results, f, indent=2, default=str)
            print(f"📁 Raw results saved to: {raw_path}")


def create_governance_experiment() -> ExperimentConfig:
    """Create a comprehensive governance experiment configuration."""
    return ExperimentConfig(
        name="governance_comprehensive",
        description="Comprehensive analysis of governance system properties across token distributions",
        parameter_sweeps={
            "acceptance_threshold": [1000, 5000, 10000, 25000],
            "decay_multiplier": [0.90, 0.95, 0.98],
            "prob_create_initiative": [0.05, 0.10, 0.15],
            "prob_support_initiative": [0.15, 0.25, 0.35],
            "max_support_tokens_fraction": [0.3, 0.5, 0.8],
        },
        token_distributions=[
            {"type": "equal", "description": "Equal distribution"},
            {"type": "pareto", "alpha": 1.16, "description": "Pareto 80/20"},
            {"type": "pareto", "alpha": 0.96, "description": "Pareto 90/10"},
            {
                "type": "custom",
                "control_percent_users": 10,
                "control_percent_tokens": 50,
                "description": "10% control 50%",
            },
            {
                "type": "custom",
                "control_percent_users": 5,
                "control_percent_tokens": 75,
                "description": "5% control 75%",
            },
            {
                "type": "custom",
                "control_percent_users": 25,
                "control_percent_tokens": 60,
                "description": "25% control 60%",
            },
        ],
        num_monte_carlo_runs=30,
        confidence_level=0.95,
        num_epochs=75,
        num_users=150,
        total_supply=1_000_000,
    )
