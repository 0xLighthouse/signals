"""
Token Distribution Generator

This module provides utilities for generating various token distributions
to test governance system behavior under different wealth inequality scenarios.
"""

import numpy as np
from typing import Dict, List, Any, Optional

# Removed import to avoid circular dependency - generate_initial_state will be called from outside
from .allocate import allocate_tokens


class TokenDistributionGenerator:
    """Generate various token distributions for testing governance systems."""

    def generate_state(
        self,
        num_users: int,
        total_supply: int,
        distribution_config: Dict[str, Any],
        random_seed: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Generate initial state with specified token distribution."""
        if random_seed is not None:
            np.random.seed(random_seed)

        distribution_type = distribution_config.get("type", "equal")

        if distribution_type == "equal":
            return self._generate_equal_distribution(num_users, total_supply)
        elif distribution_type == "pareto":
            return self._generate_pareto_distribution(num_users, total_supply, distribution_config)
        elif distribution_type == "custom":
            return self._generate_custom_distribution(num_users, total_supply, distribution_config)
        elif distribution_type == "normal":
            return self._generate_normal_distribution(num_users, total_supply, distribution_config)
        elif distribution_type == "bimodal":
            return self._generate_bimodal_distribution(num_users, total_supply, distribution_config)
        else:
            raise ValueError(f"Unknown distribution type: {distribution_type}")

    def _generate_equal_distribution(self, num_users: int, total_supply: int) -> Dict[str, Any]:
        """Generate equal token distribution."""
        # Generate user IDs
        user_ids = [f"0x{i:02x}" for i in range(num_users)]

        # Use allocate_tokens for equal distribution
        circulating_supply = int(total_supply * 0.1)  # 10% circulating
        balances = allocate_tokens(
            user_ids=user_ids,
            total_supply=circulating_supply,
            circulating_supply=circulating_supply,
            distribution=None,  # None means equal distribution
            randomize=False,
        )

        return self._create_initial_state(balances, total_supply, circulating_supply)

    def _generate_pareto_distribution(
        self, num_users: int, total_supply: int, config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate Pareto (power law) distribution."""
        alpha = config.get("alpha", 1.16)  # 1.16 ≈ 80/20 rule

        # Generate user IDs
        user_ids = [f"0x{i:02x}" for i in range(num_users)]

        # Generate Pareto distribution
        # Lower alpha = more inequality
        pareto_values = np.random.pareto(alpha, num_users)

        # Normalize to total supply
        total_pareto = np.sum(pareto_values)
        circulating_supply = int(total_supply * 0.1)  # 10% circulating

        balances = {}
        for i, user_id in enumerate(user_ids):
            balance = int((pareto_values[i] / total_pareto) * circulating_supply)
            balances[user_id] = max(1, balance)  # Ensure minimum balance

        # Adjust for rounding errors
        current_total = sum(balances.values())
        if current_total != circulating_supply:
            # Adjust the largest balance
            largest_user = max(balances.keys(), key=lambda k: balances[k])
            balances[largest_user] += circulating_supply - current_total

        return self._create_initial_state(balances, total_supply, circulating_supply)

    def _generate_custom_distribution(
        self, num_users: int, total_supply: int, config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate custom distribution where X% of users control Y% of tokens."""
        control_percent_users = config.get("control_percent_users", 20)
        control_percent_tokens = config.get("control_percent_tokens", 80)

        # Generate user IDs
        user_ids = [f"0x{i:02x}" for i in range(num_users)]

        # Use the existing allocate_tokens function
        circulating_supply = int(total_supply * 0.1)  # 10% circulating
        distribution = [control_percent_users, control_percent_tokens]

        balances = allocate_tokens(
            user_ids=user_ids,
            total_supply=circulating_supply,
            circulating_supply=circulating_supply,
            distribution=distribution,
            randomize=True,
        )

        return self._create_initial_state(balances, total_supply, circulating_supply)

    def _generate_normal_distribution(
        self, num_users: int, total_supply: int, config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate normal (Gaussian) distribution."""
        mean = config.get("mean", 0.5)
        std = config.get("std", 0.2)

        # Generate user IDs
        user_ids = [f"0x{i:02x}" for i in range(num_users)]

        # Generate normal distribution (truncated to positive values)
        normal_values = np.random.normal(mean, std, num_users)
        normal_values = np.abs(normal_values)  # Ensure positive

        # Normalize to total supply
        total_normal = np.sum(normal_values)
        circulating_supply = int(total_supply * 0.1)  # 10% circulating

        balances = {}
        for i, user_id in enumerate(user_ids):
            balance = int((normal_values[i] / total_normal) * circulating_supply)
            balances[user_id] = max(1, balance)  # Ensure minimum balance

        # Adjust for rounding errors
        current_total = sum(balances.values())
        if current_total != circulating_supply:
            largest_user = max(balances.keys(), key=lambda k: balances[k])
            balances[largest_user] += circulating_supply - current_total

        return self._create_initial_state(balances, total_supply, circulating_supply)

    def _generate_bimodal_distribution(
        self, num_users: int, total_supply: int, config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate bimodal distribution (two distinct groups)."""
        rich_ratio = config.get("rich_ratio", 0.2)  # 20% are "rich"
        rich_mean = config.get("rich_mean", 0.8)
        poor_mean = config.get("poor_mean", 0.2)
        std = config.get("std", 0.1)

        # Generate user IDs
        user_ids = [f"0x{i:02x}" for i in range(num_users)]

        # Determine which users are "rich"
        num_rich = int(num_users * rich_ratio)
        rich_indices = np.random.choice(num_users, num_rich, replace=False)

        # Generate bimodal distribution
        values = np.zeros(num_users)
        for i in range(num_users):
            if i in rich_indices:
                values[i] = np.random.normal(rich_mean, std)
            else:
                values[i] = np.random.normal(poor_mean, std)

        values = np.abs(values)  # Ensure positive

        # Normalize to total supply
        total_values = np.sum(values)
        circulating_supply = int(total_supply * 0.1)  # 10% circulating

        balances = {}
        for i, user_id in enumerate(user_ids):
            balance = int((values[i] / total_values) * circulating_supply)
            balances[user_id] = max(1, balance)  # Ensure minimum balance

        # Adjust for rounding errors
        current_total = sum(balances.values())
        if current_total != circulating_supply:
            largest_user = max(balances.keys(), key=lambda k: balances[k])
            balances[largest_user] += circulating_supply - current_total

        return self._create_initial_state(balances, total_supply, circulating_supply)

    def _create_initial_state(
        self, balances: Dict[str, int], total_supply: int, circulating_supply: int
    ) -> Dict[str, Any]:
        """Create initial state dictionary with given balances."""
        from datetime import datetime

        return {
            "balances": balances,
            "total_supply": total_supply,
            "circulating_supply": circulating_supply,
            "initiatives": {},
            "supporters": {},
            "accepted_initiatives": set(),
            "expired_initiatives": set(),
            "current_epoch": 0,
            "current_time": datetime.now(),
            # Default governance parameters (can be overridden)
            "acceptance_threshold": 1000.0,
            "inactivity_period": 10,
            "decay_multiplier": 0.95,
            "initiative_creation_stake": 10.0,
        }

    @staticmethod
    def calculate_gini_coefficient(values: List[float]) -> float:
        """Calculate Gini coefficient for a distribution."""
        if len(values) == 0:
            return 0

        # Remove negative values and sort
        values = [max(0, v) for v in values]
        values = sorted(values)
        n = len(values)

        if n == 0 or sum(values) == 0:
            return 0

        # Calculate Gini coefficient
        cumsum = np.cumsum(values)
        return (n + 1 - 2 * sum((n + 1 - i) * y for i, y in enumerate(values, 1))) / (
            n * sum(values)
        )

    @staticmethod
    def analyze_distribution(balances: Dict[str, int]) -> Dict[str, float]:
        """Analyze properties of a token distribution."""
        values = list(balances.values())

        if not values:
            return {}

        total_tokens = sum(values)
        num_users = len(values)

        # Sort for percentile calculations
        sorted_values = sorted(values, reverse=True)

        # Calculate percentiles
        top_1_percent = int(max(1, num_users * 0.01))
        top_5_percent = int(max(1, num_users * 0.05))
        top_10_percent = int(max(1, num_users * 0.10))
        top_20_percent = int(max(1, num_users * 0.20))

        return {
            "gini_coefficient": TokenDistributionGenerator.calculate_gini_coefficient(values),
            "mean_balance": np.mean(values),
            "median_balance": np.median(values),
            "std_balance": np.std(values),
            "min_balance": min(values),
            "max_balance": max(values),
            "top_1_percent_share": sum(sorted_values[:top_1_percent]) / total_tokens,
            "top_5_percent_share": sum(sorted_values[:top_5_percent]) / total_tokens,
            "top_10_percent_share": sum(sorted_values[:top_10_percent]) / total_tokens,
            "top_20_percent_share": sum(sorted_values[:top_20_percent]) / total_tokens,
            "bottom_50_percent_share": sum(sorted_values[num_users // 2 :]) / total_tokens,
        }


def create_distribution_test_suite() -> List[Dict[str, Any]]:
    """Create a comprehensive suite of token distributions for testing."""
    return [
        # Equal distribution (baseline)
        {
            "type": "equal",
            "description": "Equal distribution (baseline)",
            "expected_gini": 0.0,
        },
        # Pareto distributions (varying inequality)
        {
            "type": "pareto",
            "alpha": 2.0,
            "description": "Pareto distribution (low inequality)",
            "expected_gini": 0.3,
        },
        {
            "type": "pareto",
            "alpha": 1.16,
            "description": "Pareto distribution (80/20 rule)",
            "expected_gini": 0.6,
        },
        {
            "type": "pareto",
            "alpha": 0.8,
            "description": "Pareto distribution (high inequality)",
            "expected_gini": 0.8,
        },
        # Custom distributions
        {
            "type": "custom",
            "control_percent_users": 5,
            "control_percent_tokens": 50,
            "description": "5% control 50% (moderate concentration)",
        },
        {
            "type": "custom",
            "control_percent_users": 10,
            "control_percent_tokens": 75,
            "description": "10% control 75% (high concentration)",
        },
        {
            "type": "custom",
            "control_percent_users": 1,
            "control_percent_tokens": 90,
            "description": "1% control 90% (extreme concentration)",
        },
        {
            "type": "custom",
            "control_percent_users": 25,
            "control_percent_tokens": 60,
            "description": "25% control 60% (moderate inequality)",
        },
        # Normal distributions
        {
            "type": "normal",
            "mean": 0.5,
            "std": 0.1,
            "description": "Normal distribution (low variance)",
        },
        {
            "type": "normal",
            "mean": 0.5,
            "std": 0.3,
            "description": "Normal distribution (high variance)",
        },
        # Bimodal distributions
        {
            "type": "bimodal",
            "rich_ratio": 0.1,
            "rich_mean": 0.8,
            "poor_mean": 0.2,
            "std": 0.05,
            "description": "Bimodal (10% rich, 90% poor)",
        },
        {
            "type": "bimodal",
            "rich_ratio": 0.3,
            "rich_mean": 0.7,
            "poor_mean": 0.3,
            "std": 0.1,
            "description": "Bimodal (30% rich, 70% poor)",
        },
    ]
