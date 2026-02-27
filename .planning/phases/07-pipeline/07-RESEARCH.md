# Phase 7: Pipeline - Research

**Researched:** 2026-02-27
**Domain:** Python CLI orchestration, TOML configuration, module entry points, dataclass return types
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Invocation & CLI design**
- Entry point: `python -m backtesting.pipeline` (module-style, no console script)
- Flags: `--output` (directory, default `./output`), `--name` (experiment name, optional), `--config` (config file path, optional), `--init` (generate starter config), `-v` (verbose)
- When `--name` provided: output goes to `<output>/<name>/`
- When `--name` omitted: output goes to `<output>/<timestamp>/` (auto-generated)
- Silent by default; `-v` prints stage names (Generating data... Running simulation... Computing metrics... Plotting...)

**Output structure**
- Flat directory per experiment — all files in one folder (no subdirectories)
- Plots saved as PNG
- Each run isolated in its own named or timestamped directory under the output path

**Configuration**
- TOML format (`backtesting.toml`)
- Auto-discover config in current working directory; `--config` flag to point elsewhere
- `--init` flag writes a starter `backtesting.toml` with commented defaults
- Internal defaults used when no config file found (pipeline works out of the box)

**Programmatic API**
- Single function: `from backtesting.pipeline import run_pipeline`
- Returns a typed `PipelineResult` dataclass with `.metrics`, `.plot_paths`, `.output_dir` attributes
- Accepts config as dict or file path: `run_pipeline(config='path.toml')` or `run_pipeline(config={'timesteps': 100})`
- Always writes output files to disk (consistent with CLI behavior)
- No dry-run mode — keep v1 simple

### Claude's Discretion
- Metrics file format (JSON, CSV, or both)
- Exact `PipelineResult` field names and structure
- Error handling strategy (what happens when a stage fails)
- Config schema and default parameter values

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PIPE-01 | Single entry point orchestrates data generation → simulation → metrics → plots | `argparse` + `__main__.py` pattern; `run_pipeline()` calls each layer in sequence |
| PIPE-02 | Pipeline outputs are saved to a configurable output directory | `pathlib.Path.mkdir(parents=True, exist_ok=True)` + `fig.savefig()` + JSON/CSV dump |
| PIPE-03 | Pipeline can be run from CLI or imported as a Python module | `if __name__ == '__main__'` in `__main__.py` calls `run_pipeline()`; module exports `run_pipeline` and `PipelineResult` |
</phase_requirements>

## Summary

Phase 7 is an orchestration layer — no new domain logic, only wiring. The four prior phases have established clean, composable APIs: `generate_scenario()` produces events, `run_backtest()` + `build_results_dataframe()` runs the simulation, the `compute_*` functions in `metrics.py` produce frozen dataclasses, and the `plot_*` functions in `plots.py` return `Figure` objects. The pipeline's sole job is to call these in order, parameterize them from a TOML config, write outputs to disk, and return a typed result to the caller.

The key technical insight is that Python 3.11+ ships `tomllib` in the standard library (read-only; writing TOML requires either `tomli_w` or manual string construction). The project runs Python 3.12 and has no external TOML dependency. For writing the starter config via `--init`, the simplest correct approach is to embed the template as a string literal and write it directly — no TOML writer library needed. For reading, `tomllib.loads()` or `tomllib.load()` from stdlib is all that is required.

The pipeline module lives at `backtesting/pipeline.py` (or `backtesting/pipeline/__init__.py`) with a `__main__.py` sibling for the `-m` entry point. The `PipelineResult` dataclass is a natural fit for the return type: it is frozen, typed, and directly inspectable by callers. Metric outputs stored as JSON (stdlib `json`) are a clean, portable choice over CSV for structured nested data. Error handling should propagate stage exceptions with clear labels ("Stage 1 failed: ...") without silencing them.

**Primary recommendation:** Implement `backtesting/pipeline.py` as a single module (no subpackage needed), with `backtesting/__main__.py` delegating to it. Use stdlib `tomllib`, `argparse`, `pathlib`, `json`, and `datetime` exclusively — zero new dependencies.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `tomllib` | stdlib (Python 3.11+) | Read TOML config | Built-in, no extra install; project is Python 3.12 |
| `argparse` | stdlib | CLI flag parsing | Built-in, consistent with Python idioms; no click/typer dep |
| `pathlib` | stdlib | Output dir creation, path construction | Clean OO API; already used implicitly in plots |
| `json` | stdlib | Metrics output serialization | Portable, human-readable; structured nested data maps naturally |
| `datetime` | stdlib | Auto-generate timestamped experiment name | `datetime.now().strftime('%Y%m%d_%H%M%S')` is the standard pattern |
| `dataclasses` | stdlib | `PipelineResult` return type | Already used throughout the codebase (`metrics.py` frozen dataclasses) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `warnings` | stdlib | Suppress cadCAD output during pipeline run | cadCAD emits warnings during `Executor.execute()`; existing tests use `warnings.catch_warnings()` |
| `matplotlib.figure.Figure` | already installed | Receive plot return values | `plots.py` functions return `Figure`; pipeline calls `fig.savefig(path)` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `json` metrics file | CSV | JSON handles nested dicts (e.g., `per_proposal`, `legacy`/`signals` sub-dicts) without flattening complexity |
| `json` metrics file | Both JSON + CSV | Adds complexity; not required for v1 |
| Embedded TOML template string | `tomli_w` | `tomli_w` is an extra dependency; template string is self-documenting and zero-cost |
| `argparse` | `click` or `typer` | `click`/`typer` not in pyproject.toml; adding them for a simple 4-flag CLI is unjustified |

**Installation:** No new dependencies required.

## Architecture Patterns

### Recommended Project Structure

```
apps/simulations/src/backtesting/
├── __init__.py           # existing
├── __main__.py           # NEW: python -m backtesting entry point → delegates to pipeline.py
├── pipeline.py           # NEW: run_pipeline(), PipelineResult, _load_config(), _parse_args()
├── data/                 # Phase 3 (existing)
├── simulation/           # Phase 4 (existing)
├── metrics.py            # Phase 5 (existing)
├── plots.py              # Phase 6 (existing)
└── weighting/            # Phase 3 (existing)
```

No subpackage is needed. `pipeline.py` is a single flat module.

### Pattern 1: Module Entry Point (`__main__.py`)

**What:** Python executes `package/__main__.py` when invoked as `python -m package`. The `__main__.py` calls `main()` from `pipeline.py`.

**When to use:** Always when a package should be runnable as a script without a console_scripts entry point.

**Example:**
```python
# backtesting/__main__.py
from backtesting.pipeline import main

if __name__ == '__main__':
    main()
```

### Pattern 2: `run_pipeline()` with Config Union Type

**What:** A single public function accepting config as either a dict or a path string/Path. Resolved to a dict internally before the pipeline stages run.

**Example:**
```python
# backtesting/pipeline.py
from __future__ import annotations
import tomllib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Union

@dataclass(frozen=True)
class PipelineResult:
    metrics: dict          # keyed by metric name, values are dicts
    plot_paths: list[str]  # absolute paths to saved PNG files
    output_dir: str        # absolute path to experiment output directory

def run_pipeline(
    config: Union[dict, str, Path, None] = None,
    verbose: bool = False,
) -> PipelineResult:
    cfg = _resolve_config(config)
    out_dir = _make_output_dir(cfg)
    events = _stage_generate(cfg, verbose)
    results_df, windows_df = _stage_simulate(events, verbose)
    metrics = _stage_metrics(results_df, windows_df, verbose)
    plot_paths = _stage_plots(results_df, windows_df, metrics, out_dir, verbose)
    _save_metrics(metrics, out_dir)
    return PipelineResult(
        metrics=metrics,
        plot_paths=[str(p) for p in plot_paths],
        output_dir=str(out_dir),
    )
```

### Pattern 3: TOML Config Discovery

**What:** Auto-discover `backtesting.toml` in CWD; fall back to internal defaults if absent.

**Example:**
```python
import tomllib
from pathlib import Path

_DEFAULTS: dict = {
    'data': {
        'n_voters': 200,
        'n_proposals': 30,
        'seed': 42,
        'stake_profile': 'pareto',
    },
    'output': {
        'dir': './output',
        'name': None,
    },
}

def _resolve_config(config) -> dict:
    if config is None:
        # auto-discover
        toml_path = Path.cwd() / 'backtesting.toml'
        if toml_path.exists():
            with open(toml_path, 'rb') as f:
                user = tomllib.load(f)
        else:
            user = {}
    elif isinstance(config, (str, Path)):
        with open(config, 'rb') as f:
            user = tomllib.load(f)
    else:
        user = config  # already a dict
    # Deep merge user over defaults
    return _deep_merge(_DEFAULTS, user)
```

### Pattern 4: Writing Windows DataFrame

**What:** The timing metrics (`compute_late_vote_share`, `compute_lockin_timing`) require a `windows_df` with `proposal_id`, `start_block`, `end_block`. This is extracted from the loader DataFrame, not from the results DataFrame.

The loader DataFrame (from `events_to_dataframe()`) has `PROPOSAL_CREATED` rows with `start_block` / `end_block`. This must be captured before converting to the simulation-only results DataFrame.

**Example:**
```python
from backtesting.data.loader import events_to_dataframe, SyntheticLoader
from backtesting.simulation.runner import run_backtest, build_results_dataframe

def _stage_simulate(events, verbose):
    loader_df = events_to_dataframe(events)
    windows_df = (
        loader_df[loader_df['event_type'] == 'PROPOSAL_CREATED']
        [['proposal_id', 'start_block', 'end_block']]
        .copy()
        .reset_index(drop=True)
    )
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        raw = run_backtest(events)
    results_df = build_results_dataframe(raw, events)
    return results_df, windows_df
```

### Pattern 5: Saving Matplotlib Figures

**What:** `plots.py` functions return `Figure` objects (OO API). The pipeline calls `fig.savefig(path)`. matplotlib's `Agg` backend is already set at `plots.py` import time — no additional backend setup needed.

**Example:**
```python
def _save_figure(fig, path: Path) -> None:
    fig.savefig(str(path), dpi=300, bbox_inches='tight')
    fig.clf()   # release memory
```

### Pattern 6: Metrics Serialization to JSON

**What:** The metric dataclasses contain `dict`, `float`, `int`, `bool` values. Some values are `float('nan')` which is not valid JSON. These must be converted to `None` (JSON `null`) before serializing.

**Example:**
```python
import math, json

def _nan_to_none(v):
    if isinstance(v, float) and math.isnan(v):
        return None
    if isinstance(v, dict):
        return {k: _nan_to_none(vv) for k, vv in v.items()}
    return v

def _metrics_to_json_safe(metrics: dict) -> dict:
    return {k: _nan_to_none(v) for k, v in metrics.items()}
```

### Pattern 7: `--init` Starter Config

**What:** Write a hardcoded TOML template string to `backtesting.toml` in CWD. No TOML writer library needed.

**Example:**
```python
_STARTER_TOML = """\
# backtesting.toml — Signals backtesting configuration
# All values shown are defaults. Uncomment and edit as needed.

[data]
# n_voters = 200
# n_proposals = 30
# seed = 42
# stake_profile = "pareto"   # "pareto" | "uniform" | "bimodal"
# lock_profile = "independent"  # "correlated" | "inverse_correlated" | "independent" | "bimodal"

[output]
# dir = "./output"
# name = ""   # empty = auto-timestamp
"""

def _write_init_config() -> None:
    dest = Path.cwd() / 'backtesting.toml'
    dest.write_text(_STARTER_TOML)
    print(f'Written: {dest}')
```

### Anti-Patterns to Avoid

- **Calling `plt.savefig()` instead of `fig.savefig()`:** `plots.py` uses the OO API — never import `matplotlib.pyplot` in the pipeline. `fig.savefig()` is the correct call.
- **Importing `plots.py` at module level without Agg guard:** `plots.py` sets `matplotlib.use('Agg')` at import time as its first action, so importing `backtesting.plots` is safe. Do not re-call `matplotlib.use()` in the pipeline.
- **Passing events list directly to metrics functions:** Metrics functions take `results_df` (from `build_results_dataframe`), not the raw events list. `windows_df` is a separate DataFrame extracted from the loader layer.
- **Assuming `proposal_story` and `cumulative_vote_curve` apply to all proposals:** These per-proposal plots (`PLOT-07`, `PLOT-10`) require picking a representative proposal ID. The pipeline should default to the first proposal or iterate over all proposals and save one file per proposal.
- **Not releasing Figure memory:** Call `fig.clf()` or `matplotlib.pyplot.close(fig)` after `savefig` to avoid memory accumulation when plotting many proposals.
- **Deep-merging config with naive dict update:** `dict.update()` overwrites top-level keys (including nested dicts). Use recursive deep-merge so `[data]` section in user TOML only overrides specified keys.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOML parsing | Custom parser | `tomllib` (stdlib, Python 3.11+) | TOML has edge cases; stdlib is correct and zero-cost |
| CLI flag parsing | `sys.argv` manual parsing | `argparse` (stdlib) | Handles help text, type coercion, mutual exclusion automatically |
| Timestamp generation | Custom format | `datetime.now().strftime('%Y%m%d_%H%M%S')` | Sortable, filesystem-safe, human-readable |
| NaN-safe JSON encoding | Custom encoder class | Simple recursive `_nan_to_none()` helper | `json.JSONEncoder` subclass is more code than necessary |
| Output path construction | String concatenation | `pathlib.Path` | Handles OS-specific separators, `mkdir(parents=True, exist_ok=True)` |

**Key insight:** This phase is 100% wiring — every non-trivial operation is already handled by stdlib or prior-phase modules. Any custom solution built here is a liability.

## Common Pitfalls

### Pitfall 1: `windows_df` Not Extracted Before Simulation

**What goes wrong:** The pipeline calls `run_backtest()` and `build_results_dataframe()` to produce `results_df`. But timing metrics need `windows_df` from the loader DataFrame, which contains `PROPOSAL_CREATED` rows with `start_block`/`end_block`. If the pipeline discards the loader DataFrame, these metrics will fail.

**Why it happens:** It's easy to think `results_df` is the only DataFrame needed, since it's what all other metrics consume.

**How to avoid:** Extract `windows_df` from `events_to_dataframe(events)` before running the simulation. The conftest pattern in `tests/conftest.py` (`metrics_windows_df` fixture) demonstrates the exact extraction pattern.

**Warning signs:** `KeyError` or `NaN` on `start_block`/`end_block` in timing metrics.

### Pitfall 2: `float('nan')` Breaking JSON Serialization

**What goes wrong:** `json.dumps({'value': float('nan')})` raises `ValueError` (by default) or silently writes `NaN` (if `allow_nan=True`), which is not valid JSON.

**Why it happens:** Several metric functions return `nan` for proposals with no votes (METR-08, METR-09 explicitly documented this in the STATE.md).

**How to avoid:** Apply the `_nan_to_none()` recursive converter before `json.dumps()`. Use `json.dumps(data, indent=2)` for readable output.

**Warning signs:** `ValueError: Out of range float values are not JSON compliant`.

### Pitfall 3: Per-Proposal Plots for All Proposals

**What goes wrong:** `plot_cumulative_vote_curve` (PLOT-07) and `plot_proposal_story` (PLOT-10) each take a single `proposal_id`. If the pipeline only plots one proposal, it may not be representative. If it plots all proposals, file naming must ensure no collisions.

**Why it happens:** The CONTEXT.md does not specify which proposals to plot — this is Claude's discretion.

**How to avoid:** Generate one PNG per proposal using `{plot_name}_{proposal_id}.png` naming. The `proposal_id` values in the codebase are strings (e.g., `'p1'`, `'p2'`), safe to use in filenames.

**Warning signs:** FileNotFoundError from invalid characters in proposal_id (unlikely with synthetic data but should be sanitized).

### Pitfall 4: cadCAD Warnings Polluting Verbose Output

**What goes wrong:** `run_backtest()` generates cadCAD deprecation warnings. In `-v` mode, these mix with stage progress messages, making output confusing.

**Why it happens:** All existing tests use `warnings.catch_warnings(); warnings.simplefilter('ignore')` to suppress this. The pipeline must do the same.

**How to avoid:** Wrap `run_backtest()` in `warnings.catch_warnings()` with `simplefilter('ignore')` in the simulation stage. For `-v`, print before entering the suppress context.

### Pitfall 5: Config `--output` Path Resolution

**What goes wrong:** If `--output` is a relative path (e.g., `./output`), and the module is invoked from a different working directory than expected, outputs land in the wrong place.

**Why it happens:** Relative paths are resolved against CWD at runtime, which is correct — but callers expect consistency.

**How to avoid:** Resolve to absolute path early: `out_dir = Path(output_arg).resolve()`. Store absolute path in `PipelineResult.output_dir`.

### Pitfall 6: Frozen Dataclass Metrics Cannot Be Directly JSON-Serialized

**What goes wrong:** The metric results are frozen dataclasses (e.g., `FlipRateResult`, `GiniResult`). `json.dumps(flip_result)` raises `TypeError: Object of type FlipRateResult is not JSON serializable`.

**Why it happens:** `json` doesn't know how to handle dataclasses by default.

**How to avoid:** Use `dataclasses.asdict()` to convert each metric result to a plain dict before JSON serialization. Then apply the NaN-to-None converter.

```python
import dataclasses
metrics_dict = {
    'flip_rate': dataclasses.asdict(flip_result),
    'gini': dataclasses.asdict(gini_result),
    ...
}
```

## Code Examples

Verified patterns from existing codebase:

### Full Pipeline Call Sequence (from conftest.py pattern)

```python
# Source: tests/conftest.py + backtesting.simulation.runner
from backtesting.data.factory import generate_scenario
from backtesting.data.loader import events_to_dataframe
from backtesting.simulation.runner import run_backtest, build_results_dataframe
from backtesting.metrics import (
    compute_flip_rate, compute_gini, compute_participation_rate,
    compute_enp, compute_nakamoto_coefficient, compute_margin_shift,
    compute_transition_matrix, compute_late_vote_share,
    compute_lockin_timing, compute_top_k_concentration,
)
from backtesting.plots import (
    plot_flip_rate_summary, plot_margin_shift_histogram,
    plot_transition_matrix, plot_gini_comparison,
    plot_top_k_comparison, plot_enp_comparison,
    plot_cumulative_vote_curve, plot_late_vote_share,
    plot_lorenz_curve, plot_proposal_story,
    plot_lock_duration_histogram,
)
import warnings

# Stage 1: Data
events = generate_scenario(n_voters=200, n_proposals=30, seed=42)

# Stage 2: Simulation — extract windows_df BEFORE run_backtest
loader_df = events_to_dataframe(events)
windows_df = (
    loader_df[loader_df['event_type'] == 'PROPOSAL_CREATED']
    [['proposal_id', 'start_block', 'end_block']]
    .copy().reset_index(drop=True)
)
with warnings.catch_warnings():
    warnings.simplefilter('ignore')
    raw = run_backtest(events)
results_df = build_results_dataframe(raw, events)

# Stage 3: Metrics
flip_result = compute_flip_rate(results_df)
gini_result = compute_gini(results_df)
late_result = compute_late_vote_share(results_df, windows_df)
lockin_result = compute_lockin_timing(results_df, windows_df)
# ...etc...

# Stage 4: Plots
fig = plot_flip_rate_summary(flip_result)
fig.savefig('output/flip_rate.png', dpi=300, bbox_inches='tight')
```

### `argparse` Setup Pattern

```python
import argparse

def _parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog='python -m backtesting.pipeline',
        description='Run the Signals backtesting pipeline end-to-end.',
    )
    p.add_argument('--output', default='./output', metavar='DIR',
                   help='Output directory (default: ./output)')
    p.add_argument('--name', default=None, metavar='NAME',
                   help='Experiment name (default: auto-timestamped)')
    p.add_argument('--config', default=None, metavar='PATH',
                   help='Path to backtesting.toml config file')
    p.add_argument('--init', action='store_true',
                   help='Write starter backtesting.toml and exit')
    p.add_argument('-v', '--verbose', action='store_true',
                   help='Print stage progress')
    return p.parse_args(argv)
```

### `tomllib` Read Pattern (Python 3.12 stdlib)

```python
import tomllib
from pathlib import Path

# Read from file
with open('backtesting.toml', 'rb') as f:   # note: 'rb' mode required
    cfg = tomllib.load(f)

# Read from string
cfg = tomllib.loads('[data]\nn_voters = 200\n')
```

### `dataclasses.asdict()` for JSON Output

```python
import dataclasses, json, math

def _nan_to_none(obj):
    if isinstance(obj, float) and math.isnan(obj):
        return None
    if isinstance(obj, dict):
        return {k: _nan_to_none(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_nan_to_none(x) for x in obj]
    return obj

metrics_dict = {
    'flip_rate': _nan_to_none(dataclasses.asdict(flip_result)),
    'gini': _nan_to_none(dataclasses.asdict(gini_result)),
    # ...
}
with open(out_dir / 'metrics.json', 'w') as f:
    json.dump(metrics_dict, f, indent=2)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tomli` third-party package | `tomllib` stdlib | Python 3.11 | Zero-dep TOML reading; `tomllib.load()` requires `'rb'` mode |
| `console_scripts` entry point | `python -m package` | Design decision | No install step; works directly from `src/` layout with PYTHONPATH or editable install |
| `plt.savefig()` (stateful) | `fig.savefig()` (OO API) | Phase 6 decision | Required by PLOT-12; pipeline must not use `pyplot` |

**Deprecated/outdated:**
- `tomllib.loads()` vs `tomllib.load()`: `load()` takes a binary file object (`'rb'`); `loads()` takes a string. Both are stdlib in Python 3.11+.

## Open Questions

1. **Which proposals to use for per-proposal plots (PLOT-07, PLOT-10)**
   - What we know: These take a single `proposal_id`; synthetic data has N proposals
   - What's unclear: Should pipeline plot all proposals or just one representative?
   - Recommendation: Plot all proposals; use `{plot_name}_{proposal_id}.png` filename pattern. Adds N*2 files but is complete and deterministic.

2. **Metrics file format**
   - What we know: CONTEXT.md leaves this to Claude's discretion
   - What's unclear: JSON vs CSV vs both
   - Recommendation: JSON only (`metrics.json`). The nested structure of metric dataclasses (dicts of dicts, per-proposal breakdowns) doesn't flatten cleanly to CSV without loss of structure. JSON is human-readable and programmatically accessible.

3. **`PipelineResult.metrics` field structure**
   - What we know: It should contain all 10 metrics
   - What's unclear: Flat dict of metric names to values, or structured by category?
   - Recommendation: Flat dict keyed by metric name (e.g., `'flip_rate'`, `'gini'`), where each value is the `dataclasses.asdict()` output of the corresponding result dataclass. This mirrors the JSON file structure directly.

4. **Error handling for stage failures**
   - What we know: CONTEXT.md leaves this to Claude's discretion
   - What's unclear: Suppress and continue, or raise immediately?
   - Recommendation: Raise immediately with a clear message identifying the failing stage. Partial results are worse than no results for a backtesting pipeline. No custom exception class needed — re-raise with `raise RuntimeError(f'Stage 2 (simulation) failed: {e}') from e`.

## Sources

### Primary (HIGH confidence)

- CPython 3.12 stdlib — `tomllib` module (`import tomllib` verified in project venv; `'rb'` mode requirement confirmed by `help(tomllib.load)`)
- CPython 3.12 stdlib — `argparse`, `pathlib`, `json`, `dataclasses`, `datetime` — all standard, unchanged
- Project codebase — `apps/simulations/src/backtesting/` — direct inspection of all module APIs, function signatures, and data shapes
- Project codebase — `apps/simulations/tests/conftest.py` — authoritative fixture patterns showing the full data → simulation → metrics flow

### Secondary (MEDIUM confidence)

- Python docs — `__main__.py` pattern for `python -m package` invocation (standard Python packaging convention, stable across versions)

### Tertiary (LOW confidence)

- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are stdlib or already-installed project dependencies; verified in Python 3.12 venv
- Architecture: HIGH — patterns derived directly from existing codebase inspection; all four upstream module APIs are concrete and stable
- Pitfalls: HIGH — NaN/JSON issue and `windows_df` extraction derived from direct code reading; cadCAD warning suppression pattern verified in conftest.py

**Research date:** 2026-02-27
**Valid until:** 2026-03-28 (stable stdlib; upstream modules are frozen as of Phase 6 complete)
