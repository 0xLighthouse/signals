"""
backtesting.data — Governor-compatible event schema and data loader protocol.
"""

from backtesting.data.schema import (
    EventType,
    VoteSupport,
    ProposalCreatedEvent,
    VoteCastEvent,
    ProposalFinalizedEvent,
    GovernorEvent,
    GovernorDataLoader,
)

__all__ = [
    'EventType',
    'VoteSupport',
    'ProposalCreatedEvent',
    'VoteCastEvent',
    'ProposalFinalizedEvent',
    'GovernorEvent',
    'GovernorDataLoader',
]
