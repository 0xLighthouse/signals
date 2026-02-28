# Phase 10: Sweep Runner - Context

**Gathered:** 2026-02-28
**Status:** Ready for planning

<domain>
## Phase Boundary

A dedicated sweep engine that enumerates a cartesian parameter grid, runs cadCAD once per simulation config, computes metrics across the full curve_type/alpha axis without re-simulation, and collects results in a single `SweepResult` with bounded memory use. Extended analysis (Phase 11) and report generation (Phase 12) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Grid Configuration
- Flat lists per axis in TOML: `curve_types = ["linear", "quadratic"]`, `alphas = [0.1, 0.5, 0.9]`, etc.
- Lock profiles specified as inline dicts: `lock_profiles = [{short=30, long=365}, {short=90, long=730}]`
- Single TOML file with `[base]` section for fixed simulation params (num_proposals, num_voters, etc.) and `[sweep]` section for grid axes
- No named profile presets — one flat config per sweep run

### Parallelism & Failure
- Always use ProcessPoolExecutor, even with 1 worker (no serial mode)
- `max_workers` must be explicitly specified in TOML — no auto-detection
- Default behavior: skip-and-continue on cell failure (log error, mark cell failed, continue remaining cells)
- `--fail-fast` flag to stop entire sweep on first error
- Configurable `cell_timeout_seconds` in TOML — cells exceeding it are killed and marked failed

### Result Shape & Output
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

</decisions>

<specifics>
## Specific Ideas

- cadCAD M-param zips element-wise, not factorial — sweep must build explicit cartesian product externally (PITFALLS.md P3)
- Memory concern: ~500MB+ accumulation without cleanup (PITFALLS.md P1) — must release raw cadCAD results after per-cell metric computation
- Expected grid size ~192 cells — stdlib ProcessPoolExecutor sufficient, no need for distributed frameworks

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-sweep-runner*
*Context gathered: 2026-02-28*
