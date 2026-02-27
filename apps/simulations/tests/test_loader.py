"""
Tests for the data loader layer — DATA-05 and DATA-09.

Covers:
  DATA-05: Loader rejects double votes, out-of-window votes, unknown proposals
  DATA-09: SyntheticLoader and ParquetLoader satisfy GovernorDataLoader Protocol
"""

import warnings

import pandas as pd
import pytest

from backtesting.data.factory import generate_scenario
from backtesting.data.loader import (
    ParquetLoader,
    SyntheticLoader,
    events_to_dataframe,
    validate_event_stream,
)
from backtesting.data.schema import (
    EventType,
    GovernorDataLoader,
    ProposalCreatedEvent,
    ProposalFinalizedEvent,
    VoteCastEvent,
    VoteSupport,
)


# ---------------------------------------------------------------------------
# DATA-09: Protocol compliance
# ---------------------------------------------------------------------------

def test_protocol_compliance(sample_events):
    """Both loaders structurally satisfy GovernorDataLoader Protocol."""
    loader = SyntheticLoader(sample_events)
    assert isinstance(loader, GovernorDataLoader), (
        'SyntheticLoader does not satisfy GovernorDataLoader'
    )
    pq_loader = ParquetLoader('/tmp/x.parquet')
    assert isinstance(pq_loader, GovernorDataLoader), (
        'ParquetLoader does not satisfy GovernorDataLoader'
    )

    # A class WITHOUT load() should NOT satisfy the Protocol
    class NoLoad:
        def fetch(self) -> pd.DataFrame:
            return pd.DataFrame()

    assert not isinstance(NoLoad(), GovernorDataLoader), (
        'Class without load() should not satisfy GovernorDataLoader'
    )


# ---------------------------------------------------------------------------
# DataFrame structure
# ---------------------------------------------------------------------------

def test_dataframe_structure(sample_events):
    """SyntheticLoader.load() returns DataFrame with expected columns and dtypes."""
    loader = SyntheticLoader(sample_events)
    df = loader.load()

    assert isinstance(df, pd.DataFrame)

    expected_columns = [
        'event_type', 'block_number', 'proposal_id', 'proposer',
        'start_block', 'end_block', 'quorum', 'voter', 'support',
        'weight', 'lock_duration_days', 'passed',
    ]
    for col in expected_columns:
        assert col in df.columns, f'Missing column: {col}'

    # block_number should be integer type
    vote_rows = df[df['event_type'] == EventType.VOTE_CAST.value]
    if not vote_rows.empty:
        assert pd.api.types.is_float_dtype(df['weight']) or pd.api.types.is_integer_dtype(df['weight']), (
            'weight column should be numeric'
        )
    # block_number is int
    assert pd.api.types.is_integer_dtype(df['block_number']), (
        'block_number should be integer dtype'
    )


# ---------------------------------------------------------------------------
# Sorted DataFrame
# ---------------------------------------------------------------------------

def test_dataframe_sorted(sample_events):
    """DataFrame is sorted by block_number."""
    loader = SyntheticLoader(sample_events)
    df = loader.load()
    assert df['block_number'].is_monotonic_increasing, (
        'DataFrame is not sorted by block_number'
    )


# ---------------------------------------------------------------------------
# DATA-05: Fail fast — double votes
# ---------------------------------------------------------------------------

def test_fail_fast_double_votes():
    """SyntheticLoader raises ValueError when event stream has double votes."""
    proposal = ProposalCreatedEvent(
        block_number=100,
        proposal_id='p-001',
        proposer='0x' + '0' * 40,
        start_block=110,
        end_block=200,
    )
    vote1 = VoteCastEvent(
        block_number=120,
        proposal_id='p-001',
        voter='0x' + 'a' * 40,
        support=VoteSupport.FOR,
        weight=100.0,
    )
    vote2 = VoteCastEvent(
        block_number=150,
        proposal_id='p-001',
        voter='0x' + 'a' * 40,  # same voter, same proposal
        support=VoteSupport.AGAINST,
        weight=100.0,
    )
    finalized = ProposalFinalizedEvent(
        block_number=201,
        proposal_id='p-001',
        passed=True,
    )
    loader = SyntheticLoader([proposal, vote1, vote2, finalized])
    with pytest.raises(ValueError, match='Double vote'):
        loader.load()


# ---------------------------------------------------------------------------
# DATA-05: Fail fast — out-of-window votes
# ---------------------------------------------------------------------------

def test_fail_fast_out_of_window():
    """SyntheticLoader raises ValueError for votes outside proposal window."""
    proposal = ProposalCreatedEvent(
        block_number=100,
        proposal_id='p-002',
        proposer='0x' + '0' * 40,
        start_block=110,
        end_block=200,
    )
    # Vote at block 50 — before start_block
    vote = VoteCastEvent(
        block_number=50,
        proposal_id='p-002',
        voter='0x' + 'b' * 40,
        support=VoteSupport.FOR,
        weight=50.0,
    )
    finalized = ProposalFinalizedEvent(
        block_number=201,
        proposal_id='p-002',
        passed=True,
    )
    loader = SyntheticLoader([proposal, vote, finalized])
    with pytest.raises(ValueError, match='outside window'):
        loader.load()


# ---------------------------------------------------------------------------
# DATA-05: Fail fast — unknown proposal
# ---------------------------------------------------------------------------

def test_fail_fast_unknown_proposal():
    """SyntheticLoader raises ValueError when a vote references an unknown proposal."""
    vote = VoteCastEvent(
        block_number=120,
        proposal_id='p-999',  # no PROPOSAL_CREATED for this ID
        voter='0x' + 'c' * 40,
        support=VoteSupport.FOR,
        weight=75.0,
    )
    loader = SyntheticLoader([vote])
    with pytest.raises(ValueError, match='unknown proposal_id'):
        loader.load()


# ---------------------------------------------------------------------------
# validate_event_stream clean
# ---------------------------------------------------------------------------

def test_validate_event_stream_clean(sample_events):
    """validate_event_stream returns empty list for valid factory output."""
    df = events_to_dataframe(sample_events)
    errors = validate_event_stream(df)
    assert errors == [], f'Unexpected validation errors: {errors}'


# ---------------------------------------------------------------------------
# model_dump compatibility
# ---------------------------------------------------------------------------

def test_model_dump_compatibility(sample_events):
    """events_to_dataframe produces a DataFrame with keys matching Pydantic fields."""
    df = events_to_dataframe(sample_events)

    vote_rows = df[df['event_type'] == EventType.VOTE_CAST.value]
    if not vote_rows.empty:
        row = vote_rows.iloc[0].to_dict()
        # VoteCastEvent fields
        for field in ['block_number', 'proposal_id', 'voter', 'support', 'weight', 'lock_duration_days']:
            assert field in row, f'VoteCastEvent field {field!r} missing from DataFrame row'

    created_rows = df[df['event_type'] == EventType.PROPOSAL_CREATED.value]
    if not created_rows.empty:
        row = created_rows.iloc[0].to_dict()
        for field in ['block_number', 'proposal_id', 'proposer', 'start_block', 'end_block']:
            assert field in row, f'ProposalCreatedEvent field {field!r} missing from DataFrame row'


# ---------------------------------------------------------------------------
# Nullable columns
# ---------------------------------------------------------------------------

def test_nullable_columns(sample_events):
    """PROPOSAL_CREATED rows have NaN for vote-specific columns and vice versa."""
    df = events_to_dataframe(sample_events)

    created_rows = df[df['event_type'] == EventType.PROPOSAL_CREATED.value]
    if not created_rows.empty:
        # voter, weight, support, lock_duration_days should be NaN for created rows
        for col in ['voter', 'weight', 'support', 'lock_duration_days']:
            if col in created_rows.columns:
                assert created_rows[col].isna().all(), (
                    f'PROPOSAL_CREATED rows should have NaN for {col}'
                )

    vote_rows = df[df['event_type'] == EventType.VOTE_CAST.value]
    if not vote_rows.empty:
        # proposer, start_block, end_block, quorum, passed should be NaN for vote rows
        for col in ['proposer', 'start_block', 'end_block', 'quorum', 'passed']:
            if col in vote_rows.columns:
                assert vote_rows[col].isna().all(), (
                    f'VOTE_CAST rows should have NaN for {col}'
                )
