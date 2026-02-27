"""
Data loader layer for Governor-compatible event streams.

Provides:
  - events_to_dataframe: Convert event list to sorted DataFrame
  - validate_event_stream: Referential integrity checks (fail fast)
  - SyntheticLoader: Loads from in-memory event list
  - ParquetLoader: Loads from Parquet file on disk

Both SyntheticLoader and ParquetLoader satisfy the GovernorDataLoader Protocol
via structural typing — no inheritance required.

DataFrame note: The output DataFrame contains all event types merged into a
single table. Consumers MUST filter by event_type before accessing
type-specific columns; rows for other event types will have NaN in those fields.

Example:
    votes = df[df['event_type'] == 'VOTE_CAST']
    proposals = df[df['event_type'] == 'PROPOSAL_CREATED']
"""

from __future__ import annotations

from collections.abc import Sequence

import pandas as pd

from backtesting.data.schema import EventType, GovernorDataLoader, GovernorEvent


def events_to_dataframe(events: Sequence[GovernorEvent]) -> pd.DataFrame:
    """
    Convert a sequence of GovernorEvent objects to a sorted DataFrame.

    Each event is serialized via .model_dump(). The resulting DataFrame
    is sorted by block_number and has its index reset.

    Parameters
    ----------
    events : Sequence[GovernorEvent]
        List of ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent.

    Returns
    -------
    pd.DataFrame
        Sorted by block_number with index reset. Type-specific columns
        contain NaN for rows of other event types.
    """
    if not events:
        return pd.DataFrame()

    rows = [event.model_dump() for event in events]
    df = pd.DataFrame(rows)
    df = df.sort_values('block_number').reset_index(drop=True)
    return df


def validate_event_stream(df: pd.DataFrame) -> list[str]:
    """
    Validate referential integrity of a Governor event stream DataFrame.

    Checks:
      (a) Votes on unknown proposals (no PROPOSAL_CREATED for that proposal_id)
      (b) Double votes (same voter + proposal_id appears more than once)
      (c) Votes outside proposal window (block_number < start_block or > end_block)

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame produced by events_to_dataframe.

    Returns
    -------
    list[str]
        List of error strings. Empty list means the stream is valid.
    """
    errors: list[str] = []

    if df.empty:
        return errors

    # Extract event subsets
    created_mask = df['event_type'] == EventType.PROPOSAL_CREATED.value
    vote_mask = df['event_type'] == EventType.VOTE_CAST.value

    created_df = df[created_mask]
    vote_df = df[vote_mask]

    if vote_df.empty:
        return errors

    # Build lookup: proposal_id -> (start_block, end_block)
    proposal_windows: dict[str, tuple[int, int]] = {}
    for _, row in created_df.iterrows():
        proposal_windows[row['proposal_id']] = (int(row['start_block']), int(row['end_block']))

    known_proposals = set(proposal_windows.keys())

    # (a) Votes on unknown proposals
    vote_proposal_ids = set(vote_df['proposal_id'].dropna().unique())
    unknown = vote_proposal_ids - known_proposals
    for pid in sorted(unknown):
        errors.append(f'Vote references unknown proposal_id: {pid}')

    # (b) Double votes — same (voter, proposal_id) pair
    if 'voter' in vote_df.columns:
        dups = vote_df.groupby(['voter', 'proposal_id']).size()
        double_votes = dups[dups > 1]
        for (voter, pid), count in double_votes.items():
            errors.append(
                f'Double vote detected: voter={voter} proposal_id={pid} count={count}'
            )

    # (c) Votes outside proposal window
    for _, row in vote_df.iterrows():
        pid = row.get('proposal_id')
        if pid not in proposal_windows:
            continue  # already reported as unknown
        start_block, end_block = proposal_windows[pid]
        block_num = int(row['block_number'])
        if block_num < start_block or block_num > end_block:
            errors.append(
                f'Vote outside window: voter={row.get("voter")} '
                f'proposal_id={pid} block={block_num} '
                f'window=[{start_block}, {end_block}]'
            )

    return errors


class SyntheticLoader:
    """
    Load a Governor event stream from an in-memory event list.

    Satisfies the GovernorDataLoader Protocol structurally.
    Raises ValueError if validate_event_stream finds any errors.

    Parameters
    ----------
    events : Sequence[GovernorEvent]
        List of Governor events to load.
    """

    def __init__(self, events: Sequence[GovernorEvent]) -> None:
        self._events = list(events)

    def load(self) -> pd.DataFrame:
        """
        Convert events to DataFrame and validate referential integrity.

        Returns
        -------
        pd.DataFrame
            Sorted by block_number. Filter by event_type before accessing
            type-specific columns.

        Raises
        ------
        ValueError
            If validate_event_stream detects any integrity violations.
        """
        df = events_to_dataframe(self._events)
        errors = validate_event_stream(df)
        if errors:
            error_msg = '\n'.join(errors)
            raise ValueError(
                f'Event stream failed validation ({len(errors)} error(s)):\n{error_msg}'
            )
        return df


class ParquetLoader:
    """
    Load a Governor event stream from a Parquet file.

    Satisfies the GovernorDataLoader Protocol structurally.
    Raises ValueError if validate_event_stream finds any errors.

    Parameters
    ----------
    path : str
        Path to the Parquet file.
    column_mapping : dict | None
        Optional column rename mapping for future use (e.g., adapting
        real on-chain data column names to the schema column names).
        Not applied in the current implementation.
    """

    def __init__(self, path: str, column_mapping: dict | None = None) -> None:
        self._path = path
        self._column_mapping = column_mapping

    def load(self) -> pd.DataFrame:
        """
        Read Parquet file and validate referential integrity.

        Returns
        -------
        pd.DataFrame
            Sorted by block_number. Filter by event_type before accessing
            type-specific columns.

        Raises
        ------
        ValueError
            If validate_event_stream detects any integrity violations.
        FileNotFoundError
            If the Parquet file does not exist.
        """
        df = pd.read_parquet(self._path)
        if self._column_mapping:
            df = df.rename(columns=self._column_mapping)
        if 'block_number' in df.columns:
            df = df.sort_values('block_number').reset_index(drop=True)
        errors = validate_event_stream(df)
        if errors:
            error_msg = '\n'.join(errors)
            raise ValueError(
                f'Event stream failed validation ({len(errors)} error(s)):\n{error_msg}'
            )
        return df


# Type assertion — both classes satisfy GovernorDataLoader Protocol
assert isinstance(SyntheticLoader([]), GovernorDataLoader), (
    'SyntheticLoader does not satisfy GovernorDataLoader Protocol'
)
