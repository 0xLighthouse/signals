"""
backtesting.data — Governor-compatible event schema, synthetic factory, and data loaders.
"""

from backtesting.data.factory import (
    LockProfile,
    StakeProfile,
    generate_scenario,
)
from backtesting.data.loader import (
    ParquetLoader,
    SyntheticLoader,
    events_to_dataframe,
    validate_event_stream,
)
from backtesting.data.schema import (
    EventType,
    GovernorDataLoader,
    GovernorEvent,
    ProposalCreatedEvent,
    ProposalFinalizedEvent,
    VoteCastEvent,
    VoteSupport,
)

__all__ = [
    # Schema
    'EventType',
    'VoteSupport',
    'ProposalCreatedEvent',
    'VoteCastEvent',
    'ProposalFinalizedEvent',
    'GovernorEvent',
    'GovernorDataLoader',
    # Factory
    'generate_scenario',
    'StakeProfile',
    'LockProfile',
    # Loader
    'SyntheticLoader',
    'ParquetLoader',
    'events_to_dataframe',
    'validate_event_stream',
]
