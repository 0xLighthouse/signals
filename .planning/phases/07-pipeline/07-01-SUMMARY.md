---
phase: 07-pipeline
plan: 01
subsystem: simulation
tags: [python, pipeline, backtesting, cadcad, matplotlib, cli, toml]

requires:
  - phase: 06-plots
    provides: "11 matplotlib plot functions returning Figure objects (OO API)"
  - phase: 05-metrics
    provides: "10 compute_* metric functions returning frozen dataclasses"
  - phase: 04-cadcad-integration
    provides: "run_backtest(), build_results_dataframe() cadCAD runner"
  - phase: 03-foundation
    provides: "generate_scenario(), events_to_dataframe(), GovernorEvent schema"

provides:
  - "run_pipeline(config, verbose) -> PipelineResult orchestrating full workflow"
  - "PipelineResult frozen dataclass with .metrics, .plot_paths, .output_dir"
  - "CLI entry: python -m backtesting.pipeline with --output/--name/--config/--init/-v"
  - "Config loading: TOML file, dict, or None (auto-discover backtesting.toml)"
  - "metrics.json written to output dir (NaN-sanitized valid JSON)"
  - "11+ PNG plot files per run (9 aggregate + per-proposal cumulative_vote/story)"
  - "test_pipeline.py: 10 requirement-traced tests (PIPE-01, PIPE-02, PIPE-03)"

affects:
  - "any future analysis scripts or notebooks that use pipeline as entry point"
  - "CI/CD pipeline integration"

tech-stack:
  added: [tomllib (stdlib Python 3.11+), argparse, pathlib, json, dataclasses.asdict]
  patterns:
    - "4-stage pipeline: data -> simulation -> metrics -> plots with per-stage error wrapping"
    - "Deep-merge config: recursive _deep_merge() over _DEFAULTS, never dict.update()"
    - "_nan_to_none() recursive NaN/Inf sanitizer before json.dump()"
    - "if __name__ == '__main__' guard in pipeline.py for python -m backtesting.pipeline"
    - "Module-scoped pytest fixture runs expensive pipeline once; all tests reuse result"

key-files:
  created:
    - apps/simulations/src/backtesting/pipeline.py
    - apps/simulations/src/backtesting/__main__.py
    - apps/simulations/tests/test_pipeline.py
  modified: []

key-decisions:
  - "if __name__ == '__main__' guard added to pipeline.py — python -m backtesting.pipeline runs pipeline.py as __main__, not __main__.py; guard is required"
  - "Per-proposal plots iterate over all unique proposal_ids from results_df vote rows"
  - "_nan_to_none() converts both float('nan') and float('inf') to None for JSON safety"
  - "Module-scoped fixture for pipeline_result — avoids running full pipeline once per test"
  - "_GENERATE_SCENARIO_KEYS frozenset guards config key injection to generate_scenario()"

requirements-completed: [PIPE-01, PIPE-02, PIPE-03]

duration: 9min
completed: 2026-02-27
---

# Phase 7 Plan 01: Pipeline Summary

**Single-command backtesting orchestrator composing all prior layers (Phases 3-6) into run_pipeline() and python -m backtesting.pipeline CLI, with 10 requirement-traced passing tests**

## Performance

- **Duration:** 9 min
- **Started:** 2026-02-27T22:17:29Z
- **Completed:** 2026-02-27T22:26:45Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `pipeline.py` orchestrates data -> simulation -> metrics -> plots in 4 error-wrapped stages
- CLI (`python -m backtesting.pipeline`) and programmatic API (`run_pipeline()`) both functional
- 19 plot files + metrics.json produced per run (9 aggregate + N per-proposal plots)
- 10 requirement-traced tests (PIPE-01/02/03) all passing; full suite 147/147 passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement pipeline.py with run_pipeline(), PipelineResult, config, and CLI** - `8a9591d` (feat)
2. **Task 2: Write requirement-traced pipeline tests** - `f933024` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/pipeline.py` - Core orchestrator: PipelineResult, run_pipeline(), main(), _resolve_config(), _make_output_dir(), _nan_to_none(), _write_init_config()
- `apps/simulations/src/backtesting/__main__.py` - Module entry point delegating to pipeline.main()
- `apps/simulations/tests/test_pipeline.py` - 10 requirement-traced tests (PIPE-01, PIPE-02, PIPE-03)

## Decisions Made

- **`if __name__ == '__main__'` guard in pipeline.py:** Python's `-m backtesting.pipeline` runs `pipeline.py` as `__main__`, not `__main__.py`. Without the guard, the module loaded and exited silently (no error, no output). Adding the guard fixed CLI execution. `__main__.py` delegates to `main()` for the `python -m backtesting` entry point.
- **Per-proposal plots iterate over results_df:** Rather than using config's n_proposals, proposal IDs are extracted from actual VOTE_CAST rows in results_df — handles edge cases where proposals have no votes.
- **Module-scoped fixture:** Running the full pipeline (200 voters, 30 proposals) takes ~15s. Module scope runs it once and shares across all 10 tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added `if __name__ == '__main__'` guard to pipeline.py**

- **Found during:** Task 2 (test_pipe01_cli_entry_point failure)
- **Issue:** `python -m backtesting.pipeline` runs `pipeline.py` as `__main__`, not `__main__.py`. Without the guard, the module just imported and exited — returncode 0, no output, no error.
- **Fix:** Added `if __name__ == '__main__': main()` at the bottom of pipeline.py
- **Files modified:** apps/simulations/src/backtesting/pipeline.py
- **Verification:** CLI test passes; subprocess call exits 0 with full output written
- **Committed in:** f933024 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — missing `__main__` guard)
**Impact on plan:** Essential correctness fix. The `__main__.py` approach works for `python -m backtesting`, but `python -m backtesting.pipeline` requires the guard in pipeline.py itself.

## Issues Encountered

- Discovered project uses Python 3.12 venv at `.venv/bin/python`, not system `python3` (3.10). Used venv Python throughout verification.
- A third-party `backtesting` library (financial) exists in the ecosystem; the venv `.pth` file correctly puts our `src/` first in sys.path so our package takes precedence.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 7 (Pipeline) is complete — all requirements met (PIPE-01, PIPE-02, PIPE-03)
- Full backtesting workflow runnable with a single command: `python -m backtesting.pipeline -v`
- Pipeline is importable for notebooks/scripts: `from backtesting.pipeline import run_pipeline`
- No blockers for downstream work

---
*Phase: 07-pipeline*
*Completed: 2026-02-27*

## Self-Check: PASSED

- apps/simulations/src/backtesting/pipeline.py: FOUND
- apps/simulations/src/backtesting/__main__.py: FOUND
- apps/simulations/tests/test_pipeline.py: FOUND
- .planning/phases/07-pipeline/07-01-SUMMARY.md: FOUND
- Commit 8a9591d: FOUND
- Commit f933024: FOUND
