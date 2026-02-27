# Phase 7: Pipeline - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Single orchestrating entry point that ties data → simulation → metrics → plots into one command. Runnable as CLI (`python -m backtesting.pipeline`) or importable as a Python module (`run_pipeline()`). All layers from Phases 3–6 are composed here.

</domain>

<decisions>
## Implementation Decisions

### Invocation & CLI design
- Entry point: `python -m backtesting.pipeline` (module-style, no console script)
- Flags: `--output` (directory, default `./output`), `--name` (experiment name, optional), `--config` (config file path, optional), `--init` (generate starter config), `-v` (verbose)
- When `--name` provided: output goes to `<output>/<name>/`
- When `--name` omitted: output goes to `<output>/<timestamp>/` (auto-generated)
- Silent by default; `-v` prints stage names (Generating data... Running simulation... Computing metrics... Plotting...)

### Output structure
- Flat directory per experiment — all files in one folder (no subdirectories)
- Plots saved as PNG
- Each run isolated in its own named or timestamped directory under the output path

### Configuration
- TOML format (`backtesting.toml`)
- Auto-discover config in current working directory; `--config` flag to point elsewhere
- `--init` flag writes a starter `backtesting.toml` with commented defaults
- Internal defaults used when no config file found (pipeline works out of the box)

### Programmatic API
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

</decisions>

<specifics>
## Specific Ideas

- Output should be named and isolated per experiment — user emphasized this
- Pipeline should work with zero config (sensible defaults) but support full customization via TOML

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-pipeline*
*Context gathered: 2026-02-27*
