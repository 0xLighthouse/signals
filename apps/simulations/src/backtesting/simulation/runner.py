"""cadCAD event-replay runner: wires policies and SUFs into a cadCAD Configuration and builds the results DataFrame."""
from collections import deque
from typing import Any

import pandas as pd
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor

from backtesting.simulation.sufs import PSUBS


def _to_dict(event: Any) -> dict:
    """Normalise an event record to a plain dict.

    Accepts both plain dicts (backward compatible) and Pydantic model objects
    produced by the factory.  Enum values are serialised to their string value
    so downstream code can compare with literal strings like 'VOTE_CAST'.
    """
    if isinstance(event, dict):
        return {k: (v.value if hasattr(v, 'value') else v) for k, v in event.items()}
    # Pydantic v2 model
    return {k: (v.value if hasattr(v, 'value') else v) for k, v in event.model_dump().items()}


def run_backtest(event_records: list, curve_type: str = 'sqrt') -> list[dict]:
    """Run a cadCAD event-replay simulation over the given event records.

    Args:
        event_records: List of event dicts (or Pydantic GovernorEvent objects)
            with fields: event_type, proposal_id, block_number, voter, support,
            weight, lock_duration_days.
        curve_type: Lock curve shape for signals weight computation.
            One of 'sqrt', 'log', 'linear'. Default 'sqrt' (backward-compatible).

    Returns:
        raw_result: List of N+1 state dicts.
            raw_result[0] = initial state (step=0, tallies={})
            raw_result[1..N] = post-event states aligned with event_records[0..N-1]
    """
    # Normalise to plain dicts before passing into cadCAD
    event_records = [_to_dict(e) for e in event_records]
    n_events = len(event_records)

    config = Configuration(
        initial_state={'step': 0, 'tallies': {}},
        partial_state_update_blocks=PSUBS,
        sim_config=config_sim({
            'T': range(n_events),
            'N': 1,
            'M': {
                'event_stream': tuple(event_records),  # CRITICAL: tuple, not list
                'curve_type': curve_type,
            },
        }),
        user_id='backtesting',
        model_id='governor-replay',
        subset_id='default',
        subset_window=deque([0, n_events]),
    )

    exec_mode = ExecutionMode()
    exec_context = ExecutionContext(exec_mode.single_mode)
    executor = Executor(exec_context, [config])
    raw_result, _, _ = executor.execute()

    return raw_result


def build_results_dataframe(
    raw_result: list[dict[str, Any]],
    event_records: list,
) -> pd.DataFrame:
    """Build a results DataFrame from a cadCAD raw_result and event records.

    Skips raw_result[0] (initial state) and aligns raw_result[1..N] with
    event_records[0..N-1] by position.

    Args:
        raw_result: List of N+1 state dicts from run_backtest().
        event_records: The original list of event dicts passed to run_backtest().

    Returns:
        DataFrame with len(event_records) rows and 14 columns:
            timestep, event_type, block_number, proposal_id, voter, support,
            weight, lock_duration_days, legacy_for, legacy_against,
            legacy_abstain, signals_for, signals_against, signals_abstain
        All 6 tally columns are float64.
    """
    # Normalise to plain dicts in case caller passes Pydantic objects
    event_records = [_to_dict(e) for e in event_records]
    rows = []

    for i, state in enumerate(raw_result[1:]):  # skip index 0 (initial state)
        evt = event_records[i]
        pid = evt.get('proposal_id')
        tallies_now = state['tallies']

        row = {
            'timestep': state.get('timestep', i + 1),
            'event_type': evt.get('event_type'),
            'block_number': evt.get('block_number'),
            'proposal_id': pid,
            'voter': evt.get('voter'),
            'support': evt.get('support'),
            'weight': evt.get('weight'),
            'lock_duration_days': evt.get('lock_duration_days'),
            'legacy_for': None,
            'legacy_against': None,
            'legacy_abstain': None,
            'signals_for': None,
            'signals_against': None,
            'signals_abstain': None,
        }

        if pid and pid in tallies_now:
            tally = tallies_now[pid]
            row['legacy_for'] = tally['legacy']['FOR']
            row['legacy_against'] = tally['legacy']['AGAINST']
            row['legacy_abstain'] = tally['legacy']['ABSTAIN']
            row['signals_for'] = tally['signals']['FOR']
            row['signals_against'] = tally['signals']['AGAINST']
            row['signals_abstain'] = tally['signals']['ABSTAIN']

        rows.append(row)

    df = pd.DataFrame(rows)

    # Cast all 6 tally columns to float64
    tally_cols = [
        'legacy_for', 'legacy_against', 'legacy_abstain',
        'signals_for', 'signals_against', 'signals_abstain',
    ]
    for col in tally_cols:
        df[col] = df[col].astype('float64')

    return df
