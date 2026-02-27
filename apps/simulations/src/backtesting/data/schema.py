"""
Governor-compatible event schema — Pydantic v2 models, enums, and Protocol.

Defines the three Governor event types (PROPOSAL_CREATED, VOTE_CAST,
PROPOSAL_FINALIZED) as validated Pydantic v2 models with Governor Bravo
field names. Also defines the GovernorDataLoader Protocol that all data
loaders (synthetic and real) must implement.

Usage:
    from backtesting.data.schema import (
        EventType, VoteSupport,
        ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent,
        GovernorEvent, GovernorDataLoader,
    )
"""

from enum import Enum
from typing import Literal, Optional, Protocol, runtime_checkable

import pandas as pd
from pydantic import BaseModel, field_validator, model_validator


class EventType(str, Enum):
    """Governor event types matching Governor Bravo event names."""
    PROPOSAL_CREATED = 'PROPOSAL_CREATED'
    VOTE_CAST = 'VOTE_CAST'
    PROPOSAL_FINALIZED = 'PROPOSAL_FINALIZED'


class VoteSupport(str, Enum):
    """Governor Bravo tri-state vote support values."""
    FOR = 'FOR'
    AGAINST = 'AGAINST'
    ABSTAIN = 'ABSTAIN'


class ProposalCreatedEvent(BaseModel):
    """
    Governor event emitted when a proposal is created.

    Fields follow Governor Bravo naming conventions. The event_type
    Literal discriminator enables automatic union dispatch.
    """
    event_type: Literal[EventType.PROPOSAL_CREATED] = EventType.PROPOSAL_CREATED
    block_number: int
    proposal_id: str
    proposer: str
    start_block: int
    end_block: int
    description: str = ''
    quorum: int = 0  # 0 = no quorum required

    @field_validator('block_number', 'start_block', 'end_block')
    @classmethod
    def block_numbers_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError('block numbers must be non-negative')
        return v

    @model_validator(mode='after')
    def end_after_start(self) -> 'ProposalCreatedEvent':
        if self.end_block <= self.start_block:
            raise ValueError('end_block must be after start_block')
        return self


class VoteCastEvent(BaseModel):
    """
    Governor event emitted when a vote is cast.

    Includes lock_duration_days embedded directly on the event (not in a
    separate table) for self-contained event records compatible with
    cadCAD event-replay pattern.
    """
    event_type: Literal[EventType.VOTE_CAST] = EventType.VOTE_CAST
    block_number: int
    proposal_id: str
    voter: str
    support: VoteSupport
    weight: float           # raw token stake at time of vote
    lock_duration_days: float = 0.0   # 0.0 for non-locked (legacy-compatible)
    unix_timestamp: Optional[int] = None

    @field_validator('weight')
    @classmethod
    def weight_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError('weight must be non-negative')
        return v

    @field_validator('lock_duration_days')
    @classmethod
    def lock_duration_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError('lock_duration_days must be non-negative')
        return v


class ProposalFinalizedEvent(BaseModel):
    """
    Governor event emitted when a proposal is finalized (passed or failed).
    """
    event_type: Literal[EventType.PROPOSAL_FINALIZED] = EventType.PROPOSAL_FINALIZED
    block_number: int
    proposal_id: str
    passed: bool
    unix_timestamp: Optional[int] = None


# Union type for all Governor events — Python 3.10+ union syntax
GovernorEvent = ProposalCreatedEvent | VoteCastEvent | ProposalFinalizedEvent


@runtime_checkable
class GovernorDataLoader(Protocol):
    """
    Contract for all data loaders — synthetic and real data must implement this.

    Uses structural typing (Protocol) so real data loaders do not need to
    inherit from this class. Any class with a compatible load() method
    satisfies isinstance(loader, GovernorDataLoader).

    Example:
        class MyRealLoader:
            def load(self) -> pd.DataFrame:
                return pd.read_parquet('/data/governor.parquet')

        loader = MyRealLoader()
        assert isinstance(loader, GovernorDataLoader)  # True
    """

    def load(self) -> pd.DataFrame:
        """
        Load and return all events as a sorted DataFrame.

        Returns:
            DataFrame sorted by block_number with all event types.
            Consumers MUST filter by event_type before accessing
            type-specific columns (NaN propagation otherwise).
        """
        ...
