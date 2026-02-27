# Stack Research

**Domain:** Python backtesting & cadCAD simulation pipeline (governance metrics)
**Researched:** 2026-02-27
**Confidence:** HIGH (scipy/plotly verified via PyPI/official sources; cadCAD patterns verified via official docs)

## Context: What Already Exists (Do Not Re-add)

The following are validated and locked in `apps/simulations/pyproject.toml`:

```
pandas>=2.2.3,<3       # DataFrame results from cadCAD
matplotlib>=3.9.2,<4   # Primary plotting
seaborn>=0.13.2,<0.14  # Statistical plots
numpy>=1.26.4,<2       # Numerical arrays
fastparquet>=2024.11.0  # Parquet I/O
tabulate>=0.9.0,<0.10  # Table formatting
cadCAD>=0.5.3,<0.6     # Simulation engine
```

Dev deps: `ruff`, `pytest`, `pytest-cov`

**Critical discovery:** `scipy` is already imported in `src/statistical_analysis/metrics.py`
(`from scipy import stats`, `from scipy.stats import entropy`) but is NOT listed in
`pyproject.toml` dependencies. This is a latent bug — it works only because cadCAD's
transitive dependency graph happens to pull scipy in. It must be pinned explicitly.

---

## Recommended Stack Additions

### Core Additions (Required for v2.0 Features)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| scipy | `>=1.13.0,<2` | Gini via integration, Mann-Whitney U, KS test, confidence intervals | Already used in codebase but unpinned — latent bug. scipy 1.13+ supports Python 3.12 natively. Current stable is 1.15.3. The `stats` submodule provides all needed statistical tests without custom implementations. |
| plotly | `>=6.0.0,<7` | Interactive HTML plots for exploratory analysis and parameter sweep heatmaps | Matplotlib produces publication PDFs; plotly produces interactive HTML for exploring sweep results. Two complementary outputs. plotly 6.x (current: 6.5.2) requires Python >=3.8, works cleanly with pandas DataFrames. |
| pydantic | `>=2.0.0,<3` | Governor event schema validation — PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED | The synthetic/real data swap depends entirely on the Governor schema being correct. Pydantic v2 validates at construction time with Rust-backed performance, catches schema drift before it corrupts simulation runs. Use `model_validator` for cross-field constraints (e.g. vote timestamp must fall between proposal creation and finalization). |

### Supporting Additions (Strongly Recommended)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| kaleido | `>=0.2.1` | Static PNG/SVG/PDF export from plotly figures | Required when plotly figures need to be saved to disk for publication. kaleido v1+ requires Chrome; pin `>=0.2.1,<1.0` to avoid the Chrome dependency in CI/headless environments. If Chrome is available, upgrade to `>=1.0` for PDF/SVG quality improvements. |
| tqdm | `>=4.66.0,<5` | Progress bars for parameter sweeps | Long-running sweeps (e.g. 8×8 lock-curve × decay grid) give no feedback without progress tracking. tqdm is zero-config, works in Jupyter and terminal. cadCAD's `run` call wraps cleanly with tqdm at the sweep-config level. |

### Development Tool Additions

| Tool | Purpose | Notes |
|------|---------|-------|
| pytest-xdist | Parallel test execution for sweep validation | Add to dev deps as `pytest-xdist>=3.0.0,<4` only if sweep parameter tests become slow (>30s). Not needed initially. |
| jupyterlab | Notebook-based exploration and figure review | Add to dev deps if interactive visualization review is needed. Out of scope for v2.0 automated pipeline — flag for later. |

---

## Installation (uv, PEP 621 format)

Add to `[project] dependencies` in `apps/simulations/pyproject.toml`:

```toml
[project]
dependencies = [
    # Existing (unchanged)
    "pandas>=2.2.3,<3",
    "matplotlib>=3.9.2,<4",
    "seaborn>=0.13.2,<0.14",
    "numpy>=1.26.4,<2",
    "fastparquet>=2024.11.0,<2025",
    "tabulate>=0.9.0,<0.10",
    "cadCAD>=0.5.3,<0.6",
    # NEW v2.0 additions
    "scipy>=1.13.0,<2",
    "plotly>=6.0.0,<7",
    "pydantic>=2.0.0,<3",
    "kaleido>=0.2.1,<1.0",
    "tqdm>=4.66.0,<5",
]
```

Run `uv sync` to regenerate `uv.lock`.

---

## cadCAD Parameter Sweep Configuration (Existing Pattern + v2.0 Extension)

The existing `src/cadcad/parameters.py` already uses the correct cadCAD sweep pattern.
The v2.0 extension for the event-replay pipeline follows the same pattern:

```python
# Existing pattern — already correct, extend it
system_params = {
    # Lock curve shape parameters (v2.0 additions)
    "lock_curve_exponent": [0.5, 1.0],   # f(L) = L^exponent
    "decay_halflife_days": [30, 90, 180],  # INVALID — cadCAD allows max 2 distinct lengths
    # Correct sweep: keep to 2 lengths max per cadCAD constraint
    "decay_halflife_days": [30, 90],
    # Existing params
    "acceptance_threshold": [50000, 100000],
}
```

**cadCAD sweep constraint:** Parameters in `M` may have at most 2 distinct list lengths.
All params with a single value `[x]` count as length-1; params with `[a, b]` count as
length-2. You cannot have `[a, b, c]` in any parameter. For 3+ values in a sweep,
run cadCAD multiple times with different configs or loop over configs manually.

**Event-replay pattern** (new in v2.0) — feed Governor events into cadCAD state:

```python
# Policy function reads from pre-built event queue in state
def p_process_events(params, step, history, state):
    events = state['event_queue']
    current_tick = state['timestep']
    relevant = [e for e in events if e.block == current_tick]
    return {'processed_events': relevant}
```

---

## Metrics Implementation Notes

### Gini Coefficient
The codebase already has a hand-rolled `_calculate_gini_coefficient` in `GovernanceMetrics`.
Keep it — it's correct and avoids a scipy import in the metrics module. Use
`scipy.stats.gini` (added in scipy 1.12) only if the existing implementation shows
numerical precision issues at extreme distributions.

### ENP (Effective Number of Parties)
Formula: `ENP = 1 / sum(p_i^2)` where `p_i` is voter i's share of total vote weight.
This is the inverse Herfindahl-Hirschman Index. Pure numpy — no scipy needed:

```python
def compute_enp(vote_weights: np.ndarray) -> float:
    """Effective Number of Participants (Laakso-Taagepera, 1979)."""
    shares = vote_weights / vote_weights.sum()
    return 1.0 / np.sum(shares ** 2)
```

### Vote Flip Detection
Track proposal outcome changes across Legacy vs Signals tallies. Pure pandas — no
additional library. A flip is `legacy_outcome != signals_outcome` per proposal.

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| plotly `>=6.0,<7` | altair | Altair uses Vega-Lite grammar (declarative JSON), harder to programmatically generate sweep heatmaps. plotly has native support for parameter sweep visualization via `px.imshow` on pivot tables. |
| plotly `>=6.0,<7` | bokeh | Bokeh is excellent but adds more complexity. plotly is sufficient and has better pandas integration via plotly.express. |
| pydantic v2 | attrs | attrs is lighter but lacks the validation error messages and JSON schema export that pydantic provides. The Governor schema benefit comes from pydantic's `model_validate()` which catches malformed events during synthetic generation. |
| pydantic v2 | marshmallow | marshmallow is older, slower, more verbose. pydantic v2 (Rust core) is 5-50x faster for validation, matters during synthetic data generation of thousands of events. |
| kaleido `<1.0` | kaleido `>=1.0` | kaleido v1.0+ requires Chrome to be installed. In a headless CI environment or fresh dev machine, this is a setup burden. Pin `<1.0` until Chrome availability is confirmed or CI adds Chrome install step. |
| tqdm | rich progress | rich is heavier. tqdm is the scientific Python ecosystem standard and has direct `tqdm(range(...))` integration with cadCAD simulation loops. |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| scikit-learn | Not needed — no ML in this pipeline. Adding it pulls in a large dependency tree (joblib, threadpoolctl, etc.) for nothing. | scipy.stats for statistical tests covers all needed analysis. |
| dask / ray | Overkill for parameter sweeps of this scale. cadCAD's built-in `pathos` parallelism (already a transitive dep) handles Monte Carlo runs. | cadCAD's N parameter for Monte Carlo, manual loop for sweep configs if needed. |
| polars | pandas is already the project standard and cadCAD returns pandas DataFrames natively. Mixing DataFrame libraries creates conversion overhead. | pandas (already installed) |
| hvplot | Adds HoloViews dependency chain. plotly achieves the same interactive plots more directly. | plotly.express |
| altair + vega | Altair's declarative approach doesn't map cleanly to the cadCAD results DataFrame structure without substantial reshaping. | plotly.express which handles long-form DataFrames natively. |
| jupyter (runtime dep) | Jupyter is a development tool, not a pipeline dependency. It must never be in `[project] dependencies` — only in `[dependency-groups] dev`. | Move to dev deps if needed at all. |

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| scipy>=1.13.0 | numpy>=1.26.4, Python 3.12 | scipy 1.13+ fully supports Python 3.12. scipy 1.15.3 is current stable (Feb 2025). |
| plotly>=6.0.0 | pandas>=2.0, Python>=3.8 | plotly 6.x introduced breaking changes from 5.x in figure defaults. Pin `<7` for stability. Current stable: 6.5.2. |
| pydantic>=2.0.0 | Python>=3.8 | pydantic v2 is a breaking change from v1. If any existing code uses pydantic v1 patterns, migration required. Current stable: 2.12.x. |
| kaleido>=0.2.1,<1.0 | plotly>=5.0 | kaleido 1.0+ requires Chrome — avoid in CI. kaleido 0.2.x works with plotly 5.x and 6.x. |
| cadCAD>=0.5.3 | pathos, multiprocess (transitive) | cadCAD 0.5.x bundles pathos for parallelism. Do not add pathos explicitly. |

---

## Stack Patterns by Variant

**If running parameter sweeps interactively (Jupyter/local dev):**
- Use plotly for interactive heatmaps of sweep results
- Use tqdm for sweep progress
- kaleido `<1.0` for saving figures to disk

**If running in CI/headless pipeline:**
- Use matplotlib only for static outputs (no browser/Chrome required)
- kaleido is optional — skip figure saving or use matplotlib backends
- tqdm still works (outputs to stdout)

**If real Governor data replaces synthetic:**
- pydantic models validate incoming data at ingestion time — zero code change to simulation
- Event schema is defined once in pydantic models, used by both synthetic generator and real data loader

---

## Sources

- cadCAD Parameter Sweep docs: https://github.com/cadCAD-org/cadCAD/blob/master/documentation/System_Model_Parameter_Sweep.md — HIGH confidence
- scipy PyPI: https://pypi.org/project/SciPy/ — version 1.15.3 current stable — HIGH confidence
- plotly PyPI: https://pypi.org/project/plotly/ — version 6.5.2 current stable — HIGH confidence
- plotly static image export: https://plotly.com/python/static-image-export/ — kaleido `<1.0` recommendation — HIGH confidence
- pydantic v2 PyPI: https://pypi.org/project/pydantic/ — version 2.12.x stable — HIGH confidence
- Laakso-Taagepera ENP formula: https://en.wikipedia.org/wiki/Effective_number_of_parties — formula verified — HIGH confidence
- Existing codebase (`src/statistical_analysis/metrics.py`): scipy already imported but unpinned — confirmed from source read

---
*Stack research for: Signals backtesting & cadCAD simulation pipeline (v2.0)*
*Researched: 2026-02-27*
