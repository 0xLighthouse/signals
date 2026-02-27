"""
Tests for backtesting.data.schema — Governor event models, enums, and Protocol.

Covers: DATA-01 (Governor-compatible event schema), DATA-06 (Pydantic v2 rejects
malformed events at construction time).
"""

import pandas as pd
import pytest
from pydantic import ValidationError

from backtesting.data.schema import (
    EventType,
    GovernorDataLoader,
    GovernorEvent,
    ProposalCreatedEvent,
    ProposalFinalizedEvent,
    VoteCastEvent,
    VoteSupport,
)


class TestEventModelsExist:
    """DATA-01: Governor-compatible event schema defines all 3 event types."""

    def test_event_models_exist(self):
        """All three event model classes are importable with expected fields."""
        # ProposalCreatedEvent fields
        assert 'event_type' in ProposalCreatedEvent.model_fields
        assert 'block_number' in ProposalCreatedEvent.model_fields
        assert 'proposal_id' in ProposalCreatedEvent.model_fields
        assert 'proposer' in ProposalCreatedEvent.model_fields
        assert 'start_block' in ProposalCreatedEvent.model_fields
        assert 'end_block' in ProposalCreatedEvent.model_fields
        assert 'description' in ProposalCreatedEvent.model_fields
        assert 'quorum' in ProposalCreatedEvent.model_fields

        # VoteCastEvent fields
        assert 'event_type' in VoteCastEvent.model_fields
        assert 'block_number' in VoteCastEvent.model_fields
        assert 'proposal_id' in VoteCastEvent.model_fields
        assert 'voter' in VoteCastEvent.model_fields
        assert 'support' in VoteCastEvent.model_fields
        assert 'weight' in VoteCastEvent.model_fields
        assert 'lock_duration_days' in VoteCastEvent.model_fields
        assert 'unix_timestamp' in VoteCastEvent.model_fields

        # ProposalFinalizedEvent fields
        assert 'event_type' in ProposalFinalizedEvent.model_fields
        assert 'block_number' in ProposalFinalizedEvent.model_fields
        assert 'proposal_id' in ProposalFinalizedEvent.model_fields
        assert 'passed' in ProposalFinalizedEvent.model_fields
        assert 'unix_timestamp' in ProposalFinalizedEvent.model_fields

    def test_governor_event_union_exists(self):
        """GovernorEvent union type is importable."""
        # Union type exists — verify it's a type alias (not None)
        assert GovernorEvent is not None


class TestEnumValues:
    """EventType and VoteSupport enums have the correct values."""

    def test_event_type_values(self):
        assert EventType.PROPOSAL_CREATED.value == 'PROPOSAL_CREATED'
        assert EventType.VOTE_CAST.value == 'VOTE_CAST'
        assert EventType.PROPOSAL_FINALIZED.value == 'PROPOSAL_FINALIZED'
        assert len(list(EventType)) == 3

    def test_vote_support_values(self):
        assert VoteSupport.FOR.value == 'FOR'
        assert VoteSupport.AGAINST.value == 'AGAINST'
        assert VoteSupport.ABSTAIN.value == 'ABSTAIN'
        assert len(list(VoteSupport)) == 3

    def test_event_type_is_str_enum(self):
        """EventType extends str for serialization compatibility."""
        assert isinstance(EventType.VOTE_CAST, str)

    def test_vote_support_is_str_enum(self):
        """VoteSupport extends str for serialization compatibility."""
        assert isinstance(VoteSupport.FOR, str)


class TestProposalCreatedEventValid:
    """Construction and field access for valid ProposalCreatedEvent."""

    def test_proposal_created_valid(self):
        event = ProposalCreatedEvent(
            block_number=1000,
            proposal_id='prop-1',
            proposer='0xABCDEF',
            start_block=1010,
            end_block=2000,
        )
        assert event.block_number == 1000
        assert event.proposal_id == 'prop-1'
        assert event.proposer == '0xABCDEF'
        assert event.start_block == 1010
        assert event.end_block == 2000
        assert event.description == ''
        assert event.quorum == 0
        assert event.event_type == EventType.PROPOSAL_CREATED

    def test_proposal_created_with_all_fields(self):
        event = ProposalCreatedEvent(
            block_number=500,
            proposal_id='prop-xyz',
            proposer='0x1234',
            start_block=510,
            end_block=1000,
            description='Increase treasury allocation',
            quorum=1000000,
        )
        assert event.description == 'Increase treasury allocation'
        assert event.quorum == 1000000


class TestVoteCastEventValid:
    """Construction and field access for valid VoteCastEvent."""

    def test_vote_cast_for(self):
        event = VoteCastEvent(
            block_number=1500,
            proposal_id='prop-1',
            voter='0xVOTER1',
            support=VoteSupport.FOR,
            weight=5000.0,
        )
        assert event.support == VoteSupport.FOR
        assert event.weight == 5000.0
        assert event.lock_duration_days == 0.0
        assert event.unix_timestamp is None

    def test_vote_cast_against(self):
        event = VoteCastEvent(
            block_number=1600,
            proposal_id='prop-1',
            voter='0xVOTER2',
            support=VoteSupport.AGAINST,
            weight=3000.0,
            lock_duration_days=90.0,
        )
        assert event.support == VoteSupport.AGAINST
        assert event.lock_duration_days == 90.0

    def test_vote_cast_abstain(self):
        event = VoteCastEvent(
            block_number=1700,
            proposal_id='prop-1',
            voter='0xVOTER3',
            support=VoteSupport.ABSTAIN,
            weight=100.0,
            lock_duration_days=180.0,
            unix_timestamp=1700000000,
        )
        assert event.support == VoteSupport.ABSTAIN
        assert event.unix_timestamp == 1700000000

    def test_vote_cast_support_str_coercion(self):
        """VoteSupport accepts string values (str enum coercion)."""
        event = VoteCastEvent(
            block_number=1800,
            proposal_id='prop-2',
            voter='0xVOTER4',
            support='FOR',
            weight=1000.0,
        )
        assert event.support == VoteSupport.FOR


class TestProposalFinalizedEventValid:
    """Construction and field access for valid ProposalFinalizedEvent."""

    def test_proposal_finalized_passed(self):
        event = ProposalFinalizedEvent(
            block_number=2001,
            proposal_id='prop-1',
            passed=True,
        )
        assert event.passed is True
        assert event.unix_timestamp is None
        assert event.event_type == EventType.PROPOSAL_FINALIZED

    def test_proposal_finalized_failed(self):
        event = ProposalFinalizedEvent(
            block_number=2001,
            proposal_id='prop-2',
            passed=False,
            unix_timestamp=1700001000,
        )
        assert event.passed is False
        assert event.unix_timestamp == 1700001000


class TestValidationRejectsBadEvents:
    """DATA-06: Pydantic rejects malformed events at construction time."""

    def test_rejects_invalid_support_value(self):
        """VoteCastEvent with invalid support string raises ValidationError."""
        with pytest.raises(ValidationError):
            VoteCastEvent(
                block_number=100,
                proposal_id='p1',
                voter='0x00',
                support='INVALID',
                weight=500.0,
            )

    def test_rejects_negative_weight(self):
        """VoteCastEvent with negative weight raises ValidationError."""
        with pytest.raises(ValidationError):
            VoteCastEvent(
                block_number=100,
                proposal_id='p1',
                voter='0x00',
                support='FOR',
                weight=-100.0,
            )

    def test_rejects_end_block_before_start_block(self):
        """ProposalCreatedEvent with end_block <= start_block raises ValidationError."""
        with pytest.raises(ValidationError):
            ProposalCreatedEvent(
                block_number=100,
                proposal_id='p1',
                proposer='0xPROP',
                start_block=500,
                end_block=499,  # before start
            )

    def test_rejects_end_block_equal_to_start_block(self):
        """ProposalCreatedEvent with end_block == start_block raises ValidationError."""
        with pytest.raises(ValidationError):
            ProposalCreatedEvent(
                block_number=100,
                proposal_id='p1',
                proposer='0xPROP',
                start_block=500,
                end_block=500,  # equal — must be strictly after
            )

    def test_rejects_negative_block_number(self):
        """ProposalCreatedEvent with negative block_number raises ValidationError."""
        with pytest.raises(ValidationError):
            ProposalCreatedEvent(
                block_number=-1,
                proposal_id='p1',
                proposer='0xPROP',
                start_block=10,
                end_block=100,
            )

    def test_rejects_negative_lock_duration_days(self):
        """VoteCastEvent with negative lock_duration_days raises ValidationError."""
        with pytest.raises(ValidationError):
            VoteCastEvent(
                block_number=100,
                proposal_id='p1',
                voter='0x00',
                support='FOR',
                weight=500.0,
                lock_duration_days=-10.0,
            )


class TestDefaultValues:
    """Verify default values are correctly set for optional fields."""

    def test_quorum_defaults_to_zero(self):
        event = ProposalCreatedEvent(
            block_number=100,
            proposal_id='p1',
            proposer='0xPROP',
            start_block=110,
            end_block=200,
        )
        assert event.quorum == 0

    def test_description_defaults_to_empty_string(self):
        event = ProposalCreatedEvent(
            block_number=100,
            proposal_id='p1',
            proposer='0xPROP',
            start_block=110,
            end_block=200,
        )
        assert event.description == ''

    def test_lock_duration_days_defaults_to_zero(self):
        event = VoteCastEvent(
            block_number=100,
            proposal_id='p1',
            voter='0xVOTER',
            support='FOR',
            weight=1000.0,
        )
        assert event.lock_duration_days == 0.0

    def test_unix_timestamp_defaults_to_none(self):
        event = VoteCastEvent(
            block_number=100,
            proposal_id='p1',
            voter='0xVOTER',
            support='FOR',
            weight=1000.0,
        )
        assert event.unix_timestamp is None


class TestProtocolRuntimeCheckable:
    """GovernorDataLoader Protocol is runtime-checkable via isinstance."""

    def test_protocol_is_runtime_checkable(self):
        """Class with load() -> DataFrame satisfies GovernorDataLoader Protocol."""
        class DummyLoader:
            def load(self) -> pd.DataFrame:
                return pd.DataFrame()

        loader = DummyLoader()
        assert isinstance(loader, GovernorDataLoader)

    def test_class_without_load_fails_protocol_check(self):
        """Class without load() method does not satisfy protocol."""
        class NotALoader:
            pass

        obj = NotALoader()
        assert not isinstance(obj, GovernorDataLoader)

    def test_protocol_without_inheritance(self):
        """No inheritance needed — structural typing works."""
        class RealDataLoader:
            """Completely separate class, no import of GovernorDataLoader."""
            def load(self) -> pd.DataFrame:
                return pd.DataFrame({'event_type': ['VOTE_CAST']})

        loader = RealDataLoader()
        # Structural typing: isinstance works without inheritance
        assert isinstance(loader, GovernorDataLoader)


class TestModelDump:
    """model_dump() produces plain dicts compatible with cadCAD M params."""

    def test_proposal_created_model_dump(self):
        event = ProposalCreatedEvent(
            block_number=100,
            proposal_id='p1',
            proposer='0xPROP',
            start_block=110,
            end_block=200,
        )
        d = event.model_dump()
        assert isinstance(d, dict)
        assert d['proposal_id'] == 'p1'
        assert d['block_number'] == 100
        assert d['quorum'] == 0

    def test_vote_cast_model_dump(self):
        event = VoteCastEvent(
            block_number=150,
            proposal_id='p1',
            voter='0xVOTER',
            support=VoteSupport.FOR,
            weight=2000.0,
            lock_duration_days=90.0,
        )
        d = event.model_dump()
        assert isinstance(d, dict)
        assert d['weight'] == 2000.0
        assert d['lock_duration_days'] == 90.0

    def test_proposal_finalized_model_dump(self):
        event = ProposalFinalizedEvent(
            block_number=300,
            proposal_id='p1',
            passed=True,
        )
        d = event.model_dump()
        assert isinstance(d, dict)
        assert d['passed'] is True
        assert d['unix_timestamp'] is None

    def test_model_dump_produces_plain_dict_not_pydantic(self):
        """model_dump() output must be a plain dict, not a Pydantic model."""
        event = VoteCastEvent(
            block_number=100,
            proposal_id='p1',
            voter='0xVOTER',
            support='AGAINST',
            weight=100.0,
        )
        d = event.model_dump()
        assert type(d) is dict  # exact type, not subclass
