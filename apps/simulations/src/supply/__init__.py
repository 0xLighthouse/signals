"""
Token Distributions Module

This module provides utilities for generating various token distributions
and allocating tokens to users for testing governance systems under
different wealth inequality scenarios.
"""

from .allocate import allocate_tokens
from .distributions import (
    TokenDistributionGenerator,
    create_distribution_test_suite,
)

__all__ = [
    "allocate_tokens",
    "TokenDistributionGenerator",
    "create_distribution_test_suite",
]
