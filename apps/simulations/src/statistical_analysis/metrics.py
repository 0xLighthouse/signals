"""
Governance Metrics for Statistical Analysis

This module provides comprehensive metrics to evaluate governance system
performance, specifically focusing on the four key attributes:
1. Capturing voter preference intensity
2. Opportunity cost as sufficient risk
3. Locking mechanisms improving sybil resistance
4. Empowering smaller voting blocks increases inclusivity
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Any, Tuple, Optional
from scipy import stats
from scipy.stats import entropy
import warnings


class GovernanceMetrics:
    """Calculate comprehensive governance quality metrics."""

    def calculate_all_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """Calculate all governance metrics for a simulation run."""
        if not results or df.empty:
            return {}

        metrics = {}

        # Basic simulation metrics
        metrics.update(self._calculate_basic_metrics(results, df))

        # Voter preference intensity metrics
        metrics.update(self._calculate_preference_intensity_metrics(results, df))

        # Opportunity cost metrics
        metrics.update(self._calculate_opportunity_cost_metrics(results, df))

        # Sybil resistance metrics
        metrics.update(self._calculate_sybil_resistance_metrics(results, df))

        # Inclusivity metrics
        metrics.update(self._calculate_inclusivity_metrics(results, df))

        # System efficiency metrics
        metrics.update(self._calculate_efficiency_metrics(results, df))

        return metrics

    def _calculate_basic_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """Calculate basic simulation performance metrics."""
        final_state = results[-1]

        total_initiatives = len(final_state.get("initiatives", {}))
        accepted_initiatives = len(final_state.get("accepted_initiatives", set()))
        expired_initiatives = len(final_state.get("expired_initiatives", set()))

        return {
            "total_initiatives": total_initiatives,
            "accepted_initiatives": accepted_initiatives,
            "expired_initiatives": expired_initiatives,
            "acceptance_rate": accepted_initiatives / total_initiatives
            if total_initiatives > 0
            else 0,
            "expiration_rate": expired_initiatives / total_initiatives
            if total_initiatives > 0
            else 0,
            "final_epoch": final_state.get("current_epoch", 0),
            "simulation_length": len(results),
        }

    def _calculate_preference_intensity_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """
        Calculate metrics for voter preference intensity capture.

        Key insight: The system should allow users to express varying levels of
        preference intensity through different support amounts and lock durations.
        """
        metrics = {}

        # Analyze support patterns across all timesteps
        all_supports = []
        support_amounts = []
        lock_durations = []

        for state in results:
            locks = state.get("locks", {})
            for support_key, support_data in locks.items():
                if isinstance(support_data, dict):
                    amount = support_data.get("amount", 0)
                    duration = support_data.get("lock_duration_epochs", 0)

                    all_supports.append(
                        {
                            "amount": amount,
                            "duration": duration,
                            "weight": amount * duration,
                            "user_id": support_key[0]
                            if isinstance(support_key, tuple)
                            else support_key,
                        }
                    )
                    support_amounts.append(amount)
                    lock_durations.append(duration)

        if all_supports:
            support_df = pd.DataFrame(all_supports)

            # Variance in support amounts (higher = more preference intensity expression)
            metrics["support_amount_variance"] = np.var(support_amounts) if support_amounts else 0
            metrics["support_amount_cv"] = (
                np.std(support_amounts) / np.mean(support_amounts)
                if support_amounts and np.mean(support_amounts) > 0
                else 0
            )

            # Variance in lock durations (higher = more temporal preference expression)
            metrics["lock_duration_variance"] = np.var(lock_durations) if lock_durations else 0
            metrics["lock_duration_cv"] = (
                np.std(lock_durations) / np.mean(lock_durations)
                if lock_durations and np.mean(lock_durations) > 0
                else 0
            )

            # Weight distribution analysis (captures combined intensity)
            weights = support_df["weight"].values
            metrics["weight_variance"] = np.var(weights) if len(weights) > 0 else 0
            metrics["weight_gini"] = (
                self._calculate_gini_coefficient(weights) if len(weights) > 0 else 0
            )

            # Preference intensity score (composite metric)
            # Higher values indicate better preference intensity capture
            amount_norm = metrics["support_amount_cv"]
            duration_norm = metrics["lock_duration_cv"]
            metrics["preference_intensity_score"] = (amount_norm + duration_norm) / 2

        else:
            # No supports found
            for key in [
                "support_amount_variance",
                "support_amount_cv",
                "lock_duration_variance",
                "lock_duration_cv",
                "weight_variance",
                "weight_gini",
                "preference_intensity_score",
            ]:
                metrics[key] = 0

        return metrics

    def _calculate_opportunity_cost_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """
        Calculate metrics for opportunity cost as sufficient risk.

        Key insight: Locking tokens should create meaningful opportunity cost
        that prevents frivolous participation while enabling genuine commitment.
        """
        metrics = {}

        # Analyze token locking patterns
        locked_token_ratios = []
        user_lock_ratios = []

        for state in results:
            total_supply = state.get("total_supply", 0)
            circulating_supply = state.get("circulating_supply", 0)
            locked_tokens = total_supply - circulating_supply

            if total_supply > 0:
                locked_ratio = locked_tokens / total_supply
                locked_token_ratios.append(locked_ratio)

            # Analyze individual user lock ratios
            balances = state.get("balances", {})
            locks = state.get("locks", {})

            user_locked = {}
            for support_key, support_data in locks.items():
                if isinstance(support_key, tuple) and isinstance(support_data, dict):
                    user_id = support_key[0]
                    amount = support_data.get("amount", 0)
                    user_locked[user_id] = user_locked.get(user_id, 0) + amount

            for user_id, balance in balances.items():
                locked_amount = user_locked.get(user_id, 0)
                total_user_tokens = balance + locked_amount
                if total_user_tokens > 0:
                    user_lock_ratio = locked_amount / total_user_tokens
                    user_lock_ratios.append(user_lock_ratio)

        if locked_token_ratios:
            metrics["avg_locked_token_ratio"] = np.mean(locked_token_ratios)
            metrics["max_locked_token_ratio"] = np.max(locked_token_ratios)
            metrics["locked_ratio_variance"] = np.var(locked_token_ratios)
        else:
            metrics["avg_locked_token_ratio"] = 0
            metrics["max_locked_token_ratio"] = 0
            metrics["locked_ratio_variance"] = 0

        if user_lock_ratios:
            metrics["avg_user_lock_ratio"] = np.mean(user_lock_ratios)
            metrics["user_lock_ratio_variance"] = np.var(user_lock_ratios)

            # Opportunity cost effectiveness score
            # Higher values indicate better opportunity cost mechanisms
            # Combines meaningful locking with user participation
            participation_rate = len([r for r in user_lock_ratios if r > 0]) / len(user_lock_ratios)
            avg_lock_ratio = metrics["avg_user_lock_ratio"]
            metrics["opportunity_cost_score"] = participation_rate * avg_lock_ratio
        else:
            metrics["avg_user_lock_ratio"] = 0
            metrics["user_lock_ratio_variance"] = 0
            metrics["opportunity_cost_score"] = 0

        return metrics

    def _calculate_sybil_resistance_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """
        Calculate metrics for sybil resistance through locking mechanisms.

        Key insight: Token locking should make sybil attacks economically unfeasible
        by requiring significant capital commitment over time.
        """
        metrics = {}

        # Analyze the relationship between token holdings and influence
        final_state = results[-1]
        balances = final_state.get("balances", {})
        supporters = final_state.get("supporters", {})

        # Calculate user influence (total weight contributed)
        user_influence = {}
        user_participation = {}

        for support_key, support_data in supporters.items():
            if isinstance(support_key, tuple) and isinstance(support_data, dict):
                user_id = support_key[0]
                weight = support_data.get("current_weight", 0)
                amount = support_data.get("amount", 0)

                user_influence[user_id] = user_influence.get(user_id, 0) + weight
                user_participation[user_id] = user_participation.get(user_id, 0) + amount

        if balances and user_influence:
            # Calculate correlation between holdings and influence
            holdings = []
            influences = []

            for user_id in balances.keys():
                total_holdings = balances[user_id] + user_participation.get(user_id, 0)
                influence = user_influence.get(user_id, 0)

                holdings.append(total_holdings)
                influences.append(influence)

            if len(holdings) > 1 and np.var(holdings) > 0 and np.var(influences) > 0:
                correlation = np.corrcoef(holdings, influences)[0, 1]
                metrics["holdings_influence_correlation"] = (
                    correlation if not np.isnan(correlation) else 0
                )
            else:
                metrics["holdings_influence_correlation"] = 0

            # Analyze influence concentration (Gini coefficient)
            if influences:
                metrics["influence_gini"] = self._calculate_gini_coefficient(influences)
                metrics["holdings_gini"] = self._calculate_gini_coefficient(holdings)

                # Sybil resistance score
                # Lower correlation + higher lock requirements = better sybil resistance
                lock_requirement = metrics.get("avg_user_lock_ratio", 0)
                correlation_penalty = abs(metrics["holdings_influence_correlation"])
                metrics["sybil_resistance_score"] = lock_requirement * (1 - correlation_penalty)
            else:
                metrics["influence_gini"] = 0
                metrics["holdings_gini"] = 0
                metrics["sybil_resistance_score"] = 0
        else:
            for key in [
                "holdings_influence_correlation",
                "influence_gini",
                "holdings_gini",
                "sybil_resistance_score",
            ]:
                metrics[key] = 0

        return metrics

    def _calculate_inclusivity_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """
        Calculate metrics for empowering smaller voting blocks.

        Key insight: The system should enable smaller token holders to have
        meaningful influence when they coordinate or show strong commitment.
        """
        metrics = {}

        final_state = results[-1]
        balances = final_state.get("balances", {})
        supporters = final_state.get("supporters", {})
        accepted_initiatives = final_state.get("accepted_initiatives", set())

        if not balances:
            return {
                key: 0
                for key in [
                    "small_holder_participation",
                    "small_holder_influence",
                    "successful_small_initiatives",
                    "inclusivity_score",
                ]
            }

        # Define small holders (bottom 50% by token holdings)
        total_holdings = {}
        for user_id, balance in balances.items():
            locked_amount = sum(
                support_data.get("amount", 0)
                for support_key, support_data in supporters.items()
                if isinstance(support_key, tuple)
                and support_key[0] == user_id
                and isinstance(support_data, dict)
            )
            total_holdings[user_id] = balance + locked_amount

        holdings_values = list(total_holdings.values())
        median_holdings = np.median(holdings_values) if holdings_values else 0
        small_holders = {
            user_id: holdings
            for user_id, holdings in total_holdings.items()
            if holdings <= median_holdings
        }

        # Calculate small holder participation rate
        small_holder_participants = set()
        for support_key in supporters.keys():
            if isinstance(support_key, tuple) and support_key[0] in small_holders:
                small_holder_participants.add(support_key[0])

        metrics["small_holder_participation"] = (
            len(small_holder_participants) / len(small_holders) if small_holders else 0
        )

        # Calculate small holder influence
        small_holder_total_influence = 0
        total_influence = 0

        for support_key, support_data in supporters.items():
            if isinstance(support_key, tuple) and isinstance(support_data, dict):
                user_id = support_key[0]
                weight = support_data.get("current_weight", 0)
                total_influence += weight

                if user_id in small_holders:
                    small_holder_total_influence += weight

        metrics["small_holder_influence"] = (
            small_holder_total_influence / total_influence if total_influence > 0 else 0
        )

        # Analyze initiatives created by small holders
        small_holder_initiatives = 0
        successful_small_initiatives = 0

        for state in results:
            initiatives = state.get("initiatives", {})
            for init_id, init_data in initiatives.items():
                # Note: We'd need to track initiative creators to fully implement this
                # For now, we'll estimate based on participation patterns
                pass

        # Placeholder for small holder initiative success
        metrics["successful_small_initiatives"] = 0  # Would need creator tracking

        # Inclusivity score (composite metric)
        # Higher values indicate better empowerment of smaller holders
        participation_component = metrics["small_holder_participation"]
        influence_component = metrics["small_holder_influence"]

        # Ideal scenario: small holders participate proportionally to their numbers
        expected_influence = len(small_holders) / len(total_holdings) if total_holdings else 0
        influence_ratio = influence_component / expected_influence if expected_influence > 0 else 0

        metrics["inclusivity_score"] = (participation_component + min(influence_ratio, 1.0)) / 2

        return metrics

    def _calculate_efficiency_metrics(
        self, results: List[Dict[str, Any]], df: pd.DataFrame
    ) -> Dict[str, float]:
        """Calculate system efficiency and performance metrics."""
        metrics = {}

        # Time to acceptance analysis
        acceptance_times = []
        initiative_lifespans = []

        for state in results:
            current_epoch = state.get("current_epoch", 0)
            initiatives = state.get("initiatives", {})
            accepted = state.get("accepted_initiatives", set())

            for init_id in accepted:
                if init_id in initiatives:
                    # Estimate creation time (would need better tracking)
                    acceptance_times.append(current_epoch)

        if acceptance_times:
            metrics["avg_acceptance_time"] = np.mean(acceptance_times)
            metrics["acceptance_time_variance"] = np.var(acceptance_times)
        else:
            metrics["avg_acceptance_time"] = 0
            metrics["acceptance_time_variance"] = 0

        # Token velocity (how often tokens are locked/unlocked)
        circulation_changes = []
        for i in range(1, len(results)):
            prev_circ = results[i - 1].get("circulating_supply", 0)
            curr_circ = results[i].get("circulating_supply", 0)
            if prev_circ > 0:
                change_rate = abs(curr_circ - prev_circ) / prev_circ
                circulation_changes.append(change_rate)

        metrics["avg_token_velocity"] = np.mean(circulation_changes) if circulation_changes else 0

        return metrics

    def _calculate_gini_coefficient(self, values: List[float]) -> float:
        """Calculate Gini coefficient for inequality measurement."""
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


class StatisticalTests:
    """Perform statistical significance tests on governance metrics."""

    @staticmethod
    def compare_distributions(
        group1: List[float], group2: List[float], test_type: str = "mannwhitney"
    ) -> Dict[str, float]:
        """Compare two distributions using statistical tests."""
        if len(group1) < 2 or len(group2) < 2:
            return {"statistic": 0, "p_value": 1.0, "significant": False}

        try:
            if test_type == "mannwhitney":
                statistic, p_value = stats.mannwhitneyu(group1, group2, alternative="two-sided")
            elif test_type == "ttest":
                statistic, p_value = stats.ttest_ind(group1, group2)
            elif test_type == "ks":
                statistic, p_value = stats.ks_2samp(group1, group2)
            else:
                raise ValueError(f"Unknown test type: {test_type}")

            return {
                "statistic": float(statistic),
                "p_value": float(p_value),
                "significant": p_value < 0.05,
            }
        except Exception as e:
            warnings.warn(f"Statistical test failed: {e}")
            return {"statistic": 0, "p_value": 1.0, "significant": False}

    @staticmethod
    def calculate_confidence_interval(
        values: List[float], confidence: float = 0.95
    ) -> Tuple[float, float]:
        """Calculate confidence interval for a list of values."""
        if len(values) < 2:
            return (0, 0)

        mean = np.mean(values)
        sem = stats.sem(values)
        h = sem * stats.t.ppf((1 + confidence) / 2.0, len(values) - 1)

        return (mean - h, mean + h)

    @staticmethod
    def effect_size_cohens_d(group1: List[float], group2: List[float]) -> float:
        """Calculate Cohen's d effect size."""
        if len(group1) < 2 or len(group2) < 2:
            return 0

        mean1, mean2 = np.mean(group1), np.mean(group2)
        std1, std2 = np.std(group1, ddof=1), np.std(group2, ddof=1)

        # Pooled standard deviation
        n1, n2 = len(group1), len(group2)
        pooled_std = np.sqrt(((n1 - 1) * std1**2 + (n2 - 1) * std2**2) / (n1 + n2 - 2))

        if pooled_std == 0:
            return 0

        return (mean1 - mean2) / pooled_std
