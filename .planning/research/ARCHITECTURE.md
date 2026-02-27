# Architecture Research

**Domain:** Python simulation pipeline — cadCAD event-replay backtesting for DAO governance
**Researched:** 2026-02-27
**Confidence:** HIGH (existing code read directly; cadCAD API verified via official docs)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Entry Points                                 │
│  ┌──────────────┐  ┌───────────────┐  ┌───────────────────────┐  │
│  │  scripts/    │  │ scripts/      │  │ scripts/              │  │
│  │  run_sim.py  │  │ run_sweep.py  │  │ run_plots.py          │  │
│  └──────┬───────┘  └──────┬────────┘  └───────────┬───────────┘  │
└─────────┼─────────────────┼───────────────────────┼─────────────┘
          │                 │                       │
┌─────────▼─────────────────▼───────────────────────▼─────────────┐
│                     Orchestration Layer                           │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                backtesting/pipeline.py                    │    │
│  │  BacktestPipeline.run(config) → results DataFrame        │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
          │                 │                       │
┌─────────▼──────┐ ┌────────▼────────┐ ┌───────────▼───────────────┐
│  DATA LAYER    │ │  SIMULATION      │ │  ANALYSIS / OUTPUT        │
│                │ │  LAYER           │ │  LAYER                    │
│ backtesting/   │ │                  │ │                           │
│  data/         │ │ cadcad/          │ │ backtesting/              │
│  ├─ schema.py  │ │  ├─ config.py    │ │  metrics/                 │
│  ├─ factory.py │ │  ├─ state.py     │ │  ├─ gini.py               │
│  └─ loader.py  │ │  ├─ policies.py  │ │  ├─ enp.py                │
│                │ │  ├─ sufs/        │ │  └─ comparisons.py        │
│  backtesting/  │ │  └─ model.py     │ │                           │
│  weighting/    │ │                  │ │ backtesting/              │
│  └─ signals.py │ │ backtesting/     │ │  plots/                   │
│                │ │  experiment/     │ │  ├─ power_dist.py         │
│                │ │  ├─ config.py    │ │  ├─ gini_chart.py         │
│                │ │  └─ runner.py    │ │  └─ comparison.py         │
└────────────────┘ └─────────────────┘ └───────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `backtesting/data/schema.py` | Define Governor event types and Vote record types | Python dataclasses with strict typing |
| `backtesting/data/factory.py` | Generate synthetic Governor-compatible event streams | Functions returning `list[ProposalEvent \| VoteEvent]` |
| `backtesting/data/loader.py` | Load synthetic or real event data into canonical schema | Returns `pd.DataFrame` with typed columns |
| `backtesting/weighting/signals.py` | Compute W_signals = S × f(L) for each voter per proposal | Pure functions, no cadCAD dependency |
| `cadcad/config.py` (extend) | Add `BacktestConfig` dataclass alongside existing `SimulationConfig` | New dataclass, not replacing existing |
| `cadcad/state.py` (extend) | Add `BacktestState` and `generate_backtest_initial_state()` | Keeps existing `State` untouched |
| `cadcad/policies.py` (extend) | Add `p_replay_event` — fetches next event from M params | Reads from `params["event_stream"]` by current index |
| `cadcad/sufs/` (new files) | SUFs for applying vote events, computing tallies | `sufs/replay.py` separate from existing SUF files |
| `backtesting/experiment/config.py` | cadCAD `Experiment` config builder for sweeps | Wraps `config_sim`, keeps sweep logic isolated |
| `backtesting/experiment/runner.py` | Orchestrate cadCAD execution for one config set | Thin wrapper around existing `Executor` pattern |
| `backtesting/metrics/` | Gini, ENP, timing, flip-rate, sensitivity analysis | Pure functions on `pd.DataFrame` inputs |
| `backtesting/plots/` | Publication-grade matplotlib figures | One function per chart type, returns `Figure` |
| `backtesting/pipeline.py` | Top-level orchestrator: data → sim → metrics → plots | Calls each layer in sequence |

---

## Recommended Project Structure

```
apps/simulations/src/
│
├── cadcad/                         # EXISTING — extend, do not reorganize
│   ├── config.py                   # MODIFY: add BacktestConfig dataclass
│   ├── state.py                    # MODIFY: add BacktestState + generate_backtest_initial_state()
│   ├── model.py                    # MODIFY: add run_backtest_simulation() alongside run_simulation()
│   ├── policies.py                 # MODIFY: add p_replay_event() alongside existing policies
│   ├── parameters.py               # MODIFY: add backtest_system_params dict
│   ├── helpers.py                  # MODIFY: add backtest_results_to_dataframe()
│   └── sufs/
│       ├── __init__.py             # MODIFY: export new replay SUFs
│       ├── base.py                 # UNCHANGED
│       ├── governance.py           # UNCHANGED
│       ├── lifecycle.py            # UNCHANGED
│       ├── time.py                 # UNCHANGED
│       ├── user_actions.py         # UNCHANGED
│       └── replay.py               # NEW: s_apply_vote_event, s_compute_signals_tally, s_compute_legacy_tally
│
├── supply/                         # EXISTING — no changes needed
│   ├── allocate.py
│   ├── distributions.py
│   └── __init__.py
│
├── statistical_analysis/           # EXISTING — no changes needed for v2.0
│   ├── experiment_runner.py
│   ├── metrics.py
│   ├── visualization.py
│   └── __init__.py
│
├── visualization/                  # EXISTING — no changes needed for v2.0
│   ├── base.py
│   ├── charts/
│   ├── data_loader.py
│   ├── main.py
│   └── __init__.py
│
├── backtesting/                    # NEW PACKAGE — entire new directory
│   ├── __init__.py                 # Export BacktestPipeline, BacktestConfig
│   ├── pipeline.py                 # Top-level orchestrator
│   │
│   ├── data/                       # Data layer
│   │   ├── __init__.py
│   │   ├── schema.py               # ProposalCreated, VoteCast, ProposalFinalized dataclasses
│   │   ├── factory.py              # generate_proposals(), generate_votes(), generate_scenario()
│   │   └── loader.py               # load_events() → pd.DataFrame (supports synthetic + real)
│   │
│   ├── weighting/                  # Signals weight function
│   │   ├── __init__.py
│   │   └── signals.py              # compute_signals_weight(stake, lock_duration) → float
│   │                               # compute_legacy_weight(stake) → float
│   │                               # tally_proposal(votes_df) → TallyResult
│   │
│   ├── experiment/                 # cadCAD experiment configuration
│   │   ├── __init__.py
│   │   └── config.py               # build_experiment_config(), SweepParams dataclass
│   │
│   ├── metrics/                    # Analysis metrics
│   │   ├── __init__.py
│   │   ├── concentration.py        # gini_coefficient(), enp() (effective number of parties)
│   │   ├── timing.py               # time_to_quorum(), vote_arrival_distribution()
│   │   ├── flips.py                # outcome_flip_rate() — cases where Signals changes legacy result
│   │   └── sensitivity.py          # sensitivity_to_lock_curve(), sensitivity_to_decay()
│   │
│   └── plots/                      # Publication-grade plotting
│       ├── __init__.py
│       ├── base.py                  # shared style config, save_figure()
│       ├── power_distribution.py    # plot_voting_power_lorenz(), plot_gini_comparison()
│       ├── tally_comparison.py      # plot_legacy_vs_signals_tally()
│       ├── flip_analysis.py         # plot_outcome_flips()
│       ├── parameter_sweep.py       # plot_sweep_heatmap(), plot_sensitivity_curves()
│       └── timing.py                # plot_vote_timing_distribution()
│
├── helpers.py                      # EXISTING — no changes needed
├── main.py                         # EXISTING — no changes needed
└── visualize.py                    # EXISTING — no changes needed
```

### Structure Rationale

- **`backtesting/` as a new top-level package:** Keeps all new v2.0 code isolated. Existing packages (`cadcad/`, `supply/`, etc.) remain importable without touching their structure. New package is self-contained and its own hatchling build target.
- **`cadcad/sufs/replay.py` as a new file inside existing `sufs/`:** SUFs are cadCAD internals. Replay SUFs belong with the other SUFs, not in `backtesting/`. They are cadCAD machinery, not business logic.
- **`backtesting/weighting/signals.py` as pure functions:** The Signals weight function has no cadCAD dependency. Isolating it means it can be tested without running a simulation, and called from both the cadCAD SUFs and the metrics module.
- **`backtesting/data/schema.py` as canonical schema:** The Governor-compatible event schema defined once here is the contract that makes synthetic↔real data swappable. Both `factory.py` (synthetic) and `loader.py` (real) must conform to it.
- **`backtesting/experiment/config.py` separate from `cadcad/config.py`:** The sweep/experiment configuration (which parameter combinations to run) is a backtesting concern, not a core cadCAD model concern. Separating them prevents the existing `Config` class from becoming a monolith.

---

## Architectural Patterns

### Pattern 1: Event-Replay via M Parameters

**What:** Historical (or synthetic) events are passed into cadCAD through the `M` parameter dictionary. The state carries a `current_event_index` integer. The policy function `p_replay_event` reads `params["event_stream"][state["current_event_index"]]` and returns the event as a signal. SUFs apply the event to state.

**When to use:** Any cadCAD simulation where behavior is deterministic replay of a pre-existing sequence rather than stochastically generated each timestep. This is the core architectural choice for backtesting.

**Trade-offs:** Pro: clean cadCAD semantics, no special hooks needed. Con: the entire event stream must fit in memory as a Python list in `M`; for very large event sets, chunk the stream across multiple cadCAD runs.

**Example:**

```python
# In backtesting/experiment/config.py
def build_sim_params(events: list[dict], sweep: SweepParams) -> dict:
    return {
        "T": range(len(events)),       # One timestep per event
        "N": 1,                         # Deterministic — no Monte Carlo needed
        "M": {
            "event_stream": [events],   # Wrapped in list for cadCAD sweep format
            "lock_curve_alpha": sweep.lock_curve_alphas,
            "decay_rate": sweep.decay_rates,
        },
    }

# In cadcad/policies.py
def p_replay_event(params, substep, state_history, previous_state):
    idx = previous_state["current_event_index"]
    event = params["event_stream"][idx]
    return {"event": event}

# In cadcad/sufs/replay.py
def s_advance_event_index(params, substep, state_history, previous_state, policy_input):
    return ("current_event_index", previous_state["current_event_index"] + 1)

def s_apply_vote_event(params, substep, state_history, previous_state, policy_input):
    event = policy_input["event"]
    if event["type"] != "VOTE_CAST":
        return ("vote_ledger", previous_state["vote_ledger"])
    # Apply Signals weighting
    from backtesting.weighting.signals import compute_signals_weight
    weight = compute_signals_weight(
        stake=event["amount"],
        lock_duration=event["lock_duration"],
        alpha=params["lock_curve_alpha"],
    )
    ledger = dict(previous_state["vote_ledger"])
    ledger[event["proposal_id"]] = ledger.get(event["proposal_id"], [])
    ledger[event["proposal_id"]].append({**event, "signals_weight": weight})
    return ("vote_ledger", ledger)
```

### Pattern 2: Dual Tally Accumulation

**What:** Each VOTE_CAST event records both the legacy tally (raw stake) and the Signals tally (stake × f(lock_duration)) in the same state update pass. This avoids running two separate simulations for comparison.

**When to use:** Whenever the goal is producing a Legacy vs Signals comparison. Building both tallies simultaneously in a single replay pass is the correct approach.

**Trade-offs:** Pro: one simulation run produces both comparison columns. Con: state is slightly wider (stores both `legacy_tally` and `signals_tally` per proposal). Acceptable trade-off.

**Example:**

```python
# BacktestState initial state fields
{
    "current_event_index": 0,
    "vote_ledger": {},       # proposal_id -> list of vote records
    "legacy_tally": {},      # proposal_id -> {"for": float, "against": float}
    "signals_tally": {},     # proposal_id -> {"for": float, "against": float}
    "proposal_outcomes": {}, # proposal_id -> {"legacy_result": bool, "signals_result": bool}
}
```

### Pattern 3: Pure Function Weighting Layer

**What:** `backtesting/weighting/signals.py` contains only pure functions — no state, no cadCAD imports, no pandas. Input: numeric scalars or arrays. Output: numeric scalars or arrays.

**When to use:** Always. The weight function is the core scientific claim. It must be independently testable and reusable outside of cadCAD.

**Trade-offs:** Pro: unit-testable in isolation, callable from SUFs and metrics, easy to swap the curve. Con: none meaningful for this use case.

**Example:**

```python
# backtesting/weighting/signals.py
import numpy as np

def lock_curve(lock_duration_days: float, alpha: float = 0.5) -> float:
    """
    f(L) = 1 - exp(-alpha * L)
    Monotonic increasing, diminishing returns, approaches 1 asymptotically.
    alpha controls the rate: alpha=0.5 → ~78% of max at 3 months.
    """
    return 1.0 - np.exp(-alpha * lock_duration_days)

def compute_signals_weight(stake: float, lock_duration_days: float, alpha: float = 0.5) -> float:
    """W_signals = S × f(L)"""
    return stake * lock_curve(lock_duration_days, alpha)

def compute_legacy_weight(stake: float) -> float:
    """W_legacy = S (plain token-weighted voting)"""
    return stake
```

### Pattern 4: Schema-First Data Contract

**What:** Define the canonical Governor event schema as Python dataclasses in `backtesting/data/schema.py` before writing any generator or loader. Both `factory.py` and any future real-data `loader.py` must produce data conforming to this schema.

**When to use:** Any time synthetic and real data must be interchangeable. Defining the schema first enforces the contract at development time.

**Trade-offs:** Pro: zero-cost swap to real DAO data later — only the loader changes. Con: requires upfront schema design, but the Governor event log format is well-understood.

**Example:**

```python
# backtesting/data/schema.py
from dataclasses import dataclass
from typing import Literal

@dataclass
class VoteCastEvent:
    event_type: Literal["VOTE_CAST"] = "VOTE_CAST"
    block_number: int = 0
    proposal_id: str = ""
    voter: str = ""
    support: bool = True          # True = FOR, False = AGAINST
    weight: float = 0.0           # Raw token stake at time of vote
    lock_duration_days: float = 0.0  # 0 for non-locked (legacy)
    timestamp: int = 0            # Unix seconds

@dataclass
class ProposalCreatedEvent:
    event_type: Literal["PROPOSAL_CREATED"] = "PROPOSAL_CREATED"
    block_number: int = 0
    proposal_id: str = ""
    proposer: str = ""
    description: str = ""
    timestamp: int = 0

@dataclass
class ProposalFinalizedEvent:
    event_type: Literal["PROPOSAL_FINALIZED"] = "PROPOSAL_FINALIZED"
    block_number: int = 0
    proposal_id: str = ""
    passed: bool = False
    timestamp: int = 0

GovernorEvent = ProposalCreatedEvent | VoteCastEvent | ProposalFinalizedEvent
```

---

## Data Flow

### Full Pipeline Flow

```
backtesting/data/factory.py
    generate_scenario(config) → list[GovernorEvent]
        │
        ▼
backtesting/data/loader.py
    events_to_dataframe(events) → pd.DataFrame
        │ (schema validated, sorted by block_number)
        ▼
backtesting/experiment/config.py
    build_sim_params(events_df, sweep_params) → cadCAD M dict
        │ (events packed into M["event_stream"])
        ▼
cadcad/model.py
    run_backtest_simulation(initial_state, sim_params) → list[dict]
        │
        ├── Per timestep (one event):
        │   ├── p_replay_event      → {event: GovernorEvent}
        │   ├── s_advance_index     → current_event_index += 1
        │   ├── s_apply_vote_event  → updates vote_ledger, legacy_tally, signals_tally
        │   └── s_finalize_proposal → updates proposal_outcomes on PROPOSAL_FINALIZED
        │
        ▼
cadcad/helpers.py
    backtest_results_to_dataframe(raw_results) → pd.DataFrame
        │ (flattened: one row per timestep, tally columns exploded)
        ▼
backtesting/metrics/
    compute_all_metrics(results_df) → dict[str, float]
        │ gini, enp, timing, flip_rate, sensitivity
        ▼
backtesting/plots/
    generate_publication_suite(results_df, metrics) → list[Figure]
        │ saved to results/plots/
        ▼
backtesting/pipeline.py
    BacktestPipeline.run(config) → BacktestResult
```

### Parameter Sweep Flow

```
SweepParams(lock_curve_alphas=[0.1, 0.3, 0.5, 1.0], decay_rates=[0.0, 0.001, 0.005])
    │
    ▼
build_sim_params() packs multiple values per M key
    │ cadCAD generates cartesian product of all M lists
    ▼
Executor runs one sim per combination
    │ raw results include "subset" column identifying which combination
    ▼
backtest_results_to_dataframe() preserves subset column
    │
    ▼
backtesting/metrics/sensitivity.py reads subset groupings
    │
    ▼
backtesting/plots/parameter_sweep.py renders heatmap / sensitivity curves
```

### Key Data Flows

1. **Schema propagation:** `schema.py` types flow from `factory.py` → `loader.py` → `M["event_stream"]` → `policies.py` → `sufs/replay.py`. The dataclass fields define what each SUF can safely access.

2. **Tally accumulation:** Each VOTE_CAST event causes one state update to both `legacy_tally` and `signals_tally`. By end of simulation, both tallies are complete. Comparison happens post-simulation in metrics, not during.

3. **Results flattening:** cadCAD returns `list[dict]` where each row is one (run, timestep, substep) combination. `backtest_results_to_dataframe()` must filter to `substep == max_substep` to get one clean row per event, then explode the nested tally dicts into columns.

---

## Integration Points

### New vs Existing: Explicit Boundary

| Module | Status | What Changes |
|--------|--------|--------------|
| `cadcad/config.py` | MODIFY | Append `BacktestConfig` dataclass; existing `SimulationConfig` untouched |
| `cadcad/state.py` | MODIFY | Append `BacktestState`, `generate_backtest_initial_state()`; existing `State` untouched |
| `cadcad/model.py` | MODIFY | Append `run_backtest_simulation()`; existing `run_simulation()` untouched |
| `cadcad/policies.py` | MODIFY | Append `p_replay_event()`; existing policies untouched |
| `cadcad/sufs/__init__.py` | MODIFY | Export new replay SUFs |
| `cadcad/sufs/replay.py` | NEW | `s_advance_event_index`, `s_apply_vote_event`, `s_finalize_proposal` |
| `supply/` | UNCHANGED | No changes |
| `statistical_analysis/` | UNCHANGED | No changes |
| `visualization/` | UNCHANGED | No changes |
| `backtesting/` | NEW | Entire package |
| `pyproject.toml` | MODIFY | Add `"src/backtesting"` to `[tool.hatch.build.targets.wheel] packages` |

### Internal Module Boundaries

| Boundary | Communication | Direction | Notes |
|----------|---------------|-----------|-------|
| `backtesting/data/` ↔ `cadcad/model.py` | `M["event_stream"]` list | data → cadcad | Events packed as plain dicts (not dataclasses) for cadCAD M param compatibility |
| `backtesting/weighting/` ↔ `cadcad/sufs/replay.py` | direct import | sufs → weighting | SUFs import pure functions from weighting; no circular dependency |
| `cadcad/model.py` ↔ `backtesting/experiment/runner.py` | `run_backtest_simulation()` call | experiment → cadcad | Runner owns config assembly; model owns execution |
| `cadcad/helpers.py` ↔ `backtesting/metrics/` | `pd.DataFrame` | helpers → metrics | Helpers produce flattened DataFrame; metrics consume it |
| `backtesting/metrics/` ↔ `backtesting/plots/` | `dict[str, float]` + `pd.DataFrame` | metrics → plots | Metrics compute scalars; plots visualize them |
| `backtesting/pipeline.py` ↔ all layers | orchestration calls | pipeline → all | Pipeline is the only module that imports across all layers |

### pyproject.toml Change

```toml
# Current:
packages = ["src/cadcad", "src/supply", "src/visualization", "src/statistical_analysis"]

# After v2.0:
packages = ["src/cadcad", "src/supply", "src/visualization", "src/statistical_analysis", "src/backtesting"]
```

---

## cadCAD Configuration API for Event-Replay

This section documents the specific cadCAD API usage appropriate for backtesting (non-stochastic replay) vs the existing stochastic simulation.

### Existing Pattern (Stochastic ABM)

```python
# cadcad/model.py — current run_simulation()
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim

config = Configuration(
    initial_state=initial_state,
    partial_state_update_blocks=psubs,
    sim_config=config_sim(simulation_parameters),
    ...
)
executor = Executor(exec_context, [config])
raw_result, tensor_field, sessions = executor.execute()
```

### New Pattern (Event-Replay Backtesting)

```python
# cadcad/model.py — new run_backtest_simulation()
# Use Experiment API for parameter sweeps (multiple M combinations)
from cadCAD.configuration import Experiment
from cadCAD.configuration.utils import config_sim

exp = Experiment()
exp.append_model(
    initial_state=initial_state,
    partial_state_update_blocks=backtest_psubs,
    sim_configs=config_sim(sim_params),   # sim_params["M"] has sweep lists
)
executor = Executor(exec_context, exp.configs)
raw_result, tensor_field, sessions = executor.execute()
```

**Key difference:** `Configuration` is used for a single model run. `Experiment.append_model()` is used when running parameter sweeps (multiple M values). For backtesting with parameter sweeps (lock curve alpha, decay rate), use `Experiment`.

### Result Structure

cadCAD raw results rows contain these index fields:

| Field | Type | Meaning |
|-------|------|---------|
| `subset` | int | Which M parameter combination (sweep index) |
| `run` | int | Which Monte Carlo run (N index) — always 0 for deterministic replay |
| `timestep` | int | Which event in the stream (0 to len(events)-1) |
| `substep` | int | Which PSUB block (1 to len(psubs)) |

Post-processing: filter to `substep == max(substep)` per (subset, run, timestep) to get one clean row per event. Then join subset index back to sweep parameters for analysis.

---

## Suggested Build Order

Build order respects hard dependencies: data schema before generators, weighting before SUFs that call it, state before model, model before metrics, metrics before plots.

### Phase 1: Data Foundation (no dependencies)

1. `backtesting/data/schema.py` — define `VoteCastEvent`, `ProposalCreatedEvent`, `ProposalFinalizedEvent`
2. `backtesting/weighting/signals.py` — `lock_curve()`, `compute_signals_weight()`, `compute_legacy_weight()`
3. `backtesting/data/factory.py` — `generate_proposals()`, `generate_votes()`, `generate_scenario()`
4. `backtesting/data/loader.py` — `load_events()` returning canonical `pd.DataFrame`

**Tests first:** Write unit tests for `signals.py` (pure functions, trivial to test) and `factory.py` (validate schema conformance).

### Phase 2: cadCAD Integration (depends on Phase 1)

1. `cadcad/config.py` — append `BacktestConfig`
2. `cadcad/state.py` — append `BacktestState`, `generate_backtest_initial_state()`
3. `cadcad/sufs/replay.py` — `s_advance_event_index`, `s_apply_vote_event`, `s_finalize_proposal`
   - `s_apply_vote_event` imports from `backtesting/weighting/signals.py`
4. `cadcad/policies.py` — append `p_replay_event`
5. `backtesting/experiment/config.py` — `build_sim_params()`, `SweepParams`
6. `cadcad/model.py` — append `run_backtest_simulation()` using `Experiment` API
7. `cadcad/helpers.py` — append `backtest_results_to_dataframe()`

**Integration test:** Run a minimal event stream (3 proposals, 10 votes each) through the full cadCAD pipeline and verify the output DataFrame has the expected columns.

### Phase 3: Metrics (depends on Phase 2)

1. `backtesting/metrics/concentration.py` — `gini_coefficient()`, `enp()`
2. `backtesting/metrics/timing.py` — `time_to_quorum()`, `vote_arrival_distribution()`
3. `backtesting/metrics/flips.py` — `outcome_flip_rate()` (requires both tallies from Phase 2)
4. `backtesting/metrics/sensitivity.py` — `sensitivity_to_lock_curve()` (requires sweep results)
5. `backtesting/metrics/__init__.py` — `compute_all_metrics()` orchestrator

### Phase 4: Plots (depends on Phase 3)

1. `backtesting/plots/base.py` — shared style, `save_figure()`
2. `backtesting/plots/power_distribution.py` — Lorenz curve, Gini comparison
3. `backtesting/plots/tally_comparison.py` — Legacy vs Signals bar chart per proposal
4. `backtesting/plots/flip_analysis.py` — outcome flip scatter / histogram
5. `backtesting/plots/parameter_sweep.py` — heatmap, sensitivity curves
6. `backtesting/plots/timing.py` — vote timing distribution
7. `backtesting/plots/__init__.py` — `generate_publication_suite()`

### Phase 5: Orchestration + Config Registration

1. `backtesting/pipeline.py` — `BacktestPipeline`, `BacktestResult`
2. `backtesting/__init__.py` — public exports
3. `pyproject.toml` — add `"src/backtesting"` to build packages

---

## Anti-Patterns

### Anti-Pattern 1: Running Two Separate Simulations for Legacy vs Signals

**What people do:** Run one cadCAD simulation for legacy voting, then a second separate simulation for Signals voting, then compare outputs.

**Why it's wrong:** Doubles runtime. Introduces non-determinism between runs if random seeds differ. Makes the comparison noisy — you want to compare tallies on the exact same votes.

**Do this instead:** Accumulate both `legacy_tally` and `signals_tally` in the same state during a single replay. The VOTE_CAST SUF writes to both simultaneously. One simulation, two tally columns.

### Anti-Pattern 2: Putting the Signals Weight Function Inside cadCAD SUFs

**What people do:** Implement `W = S × f(L)` inline inside `s_apply_vote_event`.

**Why it's wrong:** The weight function is a scientific claim that needs independent unit tests and parameterization (alpha sweep). Burying it in a SUF makes it invisible and untestable without running the full simulation.

**Do this instead:** Implement `compute_signals_weight()` in `backtesting/weighting/signals.py` as a pure function. Import it from the SUF. Test it directly.

### Anti-Pattern 3: Using cadCAD's N Parameter for Sweep Across Lock Curve Shapes

**What people do:** Set `N=10` thinking this runs 10 different parameter combinations.

**Why it's wrong:** `N` is the Monte Carlo repetition count for the same parameters. For deterministic event replay, `N=1` always. Parameter sweep uses multiple values in the `M` dict (cadCAD generates the cartesian product). `N > 1` on replay means running the identical sequence N times — wasteful.

**Do this instead:** Set `N=1`. Put sweep parameters as lists in `M`. Use cadCAD's built-in sweep mechanism. The `subset` column in results identifies which combination.

### Anti-Pattern 4: Storing Event Dataclasses in cadCAD M Parameters

**What people do:** Pass `list[VoteCastEvent]` (dataclass instances) into `M["event_stream"]`.

**Why it's wrong:** cadCAD serializes M parameters. Dataclass instances may not serialize cleanly across process boundaries (especially if using `ProcessPoolExecutor` for parallel sweeps). cadCAD may also make copies of M parameters.

**Do this instead:** Convert events to plain `dict` via `dataclasses.asdict()` before packing into `M`. Reconstruct structured access by key name in the policy function.

### Anti-Pattern 5: One Monolithic PSUB for All Event Types

**What people do:** Write one large `s_apply_event` SUF that handles `PROPOSAL_CREATED`, `VOTE_CAST`, and `PROPOSAL_FINALIZED` with nested if/else.

**Why it's wrong:** cadCAD PSUBs are meant to be composable. A monolithic SUF is hard to test and debug. When the simulation fails at timestep 47, you can't tell which event type caused it.

**Do this instead:** Use multiple PSUBs or at minimum separate SUFs per event type. Each SUF handles one concern: `s_apply_vote_event` only processes votes, `s_finalize_proposal` only processes finalizations, etc. Non-matching events return the previous state unchanged.

---

## Scaling Considerations

This is a research simulation, not a production system. Scaling concerns are about simulation performance, not user load.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 scenario, 1 param set | Single `run_backtest_simulation()` call, sequential |
| 10-100 param combinations | cadCAD Experiment sweep (cartesian product of M values), still single process |
| 100+ param combinations | Use `ExperimentRunner` pattern from `statistical_analysis/` with `ProcessPoolExecutor`; each worker runs one cadCAD config |
| Very large event streams (>10k events) | Chunk event stream into time windows; run cadCAD per window; stitch results |

### Scaling Priority

1. **First bottleneck:** Parameter sweep size. cadCAD's built-in sweep handles small cartesian products. For large sweeps, the existing `ProcessPoolExecutor` pattern in `statistical_analysis/experiment_runner.py` is the proven approach.
2. **Second bottleneck:** Event stream length. Python-level cadCAD timestep loop is slow for very long streams. For v2.0 scope (synthetic data, ~100 proposals per scenario), this is not a concern.

---

## Sources

- cadCAD official documentation — `github.com/cadCAD-org/cadCAD/tree/master/documentation` (Configuration API, Policy/SUF signatures, M parameter structure, result row fields)
- cadCAD README.md — Policy function signature `(_params, substep, sH, s)`, result structure with `subset/run/timestep/substep` indexes
- Existing `apps/simulations/src/` codebase — read directly: `cadcad/model.py`, `cadcad/config.py`, `cadcad/state.py`, `cadcad/policies.py`, `cadcad/sufs/governance.py`, `statistical_analysis/experiment_runner.py`, `visualization/main.py`
- radCAD README — `github.com/CADLabs/radCAD` (compatibility context; not recommended for switch given existing cadCAD investment)

---

*Architecture research for: Signals backtesting & cadCAD simulation pipeline (v2.0)*
*Researched: 2026-02-27*
