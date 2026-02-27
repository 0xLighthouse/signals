# Backtesting

Quantitative comparison of legacy (stake-only) governance vs Signals (commitment-weighted) governance. Replays Governor-compatible event streams through a cadCAD simulation, computing parallel tallies under both regimes, then measures how outcomes diverge.

**Goal**: Produce publishable evidence that commitment-weighted voting improves governance outcomes — fairer power distribution, reduced whale dominance, and meaningful participation incentives.

## Quick start

```bash
cd apps/simulations

# Install dependencies
uv sync

# Run all backtesting tests
uv run pytest tests/ -v

# Run with coverage
uv run pytest tests/ --cov=src/backtesting --cov-report=html
```

## End-to-end workflow

```python
from backtesting.data import generate_scenario, SyntheticLoader
from backtesting.simulation import run_backtest, build_results_dataframe
from backtesting.metrics import (
    compute_flip_rate, compute_gini, compute_enp,
    compute_margin_shift, compute_transition_matrix,
    compute_late_vote_share, compute_lockin_timing,
    compute_top_k_concentration,
)
from backtesting.plots import plot_flip_rate_summary, plot_gini_comparison

# 1. Generate synthetic Governor event stream
events = generate_scenario(
    n_voters=200,
    n_proposals=30,
    total_supply=1_000_000.0,
    stake_profile='pareto',     # Power-law stake distribution
    lock_profile='independent', # Random lock durations
    seed=42,
)

# 2. Load and validate
loader = SyntheticLoader(events)
events_df = loader.load()  # Raises ValueError on integrity errors

# 3. Run cadCAD event-replay simulation
raw_result = run_backtest(events)
results_df = build_results_dataframe(raw_result, events)
# results_df columns: timestep, event_type, block_number, proposal_id,
#   voter, support, weight, lock_duration_days,
#   legacy_for, legacy_against, legacy_abstain,
#   signals_for, signals_against, signals_abstain

# 4. Compute metrics
flip = compute_flip_rate(results_df)
gini = compute_gini(results_df)

# Timing metrics need a windows DataFrame
windows_df = events_df[events_df['event_type'] == 'PROPOSAL_CREATED'][
    ['proposal_id', 'start_block', 'end_block']
].reset_index(drop=True)

late = compute_late_vote_share(results_df, windows_df)
lockin = compute_lockin_timing(results_df, windows_df)

# 5. Plot and save
fig = plot_flip_rate_summary(flip)
fig.savefig('flip_rate.png')

fig = plot_gini_comparison(gini)
fig.savefig('gini.png')
```

## Architecture

```
backtesting/
├── data/
│   ├── schema.py       Pydantic v2 event models (GovernorEvent union type)
│   ├── factory.py      Synthetic scenario generation with configurable profiles
│   └── loader.py       SyntheticLoader, ParquetLoader, validation
├── weighting/
│   └── signals.py      lock_curve(), compute_signals_weight(), compute_legacy_weight()
├── simulation/
│   ├── runner.py       run_backtest(), build_results_dataframe()
│   ├── policies.py     cadCAD policy: event replay
│   └── sufs.py         cadCAD state update functions, PSUB chain
├── metrics.py          10 metric functions, all returning frozen dataclasses
└── plots.py            11 matplotlib plot functions (OO API, no pyplot)
```

### Data layer

Three event types model a Governor lifecycle:

| Event | Key fields |
|-------|------------|
| `PROPOSAL_CREATED` | proposal_id, proposer, start_block, end_block, quorum |
| `VOTE_CAST` | proposal_id, voter, support (FOR/AGAINST/ABSTAIN), weight, lock_duration_days |
| `PROPOSAL_FINALIZED` | proposal_id, passed |

The `generate_scenario()` factory creates realistic event streams with configurable stake and lock duration distributions:

- **Stake profiles**: `pareto` (power-law 80/20), `uniform`, `bimodal` (10% hold 90%)
- **Lock profiles**: `correlated` (high stake = long lock), `independent` (random), `bimodal` (30% short, 70% long)

Data sources are swappable — `SyntheticLoader` for generated data, `ParquetLoader` for real DAO exports. Both conform to the `GovernorDataLoader` protocol.

### Weighting

The Signals weight formula: **W = S x f(L)**

- **S** = token stake
- **f(L)** = lock curve mapping lock duration to a multiplier in [floor, 1.0]
- **Curve types**: `sqrt` (default, diminishing returns), `linear`, `log`, `exp`

Legacy weight is just stake (identity function), providing the comparison baseline.

### Simulation

The cadCAD runner replays events through a multi-PSUB pipeline, maintaining parallel running tallies for both legacy and Signals regimes. Each vote updates cumulative FOR/AGAINST/ABSTAIN counts under both weighting schemes simultaneously.

### Metrics

All functions accept `results_df` from `build_results_dataframe()` and return frozen dataclasses.

| Function | Returns | What it measures |
|----------|---------|-----------------|
| `compute_flip_rate` | `FlipRateResult` | Fraction of proposals whose outcome differs between regimes |
| `compute_gini` | `GiniResult` | Gini coefficient of voting power distribution |
| `compute_participation_rate` | `ParticipationResult` | Voter participation rate per proposal |
| `compute_enp` | `ENPResult` | Effective Number of Participants (1/HHI) |
| `compute_nakamoto_coefficient` | `NakamotoResult` | Min voters controlling >50% of weight |
| `compute_margin_shift` | `MarginShiftResult` | Per-proposal change in victory margin |
| `compute_transition_matrix` | `TransitionMatrix` | 2x2 outcome transition (pass/fail x legacy/signals) |
| `compute_late_vote_share` | `LateVoteShareResult` | Weight fraction cast in final third of voting window |
| `compute_lockin_timing` | `LockinTimingResult` | When outcome becomes mathematically certain |
| `compute_top_k_concentration` | `TopKConcentrationResult` | Top-1/5/10 voter share of voting power |

`compute_late_vote_share` and `compute_lockin_timing` additionally require a `windows_df` with proposal_id, start_block, end_block columns.

### Plots

11 functions, each returning a `matplotlib.figure.Figure`. The module uses the OO API exclusively — no `matplotlib.pyplot` import, no global state. Module-level `rcParams` set publication styling (serif font, y-gridlines only, no top/right spines, 300 DPI).

Color convention: **Blue (#2196F3)** = Legacy, **Orange (#FF9800)** = Signals.

| Function | Input | Chart type |
|----------|-------|------------|
| `plot_flip_rate_summary` | FlipRateResult | Grouped bar |
| `plot_margin_shift_histogram` | MarginShiftResult | Horizontal bar per proposal |
| `plot_transition_matrix` | TransitionMatrix | 2x2 heatmap |
| `plot_gini_comparison` | GiniResult | Grouped bar |
| `plot_top_k_comparison` | TopKConcentrationResult | Grouped bar (k=1,5,10) |
| `plot_enp_comparison` | ENPResult | Grouped bar |
| `plot_cumulative_vote_curve` | results_df, proposal_id | Line chart |
| `plot_late_vote_share` | LateVoteShareResult | Grouped bar per proposal |
| `plot_lorenz_curve` | results_df | Lorenz curves with equality line |
| `plot_proposal_story` | results_df, proposal_id, LockinTimingResult | Multi-line margin timeline |
| `plot_lock_duration_histogram` | results_df | Histogram + twinx weight overlay |

## Testing

```bash
cd apps/simulations

# All tests
uv run pytest tests/ -v

# By module
uv run pytest tests/test_schema.py           # Event validation
uv run pytest tests/test_factory.py          # Data generation
uv run pytest tests/test_loader.py           # Data loading
uv run pytest tests/test_weighting.py        # Weight functions
uv run pytest tests/test_simulation_runner.py # cadCAD runner
uv run pytest tests/test_metrics.py          # Metric computations
uv run pytest tests/test_plots.py            # Plot generation
```

## Dependencies

Requires Python >= 3.12. Key runtime dependencies:

- **cadCAD** — event-replay simulation engine
- **pandas** / **numpy** — data manipulation
- **matplotlib** — publication-grade plotting (OO API)
- **pydantic** v2 — event schema validation
- **fastparquet** — Parquet file I/O
- **scipy** — statistical functions

See `pyproject.toml` for pinned versions.
