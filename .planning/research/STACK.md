# Stack Research — v3.0 Sweep Engine & Extended Analysis

**Domain:** Parameter sweep engine, Monte Carlo allocation, extended governance analysis
**Researched:** 2026-02-27
**Confidence:** HIGH (all versions confirmed from uv.lock direct read)

---

## Existing Stack (Locked — Do Not Change)

From `apps/simulations/pyproject.toml` and resolved `uv.lock`:

| Package | Resolved Version | Status |
|---------|-----------------|--------|
| cadCAD | 0.5.3 | locked |
| pandas | 2.3.3 | locked |
| numpy | 1.26.4 | locked |
| matplotlib | 3.10.8 | locked |
| seaborn | 0.13.2 | locked |
| scipy | 1.17.1 | locked |
| pydantic | 2.12.5 | locked |
| fastparquet | 2024.11.0 | locked |
| tabulate | 0.9.0 | locked |
| tqdm | 4.67.3 | transitive via cadCAD |

---

## v3.0 Verdict: Zero New Runtime Dependencies

All four v3.0 feature areas are achievable with existing installed packages + Python stdlib.

### Feature-to-Stack Mapping

**1. Parameter Sweep Runner (Grid Search)**
- `itertools.product` (stdlib) — cartesian product of parameter axes
- `concurrent.futures.ProcessPoolExecutor` (stdlib) — process-based parallelism
- `tqdm` 4.67.3 (transitive) — terminal progress bar
- `pandas.DataFrame` (existing) — collect per-cell metric dicts

**2. Monte Carlo Allocation & Vote Timing**
- `numpy.random.Generator` (existing) — `rng.beta(a, b)` for allocation fractions, `rng.lognormal()` for timing
- `scipy.stats` (existing, 1.17.1) — named distribution sampling, configurable from TOML
- `scipy.stats.qmc` (existing, added scipy 1.7) — quasi-Monte Carlo for variance reduction

**3. Heatmap Visualizations & Report Bundles**
- `seaborn.heatmap()` (existing, 0.13.2) — OO API compatible (`ax=` param)
- `matplotlib.figure.Figure` (existing) — same OO API pattern as v2.0
- `pandas.DataFrame.pivot_table()` (existing) — reshape for heatmap
- `pandas.DataFrame.to_csv()` (existing) — CSV export
- `json.dump()` (stdlib) — JSON export with existing `_nan_to_none()` sanitizer

**4. Extended Statistical Analysis**
- `scipy.stats.mannwhitneyu` (existing) — non-parametric influence distribution test
- `scipy.stats.ks_2samp` (existing) — two-sample margin distribution comparison
- `scipy.stats.bootstrap` (existing, added scipy 1.7) — confidence intervals
- `pandas.cut()` (existing) — margin-class binning

---

## Only pyproject.toml Change

Pin `tqdm` as a direct dependency (currently transitive-only via cadCAD):

```toml
"tqdm>=4.66.0,<5",  # was transitive-only via cadCAD; pin as direct dep
```

Run `uv sync` after — resolved version (4.67.3) will not change.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| plotly | Not needed for static publication figures | seaborn.heatmap() + matplotlib |
| joblib | stdlib ProcessPoolExecutor is sufficient | `concurrent.futures` |
| scikit-learn | No ML needed; scipy.stats covers all tests | scipy.stats |
| dask / ray | ~192 sweep cells run in minutes with ProcessPoolExecutor | stdlib |
| numba / cython | Bottleneck is I/O not computation | numpy vectorized ops |
| polars | cadCAD returns pandas natively | pandas (existing) |

---

## Distribution Recommendations for Allocation Fractions

| Parameter | Distribution | Params | Rationale |
|-----------|-------------|--------|-----------|
| Allocation fraction (conservative) | `Beta(2, 5)` | mean≈0.29 | Skews toward 15-45% range, bounded [0,1] |
| Allocation fraction (aggressive) | `Beta(5, 2)` | mean≈0.71 | Skews toward 60-100% range |
| Vote timing offset | `LogNormal` | mu=-1.5, sigma=0.8 | Right-skewed: most votes early-to-mid, long tail |
| Lock duration (conviction) | `Truncnorm` | mu=0.5*L_max, sigma=0.2*L_max | Centered at mid-duration, bounded |

---

*Stack research for: Signals v3.0 — Sweep Engine & Extended Analysis*
*Researched: 2026-02-27*
