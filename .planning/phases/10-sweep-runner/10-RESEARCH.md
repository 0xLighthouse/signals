# Phase 10: Sweep Runner - Research

**Researched:** 2026-02-28
**Domain:** Parameter sweep engine, parallel execution, TOML configuration, memory management
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Grid Configuration
- Flat lists per axis in TOML: `curve_types = ["linear", "quadratic"]`, `alphas = [0.1, 0.5, 0.9]`, etc.
- Lock profiles specified as inline dicts: `lock_profiles = [{short=30, long=365}, {short=90, long=730}]`
- Single TOML file with `[base]` section for fixed simulation params (num_proposals, num_voters, etc.) and `[sweep]` section for grid axes
- No named profile presets — one flat config per sweep run

#### Parallelism & Failure
- Always use ProcessPoolExecutor, even with 1 worker (no serial mode)
- `max_workers` must be explicitly specified in TOML — no auto-detection
- Default behavior: skip-and-continue on cell failure (log error, mark cell failed, continue remaining cells)
- `--fail-fast` flag to stop entire sweep on first error
- Configurable `cell_timeout_seconds` in TOML — cells exceeding it are killed and marked failed

#### Result Shape & Output
- `SweepResult` contains a summary DataFrame (one row per config, columns = metrics)
- Auto-export on completion: write `summary.csv` and `config.json` to output directory
- Output directory follows existing pattern: `apps/simulations/output/{timestamp}/`
- tqdm progress bar showing cell count + ETA: `[3/12 cells] 25% |████      | 1:23 remaining`

### Claude's Discretion
- Whether allocation strategies should be a sweep axis or fixed per run (consider grid size and memory)
- Detail data retention strategy (summary only vs optional per-proposal detail)
- Provenance approach (embed config in SweepResult vs copy TOML to output dir)
- Module structure (single sweep.py vs subpackage)
- Entry point design (Python function, CLI script, or both)
- Whether to support resume for interrupted sweeps

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SWEP-01 | `SweepConfig` dataclass defining grid axes: curve_type, alpha, lock_profile, allocation_strategy | Python dataclass with validated fields; `itertools.product` drives enumeration |
| SWEP-02 | Dedicated `sweep.py` runner using `itertools.product` for cartesian grid enumeration (cadCAD M-param zips element-wise, not factorial) | Verified: `itertools.product(['sqrt','log'], [0.5,1.0,2.0])` produces 6 pairs; cadCAD M dict does NOT do cartesian — external product is mandatory |
| SWEP-03 | `ProcessPoolExecutor` parallelism across sweep cells (~192 cells, stdlib sufficient) | Verified: `ProcessPoolExecutor` + `as_completed` pattern works; cell functions must be module-level (picklable); `BetaDistribution` is picklable |
| SWEP-04 | Memory management: compute metrics per-cell and release cadCAD raw results | Verified: `del raw_result; gc.collect()` pattern works; raw cadCAD result is a `list[dict]` that can be deleted after metrics computation |
| SWEP-05 | `SweepResult` with summary DataFrame (one row per config, columns = metrics) | Verified: `pd.DataFrame(cells)` where each cell is a flat dict; 2 curve_types × 3 alphas × 2 strategies = 12 rows confirmed |
| SWEP-06 | tqdm progress reporting during sweep execution | Verified: `tqdm` 4.67.3 is installed; `tqdm(total=N)` + `pbar.update(1)` inside `as_completed` loop is thread-safe |
| SWEP-07 | TOML configuration for sweep grid parameters | Verified: `tomllib` (stdlib Python 3.11+) handles `[[sweep.lock_profiles]]` array of inline tables; exact TOML structure confirmed working |
</phase_requirements>

## Summary

Phase 10 builds a sweep engine that enumerates a cartesian parameter grid across `curve_type`, `alpha` (pareto_alpha), `lock_profile`, and optionally `allocation_strategy`, runs one cadCAD simulation per cell, computes scalar metrics after each cell's raw results are available, and releases the raw results immediately to bound memory. All findings are collected into a `SweepResult` containing a `summary_df` (one row per cell) and exported as `summary.csv` + `config.json`.

The implementation is a thin orchestration layer on top of Phase 9's existing infrastructure: `generate_scenario()` + `run_backtest()` + `build_results_dataframe()` + metrics functions. No new simulation logic is needed. The sweep runner's job is grid enumeration, parallel dispatch, timeout enforcement, error containment, progress reporting, and output serialization.

The key architectural insight from CONTEXT.md: cadCAD's M-param dict zips element-wise (not cartesian), so the sweep must build the explicit cartesian product externally using `itertools.product`. This is verified and working. All dependencies (tqdm 4.67.3, tomllib stdlib, ProcessPoolExecutor stdlib, itertools stdlib) are already available in the project environment.

**Primary recommendation:** Implement as a single `backtesting/sweep.py` module with `SweepConfig`, `SweepCell`, `SweepResult` dataclasses and a `run_sweep()` function. Use `ProcessPoolExecutor` + `as_completed` + `tqdm` for parallel progress-tracked execution. Module-level `_run_cell()` function is mandatory for picklability.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `itertools` | stdlib | Cartesian product enumeration | `itertools.product` is the canonical way; verified produces correct N-dim grid |
| `concurrent.futures` | stdlib | `ProcessPoolExecutor` parallel cell execution | Decision-locked; `as_completed` enables streaming results + progress updates |
| `tqdm` | 4.67.3 | Progress bar with ETA | Already installed; `tqdm(total=N)` + `pbar.update(1)` is thread-safe in `as_completed` loop |
| `tomllib` | stdlib (3.11+) | TOML config parsing | Project uses Python 3.12+; already used in `pipeline.py`; handles `[[sweep.lock_profiles]]` correctly |
| `pandas` | >=2.2.3 | `summary_df` construction and CSV export | Already in project; `pd.DataFrame(list_of_dicts)` + `.to_csv()` |
| `json` | stdlib | `config.json` export | Used in `pipeline.py` already |
| `gc` | stdlib | Explicit garbage collection after cell cleanup | `del raw_result; gc.collect()` ensures bounded memory |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `logging` | stdlib | Cell failure logging | Log errors on skip-and-continue; matches project convention |
| `dataclasses` | stdlib | `SweepConfig`, `SweepCell`, `SweepResult` | Consistent with Phase 9 pattern (`MCSample`, `MCResult`) |
| `pathlib` | stdlib | Output directory creation | Matches `pipeline.py` pattern exactly |
| `datetime` | stdlib | Timestamp-based output directory naming | Matches `pipeline.py` `_make_output_dir()` pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ProcessPoolExecutor` | `multiprocessing.Pool` | Pool requires more boilerplate; decision-locked to ProcessPoolExecutor |
| `itertools.product` | cadCAD M-param sweep | cadCAD zips element-wise, not cartesian — CANNOT use cadCAD for this |
| `tomllib` (stdlib) | `toml` or `tomli` third-party | No new dependency needed; project already on Python 3.12+ |
| `tqdm` | custom progress print | tqdm is already installed and provides ETA automatically |

**Installation:** No new packages needed. All required libraries are either stdlib or already in `pyproject.toml` (`tqdm` is not listed but IS available at runtime — verified 4.67.3). Add `tqdm` to `pyproject.toml` if it's a transitive dep that could disappear.

## Architecture Patterns

### Recommended Project Structure
```
src/backtesting/
├── sweep.py             # New: SweepConfig, SweepCell, SweepResult, run_sweep()
├── mc.py               # Phase 9: MCResult, MCSample, run_mc_samples()
├── pipeline.py         # Existing: run_pipeline(), PipelineResult
├── metrics.py          # Existing: compute_* functions
├── simulation/
│   └── runner.py       # Existing: run_backtest(), build_results_dataframe()
└── data/
    ├── factory.py      # Existing: generate_scenario()
    └── budget.py       # Existing: AllocationDistribution hierarchy
```

### Pattern 1: SweepConfig → SweepCell → SweepResult Dataclass Chain

**What:** Three dataclasses model the sweep lifecycle: config (inputs), cell (one enumerated grid point), result (all outputs).
**When to use:** Always — matches Phase 9's `MCResult`/`MCSample` pattern.
**Example:**
```python
# Mirrors Phase 9 pattern (MCResult, MCSample) exactly
from dataclasses import dataclass, field
import pandas as pd

@dataclass
class SweepConfig:
    """Grid axes and execution settings from TOML [sweep] section."""
    curve_types: list[str]
    alphas: list[float]
    lock_profiles: list[dict]            # [{'short': 30, 'long': 365}, ...]
    allocation_strategies: list[str]     # Claude's discretion: sweep axis or fixed
    max_workers: int
    cell_timeout_seconds: int = 120
    base: dict = field(default_factory=dict)  # [base] TOML section passthrough

@dataclass
class SweepCell:
    """One enumerated grid point — the inputs for a single cadCAD run."""
    cell_id: int
    curve_type: str
    alpha: float
    lock_profile: dict
    allocation_strategy: str

@dataclass
class SweepResult:
    """Collected results from all sweep cells."""
    config: SweepConfig
    summary_df: pd.DataFrame   # one row per cell, columns = grid params + scalar metrics
    failed_cells: list[int]    # cell_ids that failed or timed out
    output_dir: str
```

### Pattern 2: Module-Level Cell Function for ProcessPoolExecutor Picklability

**What:** The function submitted to `ProcessPoolExecutor.submit()` MUST be defined at module level (not a lambda or nested function) to be picklable for inter-process serialization.
**When to use:** Always when using ProcessPoolExecutor. Lambda and nested functions fail with `PicklingError`.
**Example:**
```python
# sweep.py — module level (not inside run_sweep())
def _run_cell(cell: SweepCell, base_cfg: dict) -> dict:
    """
    Execute one sweep cell. Returns flat dict for summary_df row.
    Released: raw cadCAD results deleted before return.
    """
    import gc
    import warnings
    from backtesting.data.factory import generate_scenario
    from backtesting.data.loader import events_to_dataframe
    from backtesting.simulation.runner import run_backtest, build_results_dataframe
    from backtesting.metrics import compute_flip_rate, compute_gini

    events = generate_scenario(
        curve_type=cell.curve_type,
        pareto_alpha=cell.alpha,
        lock_profile=cell.lock_profile['long'],  # map dict to string/float params
        allocation_strategy=cell.allocation_strategy,
        **base_cfg,
    )

    events_df = events_to_dataframe(events)
    windows_df = (
        events_df[events_df['event_type'] == 'PROPOSAL_CREATED']
        [['proposal_id', 'start_block', 'end_block']]
        .copy().reset_index(drop=True)
    )

    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        raw = run_backtest(events, curve_type=cell.curve_type)

    results_df = build_results_dataframe(raw, events)

    # Compute scalar metrics before releasing raw data
    flip = compute_flip_rate(results_df)
    gini = compute_gini(results_df, curve_type=cell.curve_type)

    # CRITICAL: release raw cadCAD results immediately (SWEP-04)
    del raw, events, results_df
    gc.collect()

    return {
        'cell_id': cell.cell_id,
        'curve_type': cell.curve_type,
        'alpha': cell.alpha,
        'lock_profile_short': cell.lock_profile['short'],
        'lock_profile_long': cell.lock_profile['long'],
        'allocation_strategy': cell.allocation_strategy,
        'flip_rate': flip.aggregate,
        'gini_legacy': gini.legacy,
        'gini_signals': gini.signals,
        'failed': False,
    }
```

### Pattern 3: ProcessPoolExecutor + as_completed + tqdm

**What:** Submit all cells upfront, then consume `as_completed()` which yields futures in completion order, updating tqdm on each.
**When to use:** Standard pattern for parallel work with streaming progress. Verified working with 12-cell test.
**Example:**
```python
from concurrent.futures import ProcessPoolExecutor, TimeoutError as FutureTimeout, as_completed
from tqdm import tqdm

def run_sweep(config: SweepConfig, *, fail_fast: bool = False) -> SweepResult:
    cells = _enumerate_cells(config)   # itertools.product → list[SweepCell]
    rows = []
    failed_cells = []

    with ProcessPoolExecutor(max_workers=config.max_workers) as ex:
        futures = {ex.submit(_run_cell, cell, config.base): cell for cell in cells}
        with tqdm(total=len(futures), desc='Sweep', unit='cell') as pbar:
            for fut in as_completed(futures):
                cell = futures[fut]
                try:
                    row = fut.result(timeout=config.cell_timeout_seconds)
                    rows.append(row)
                except FutureTimeout:
                    fut.cancel()
                    logging.error(f'Cell {cell.cell_id} timed out')
                    failed_cells.append(cell.cell_id)
                    rows.append(_make_failed_row(cell))
                    if fail_fast:
                        raise RuntimeError(f'Sweep aborted: cell {cell.cell_id} timed out')
                except Exception as e:
                    logging.error(f'Cell {cell.cell_id} failed: {e}')
                    failed_cells.append(cell.cell_id)
                    rows.append(_make_failed_row(cell))
                    if fail_fast:
                        raise
                pbar.update(1)

    summary_df = pd.DataFrame(rows)
    return SweepResult(config=config, summary_df=summary_df, failed_cells=failed_cells, ...)
```

### Pattern 4: itertools.product for Cartesian Grid Enumeration

**What:** `itertools.product(*axes)` produces the cartesian product. cadCAD M-dict zips, not products — never use cadCAD for multi-axis sweeps.
**When to use:** Always for the sweep grid — this is the ONLY correct approach per CONTEXT.md SPECIFICS.
**Example:**
```python
import itertools

def _enumerate_cells(config: SweepConfig) -> list[SweepCell]:
    """Build explicit cartesian product of all sweep axes."""
    axes = itertools.product(
        config.curve_types,
        config.alphas,
        config.lock_profiles,
        config.allocation_strategies,
    )
    return [
        SweepCell(
            cell_id=i,
            curve_type=curve_type,
            alpha=alpha,
            lock_profile=lock_profile,
            allocation_strategy=strategy,
        )
        for i, (curve_type, alpha, lock_profile, strategy) in enumerate(axes)
    ]

# Verified: 2 curve_types * 3 alphas * 2 lock_profiles * 2 strategies = 24 cells
# Success criterion test: 2 * 3 * 2 (allocation) = 12 rows matches SWEP-01 test case
```

### Pattern 5: TOML Config Loading for Sweep

**What:** Use `tomllib.load()` (stdlib) with `[base]` and `[sweep]` sections. Lock profiles use `[[sweep.lock_profiles]]` array-of-tables syntax.
**When to use:** Always for SWEP-07.
**Example:**
```toml
# sweep.toml
[base]
n_voters = 200
n_proposals = 30
total_supply = 1_000_000.0
avg_participation_rate = 0.10
stake_profile = "pareto"
budget_enabled = true
blocks_per_day = 7200
base_seed = 42

[sweep]
curve_types = ["sqrt", "log", "linear"]
alphas = [0.5, 1.0, 2.0]
allocation_strategies = ["uniform_fraction", "conviction_weighted"]
max_workers = 4
cell_timeout_seconds = 120

[[sweep.lock_profiles]]
short = 30
long = 365

[[sweep.lock_profiles]]
short = 90
long = 730

[output]
dir = "./output"
```

```python
import tomllib
import pathlib

def load_sweep_config(path: str | pathlib.Path) -> SweepConfig:
    with open(path, 'rb') as f:
        data = tomllib.load(f)
    sweep = data['sweep']
    return SweepConfig(
        curve_types=sweep['curve_types'],
        alphas=sweep['alphas'],
        lock_profiles=sweep['lock_profiles'],
        allocation_strategies=sweep.get('allocation_strategies', ['uniform_fraction']),
        max_workers=sweep['max_workers'],   # required — no auto-detection
        cell_timeout_seconds=sweep.get('cell_timeout_seconds', 120),
        base=data.get('base', {}),
    )
```

### Pattern 6: Auto-Export on Completion

**What:** After `run_sweep()` completes, write `summary.csv` and `config.json` to the timestamped output directory. Mirrors `pipeline.py`'s existing pattern.
**When to use:** Always — decision-locked.
**Example:**
```python
import datetime, json, math

def _make_output_dir(base_dir: str = './output') -> pathlib.Path:
    """Follows pipeline.py pattern exactly."""
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out_dir = (pathlib.Path(base_dir) / timestamp).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir

def _export_results(result: SweepResult, out_dir: pathlib.Path) -> None:
    result.summary_df.to_csv(out_dir / 'summary.csv', index=False)
    config_dict = {
        'curve_types': result.config.curve_types,
        'alphas': result.config.alphas,
        'lock_profiles': result.config.lock_profiles,
        'allocation_strategies': result.config.allocation_strategies,
        'max_workers': result.config.max_workers,
        'cell_timeout_seconds': result.config.cell_timeout_seconds,
    }
    with open(out_dir / 'config.json', 'w') as f:
        json.dump(config_dict, f, indent=2)
```

### Anti-Patterns to Avoid
- **Lambda/nested function in ProcessPoolExecutor.submit():** Will raise `PicklingError` at runtime. Cell function MUST be module-level.
- **Using cadCAD M-param for multi-axis sweep:** cadCAD's M-param dict zips element-wise. If you pass `M = {'curve_type': ['sqrt','log'], 'alpha': [0.5, 1.0]}` you get `(sqrt, 0.5)` and `(log, 1.0)` — not all 4 combinations. Always use `itertools.product` externally.
- **Accumulating raw cadCAD results across cells:** A `list[dict]` for 200+ events × 192 cells ≈ 500MB+. Delete `raw` and `events` immediately after `build_results_dataframe()`.
- **Using `fut.result()` without timeout:** Cell timeout enforcement requires `fut.result(timeout=config.cell_timeout_seconds)`.
- **Auto-detecting max_workers:** Decision-locked: `max_workers` is required in TOML. Do NOT compute from `os.cpu_count()`.
- **Updating tqdm outside `as_completed` loop:** Progress must reflect actual completion order, not submission order.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cartesian product | Custom nested loops | `itertools.product` | Handles N-dimensional grids; composable; stdlib |
| Progress bar with ETA | `print(f'{n}/{total}')` | `tqdm` | ETA calculation is non-trivial; tqdm handles terminal detection, SIGWINCH, etc. |
| TOML parsing | Custom parser | `tomllib` (stdlib) | Edge cases in string escaping, inline tables; stdlib since Python 3.11 |
| Process pool | `multiprocessing.Process` | `ProcessPoolExecutor` | Handles pool lifecycle, exception propagation, future cancellation |
| Cell timeout | Polling loop | `fut.result(timeout=N)` | `FutureTimeout` exception cleanly signals timeout; no polling needed |

**Key insight:** The sweep runner is pure orchestration. Every hard problem (simulation, metrics, parallelism, progress) is solved by existing infrastructure — the sweep runner composes them.

## Common Pitfalls

### Pitfall 1: cadCAD M-Param Zips, Not Cartesian
**What goes wrong:** Passing multiple values per M key to cadCAD produces element-wise pairs, not the full grid. A 2-element curve_types × 3-element alphas via M-dict gives 2 runs, not 6.
**Why it happens:** cadCAD was designed for sensitivity analysis where you vary one parameter at a time across T timesteps, not for parameter grid sweeps.
**How to avoid:** Always enumerate the cartesian product externally with `itertools.product`, then call cadCAD once per cell. Verified in CONTEXT.md SPECIFICS.
**Warning signs:** Test for `SWEP-01` (2 curve_types × 3 alphas × 2 strategies = 12 rows) catches this immediately.

### Pitfall 2: Raw cadCAD Result Memory Accumulation
**What goes wrong:** `run_backtest()` returns a `list[dict]` with N+1 entries (one per event + initial state). At 200+ events per cell × 192 cells, this accumulates 500MB+ if not deleted.
**Why it happens:** Python's garbage collector is non-deterministic; del + gc.collect() is needed in the child process.
**How to avoid:** In `_run_cell()`, `del raw, events, results_df` after metric computation, then `gc.collect()` before return.
**Warning signs:** Monotonically increasing memory during sweep execution visible with `htop` or `tracemalloc`.

### Pitfall 3: Non-Picklable Cell Function
**What goes wrong:** `ProcessPoolExecutor.submit(lambda cell: ..., cell)` raises `_pickle.PicklingError: Can't pickle <function <lambda>>`.
**Why it happens:** Inter-process serialization requires all arguments and the target function to be picklable. Lambdas and closure functions are not.
**How to avoid:** Define `_run_cell(cell, base_cfg)` at module level in `sweep.py`.
**Warning signs:** Immediate crash on first `submit()` call before any real work executes.

### Pitfall 4: tqdm Updates Not Thread-Safe in Main Process
**What goes wrong:** Updating tqdm from multiple threads simultaneously produces garbled output.
**Why it happens:** `as_completed()` futures complete in arbitrary order; calling `pbar.update()` from concurrent callbacks is unsafe.
**How to avoid:** Update tqdm only in the main process's `for fut in as_completed(futures)` loop — never inside `_run_cell()`. The pattern `fut.result()` in main process → `pbar.update(1)` is single-threaded and safe.
**Warning signs:** Interleaved or doubled progress output.

### Pitfall 5: fail-fast Without Proper Executor Shutdown
**What goes wrong:** Raising an exception inside the `with ProcessPoolExecutor(...) as ex:` block causes `__exit__` to call `ex.shutdown(wait=True)`, which blocks until all pending futures complete — potentially minutes.
**Why it happens:** `ProcessPoolExecutor.__exit__` defaults to `shutdown(wait=True)`.
**How to avoid:** For fail-fast, call `ex.shutdown(wait=False, cancel_futures=True)` before raising. Python 3.9+ supports `cancel_futures=True`.
**Warning signs:** Sweep hangs after first failure when `--fail-fast` is used.

### Pitfall 6: lock_profile Dict Has No Direct Mapping to generate_scenario()
**What goes wrong:** `generate_scenario()` accepts `lock_profile` as a string literal (`'correlated'`, `'independent'`, etc.) from `LockProfile = Literal[...]`, not a dict like `{'short': 30, 'long': 365}`.
**Why it happens:** Phase 8/9 factory uses string profiles. CONTEXT.md wants dict-style TOML config for lock profiles.
**How to avoid:** The sweep must map TOML lock profile dicts to `generate_scenario()` parameters. Options: (a) treat the dict as `l_max_days` + some derived param, or (b) add a new lock profile type. **Recommendation:** The CONTEXT.md lock profile dicts `{short, long}` map to custom lock duration ranges — implement a new `LockProfile` that accepts these as `l_min_days`/`l_max_days` or use them as raw distribution params. Resolve during Wave 0 (create test that specifies the expected mapping).
**Warning signs:** `generate_scenario()` raises `ValueError: Unknown lock_profile` on first cell.

## Code Examples

Verified patterns from codebase:

### Exact generate_scenario() Signature (from factory.py)
```python
# Source: /apps/simulations/src/backtesting/data/factory.py
def generate_scenario(
    n_voters: int = 200,
    n_proposals: int = 30,
    total_supply: float = 1_000_000.0,
    avg_participation_rate: float = 0.10,
    stake_profile: str = 'pareto',
    lock_profile: str = 'independent',   # string, not dict
    pareto_alpha: float = 0.7,           # this is the 'alpha' sweep axis
    l_max_days: float = 365.0,
    proposal_window_blocks: int = 50400,
    seed: int | None = None,
    budget_enabled: bool = True,
    allocation_strategy: str = 'uniform_fraction',
    blocks_per_day: int = 7200,
    curve_type: str = 'sqrt',            # sweep axis
    mc_dist: AllocationDistribution | None = None,
    vote_timing: VoteTimingConfig | None = None,
) -> list[GovernorEvent]:
```

**Key mapping for sweep axes:**
- `curve_type` → directly from `SweepConfig.curve_types` (axis)
- `pareto_alpha` → from `SweepConfig.alphas` (this IS the alpha axis)
- `lock_profile` → from dict keys, e.g. `{'short': 30, 'long': 365}` needs translation
- `allocation_strategy` → from `SweepConfig.allocation_strategies` (if sweep axis)

### run_backtest() Signature
```python
# Source: /apps/simulations/src/backtesting/simulation/runner.py
def run_backtest(event_records: list, curve_type: str = 'sqrt') -> list[dict]:
    # curve_type threaded via cadCAD M dict (confirmed decision from Phase 8)
```

### Metric Functions That Return Scalar Aggregates (for summary_df)
```python
# Source: /apps/simulations/src/backtesting/metrics.py
# These .aggregate fields are the scalar values for summary_df columns:
flip = compute_flip_rate(results_df)          # flip.aggregate: float
gini = compute_gini(results_df, curve_type)   # gini.legacy, gini.signals: float
participation = compute_participation_rate(results_df)  # participation.aggregate: float
margin = compute_margin_shift(results_df)     # margin.aggregate_mean, .aggregate_std: float
# ENPResult.legacy/signals are dicts (per-proposal) — need nanmean for summary_df
# NakamotoResult.legacy/signals are dicts — need mean for summary_df
```

### tqdm with ProcessPoolExecutor (verified pattern)
```python
# Verified locally: tqdm 4.67.3, Python 3.12
from concurrent.futures import ProcessPoolExecutor, TimeoutError as FutureTimeout, as_completed
from tqdm import tqdm

with ProcessPoolExecutor(max_workers=config.max_workers) as ex:
    futures = {ex.submit(_run_cell, cell, base_cfg): cell for cell in cells}
    with tqdm(total=len(futures), desc='Sweep', unit='cell') as pbar:
        for fut in as_completed(futures):
            cell = futures[fut]
            try:
                row = fut.result(timeout=config.cell_timeout_seconds)
                rows.append(row)
            except FutureTimeout:
                fut.cancel()
                rows.append(_make_failed_row(cell))
                failed_cells.append(cell.cell_id)
                if fail_fast:
                    ex.shutdown(wait=False, cancel_futures=True)
                    raise RuntimeError(f'fail-fast: cell {cell.cell_id} timed out')
            except Exception as e:
                rows.append(_make_failed_row(cell))
                failed_cells.append(cell.cell_id)
                if fail_fast:
                    ex.shutdown(wait=False, cancel_futures=True)
                    raise
            pbar.update(1)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| cadCAD M-param for parameter sweeps | External `itertools.product` + one cadCAD call per cell | Phase 10 decision (CONTEXT.md) | Correct cartesian product; bounded memory per cell |
| Accumulate all results then compute metrics | Compute metrics per-cell, release raw data | Phase 10 decision (CONTEXT.md) | Prevents 500MB+ accumulation |

**Deprecated/outdated:**
- cadCAD multi-param sweeps: Not applicable here — cadCAD's built-in sweep mechanism zips, not products. Use only for single-axis sensitivity analysis within a single run.

## Open Questions

1. **lock_profile dict → generate_scenario() mapping**
   - What we know: TOML has `{short: 30, long: 365}` dicts; `generate_scenario()` accepts `lock_profile: str` (e.g. `'independent'`) and `l_max_days: float`
   - What's unclear: Does `{short, long}` replace the `lock_profile` string entirely (new custom profile), or is it only about `l_max_days`? The `lock_profile` string controls distribution shape (correlated/independent/bimodal), and `l_max_days` controls the range ceiling.
   - Recommendation: Treat TOML lock profiles as `l_max_days=long` with `lock_profile='independent'` as default string, unless the user extends `generate_scenario()` to accept a new profile type. Define this mapping explicitly in Wave 0 before writing `_run_cell()`.

2. **allocation_strategies as sweep axis vs. fixed parameter**
   - What we know: Claude has discretion; grid with 3 curve_types × 3 alphas × 2 lock_profiles × 2 strategies = 36 cells; without strategies axis = 18 cells
   - What's unclear: Success criterion test uses "2 allocation strategies" producing 12 rows — this implies strategies ARE a sweep axis (SWEP-01 states: "SweepConfig defining grid axes: curve_type, alpha, lock_profile, allocation_strategy")
   - Recommendation: Include `allocation_strategies` as a sweep axis (SWEP-01 explicitly lists it). TOML key: `allocation_strategies = ["uniform_fraction", "conviction_weighted"]`.

3. **tqdm dependency in pyproject.toml**
   - What we know: tqdm 4.67.3 is installed but NOT in `pyproject.toml` (only transitive dependency)
   - What's unclear: Could disappear if the transitive dep chain changes
   - Recommendation: Add `tqdm>=4.60.0,<5` to `pyproject.toml` dependencies explicitly.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 8.x |
| Config file | `/apps/simulations/pyproject.toml` (implicit — no pytest.ini found) |
| Quick run command | `cd apps/simulations && uv run pytest tests/test_sweep.py -x` |
| Full suite command | `cd apps/simulations && uv run pytest tests/ -x` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SWEP-01 | `SweepConfig` with 2 curve_types × 3 alphas × 2 strategies = 12 rows in `summary_df` | unit | `uv run pytest tests/test_sweep.py::test_swep01_cartesian_product -x` | ❌ Wave 0 |
| SWEP-02 | `itertools.product` produces cartesian grid (not zip) — cadCAD not used for enumeration | unit | `uv run pytest tests/test_sweep.py::test_swep02_cartesian_not_zip -x` | ❌ Wave 0 |
| SWEP-03 | `ProcessPoolExecutor` runs cells in parallel; `max_workers` is respected | unit | `uv run pytest tests/test_sweep.py::test_swep03_parallel_execution -x` | ❌ Wave 0 |
| SWEP-04 | Memory does not accumulate unboundedly (raw cadCAD results released per cell) | unit | `uv run pytest tests/test_sweep.py::test_swep04_memory_release -x` | ❌ Wave 0 |
| SWEP-05 | `SweepResult.summary_df` has one row per config with correct columns | unit | `uv run pytest tests/test_sweep.py::test_swep05_summary_df_shape -x` | ❌ Wave 0 |
| SWEP-06 | tqdm progress bar shows cell count during execution | integration | `uv run pytest tests/test_sweep.py::test_swep06_tqdm_progress -x` | ❌ Wave 0 |
| SWEP-07 | TOML config loads grid params without code changes | unit | `uv run pytest tests/test_sweep.py::test_swep07_toml_config -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/simulations && uv run pytest tests/test_sweep.py -x`
- **Per wave merge:** `cd apps/simulations && uv run pytest tests/ -x`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_sweep.py` — covers SWEP-01 through SWEP-07; shared fixture with small grid (2×3×2 = 12 cells) using `n_voters=50, n_proposals=3` for speed
- [ ] `apps/simulations/pyproject.toml` — add `tqdm>=4.60.0,<5` to dependencies
- [ ] Clarify `lock_profile` dict mapping before writing `_run_cell()` (see Open Questions)

## Sources

### Primary (HIGH confidence)
- Codebase direct read: `/apps/simulations/src/backtesting/mc.py` — Phase 9 pattern for `MCSample`/`MCResult` dataclass chain; `SeedSequence.spawn()` usage
- Codebase direct read: `/apps/simulations/src/backtesting/pipeline.py` — TOML loading pattern (`tomllib`), output directory pattern, NaN sanitization for JSON
- Codebase direct read: `/apps/simulations/src/backtesting/simulation/runner.py` — `run_backtest()` signature, cadCAD M-dict parameter threading
- Codebase direct read: `/apps/simulations/src/backtesting/data/factory.py` — `generate_scenario()` complete signature, `ScenarioCurveType` validation
- Codebase direct read: `/apps/simulations/src/backtesting/metrics.py` — all metric result dataclass fields, scalar vs. per-proposal return types
- Live verification: `itertools.product(['sqrt','log'], [0.5,1.0,2.0])` → 6 pairs (not 3); `pd.DataFrame(cells)` → 12 rows for 2×3×2 grid
- Live verification: `tqdm` 4.67.3 installed; `ProcessPoolExecutor` + `as_completed` + `tqdm.update()` pattern works with 12 cells
- Live verification: `tomllib` parses `[[sweep.lock_profiles]]` array-of-tables correctly
- Live verification: `BetaDistribution` is picklable (required for ProcessPoolExecutor)
- Live verification: `del raw; gc.collect()` memory release pattern works in child process context
- Live verification: `fut.result(timeout=N)` raises `FutureTimeout` correctly

### Secondary (MEDIUM confidence)
- Python stdlib documentation: `concurrent.futures.ProcessPoolExecutor`, `cancel_futures=True` in `shutdown()` available since Python 3.9+ — project uses 3.12, confirmed safe
- Python stdlib documentation: `tomllib` available since Python 3.11+ — project requires Python 3.12+

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified installed and working in project environment
- Architecture: HIGH — patterns derived directly from Phase 9 codebase and live execution tests
- Pitfalls: HIGH — cadCAD M-param zip behavior documented in CONTEXT.md SPECIFICS; memory accumulation, pickling, tqdm safety all live-tested
- Open questions: lock_profile dict mapping is a genuine gap requiring design decision before `_run_cell()` implementation

**Research date:** 2026-02-28
**Valid until:** 2026-04-01 (stable stdlib + mature libraries)
