# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Poetry to uv Migration

**Shipped:** 2026-02-27
**Phases:** 1 (of 2 planned) | **Plans:** 1 | **Sessions:** 1

### What Was Built

- PEP 621-compliant pyproject.toml with hatchling build backend
- uv.lock with 36 packages resolved (replacing poetry.lock)
- Clean dev/runtime dependency separation

### What Worked

- Quick depth setting kept scope tight — 1 plan, 2 tasks, 6 min execution
- Atomic commits per task made the migration traceable
- Auto-fixing deviations (uv/Python install, hatchling build config) kept momentum

### What Was Inefficient

- Phase 2 (Verify) was planned but never executed — could have been folded into Phase 1 as a final task
- For a simple migration, 2 phases was over-structured

### Patterns Established

- PEP 621 `[project]` table for metadata
- `[dependency-groups]` for dev deps separation
- uv.lock committed to version control for reproducible installs
- hatchling build targets config for non-standard src/ layouts

### Key Lessons

1. For simple migrations, verification should be part of the migration phase, not a separate phase
2. The `src/` layout with multiple subdirectories needs explicit hatchling `packages` config

### Cost Observations

- Model mix: 100% sonnet (balanced profile)
- Sessions: 1
- Notable: Very efficient for a migration task — 6 min total execution

---

## Milestone: v2.0 — Backtesting & Simulation

**Shipped:** 2026-02-27
**Phases:** 5 | **Plans:** 9 | **Sessions:** ~5

### What Was Built

- Governor-compatible event schema with Pydantic v2 validation
- Synthetic data factory with Pareto stakes, tri-modal timing, 3 distribution profiles
- cadCAD dual-tally simulation (legacy + Signals) with immutable state updates
- 10 governance metrics as pure functions on DataFrame
- 11 publication-grade matplotlib plots (OO API, no pyplot)
- Pipeline orchestrator: `run_pipeline()` + CLI with TOML config

### What Worked

- Layered phase structure (data → simulation → metrics → plots → pipeline) created clean dependency chain — each phase built on the previous with zero circular dependencies
- Pure function architecture for metrics and weighting made testing trivial — 147 tests, all deterministic
- Requirement tracing (DATA-01, SIM-01, METR-01, PLOT-01, PIPE-01) kept every phase focused on its contract
- matplotlib OO API decision eliminated pyplot state bugs that typically plague batch plot generation
- The balanced model profile (sonnet executors, sonnet verifiers) delivered good quality at reasonable cost

### What Was Inefficient

- Plan 03-02 SUMMARY.md had empty `requirements_completed` frontmatter — 7 requirements not tracked at SUMMARY level (caught by audit but shouldn't require audit to detect)
- `GovernorDataLoader` Protocol defined but not wired into pipeline — the "zero architecture change" promise (DATA-09) is at the loader layer, not the pipeline layer. Should have been caught during planning
- Pre-existing `test_simulation.py` broken import carried through entire milestone without being addressed

### Patterns Established

- Frozen dataclasses for metric return types — consistent API across all 10 metrics
- Module-level `matplotlib.use('Agg')` + `rcParams.update()` for headless publication-grade rendering
- `_nan_to_none()` sanitization before JSON serialization — prevents float NaN corruption
- TOML config with recursive deep-merge over defaults for zero-config + surgical overrides
- `if __name__ == '__main__'` guard in CLI module when using `python -m` invocation

### Key Lessons

1. When a Protocol/interface is defined for future extensibility, wire it into the E2E flow even if the current implementation is simpler without it — otherwise the integration seam goes untested
2. SUMMARY frontmatter `requirements_completed` should be populated by the executor, not left empty — the 3-source cross-reference depends on it
3. 5 phases executing in a single day is achievable with the balanced profile and parallel wave execution

### Cost Observations

- Model mix: ~90% sonnet (executors, verifiers, integration checker), ~10% opus (orchestration)
- Sessions: ~5 (one per phase execution + audit + complete)
- Notable: Full milestone (5 phases, 9 plans, 46 requirements) from zero code to shipped in a single day

---

## Milestone: v3.0 — Sweep Engine & Extended Analysis

**Shipped:** 2026-02-28
**Phases:** 7 (including 2 decimal phases) | **Plans:** 13 | **Sessions:** ~6

### What Was Built

- Public `budget.py` module with AllocationDistribution hierarchy (Beta/truncnorm/uniform)
- Monte Carlo allocation modeling with SeedSequence-spawned independent generators
- Dedicated cartesian sweep engine with ProcessPoolExecutor parallelism and memory management
- 6-function extended analysis module (margin flips, influence, timing sensitivity, archetypes, significance, bootstrap CI)
- Report bundle: annotated heatmaps, detail plots, composite figure, CSV/JSON export

### What Worked

- NaN-for-degenerate convention established in Phase 8 and enforced consistently through all subsequent phases — prevented silent metric corruption across the entire sweep
- Decimal phase numbering (10.1, 11.1) cleanly addressed mid-milestone integration gaps without disrupting the phase sequence
- Phase verification caught all cross-phase wiring issues before they accumulated — integration gaps in 10.1 and 11.1 were caught by audit and resolved promptly
- budget.py as a leaf module (no backtesting.* imports) prevented circular dependency chains across MC, sweep, and pipeline consumers
- The [None] sentinel pattern in `_enumerate_cells()` for optional cartesian axes (mc_dists, vote_timings) was clean and reusable

### What Was Inefficient

- `analysis.py` was built as a standalone module (Phase 11) but never wired into `report.py` (Phase 12) — 6 tested functions with zero production callers. The timing_sensitivity/ directory is created but always empty
- 11.1-01-SUMMARY.md had empty `requirements_completed` frontmatter (same pattern as v2.0's 03-02 SUMMARY) — lesson from v2.0 not applied
- mc_dists TOML loading was deferred in Phase 10.1 as a scoping decision, but this leaves a gap for TOML-only users
- Two mid-milestone audits were needed: one after Phase 10 (which spawned 10.1 and 11.1), and the final audit after Phase 12. The first audit added 30+ minutes but was valuable

### Patterns Established

- `_run_cell()` as a module-level function for ProcessPoolExecutor picklability — deferred imports inside the function body
- `np.nanmean` for all metric aggregation in sweep results (pair with NaN-for-degenerate returns)
- `_nan_to_none_extended()` handles np.integer, np.floating, and Python float NaN/Inf recursively before JSON serialization
- `origin='lower'` mandatory for all heatmaps — default 'upper' inverts the y-axis
- TOML `[[sweep.vote_timings]]` table array pattern for list-of-dataclass config

### Key Lessons

1. When an analysis module is built in one phase and consumed in the next, the consumer phase plan MUST explicitly import and call the analysis functions — don't assume the wiring will happen naturally
2. Mid-milestone audits are valuable — they catch integration gaps early enough to fix them with targeted decimal phases rather than discovering them at milestone completion
3. The `requirements_completed` frontmatter gap keeps recurring — this should be enforced by the executor, not left to the plan author
4. Memory management (`del + gc.collect()`) in the sweep runner was critical — without it, 192-cell sweeps would accumulate 500MB+ of cadCAD raw results

### Cost Observations

- Model mix: ~80% sonnet (executors, verifiers, integration checker), ~20% opus (orchestration, audit, completion)
- Sessions: ~6 (phase executions + 2 audits + completion)
- Notable: 7 phases (13 plans) executed in a single day. Decimal phases (10.1, 11.1) added ~20% overhead but prevented integration debt

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 1/2 | Initial project setup, quick depth |
| v2.0 | ~5 | 5/5 | Full pipeline, balanced profile, wave execution |
| v3.0 | ~6 | 7/7 | Decimal phases for integration gaps, mid-milestone audits |

### Cumulative Quality

| Milestone | Tests | LOC (src) | LOC (test) |
|-----------|-------|-----------|------------|
| v1.0 | — | — | — |
| v2.0 | 147 | 2,621 | 2,398 |
| v3.0 | 207+ | 5,718 | 4,147 |

### Top Lessons (Verified Across Milestones)

1. Verification should match the scope of work — don't plan separate verify phases for simple tasks (v1.0), but do verify every phase in multi-phase milestones (v2.0, v3.0)
2. Pure function architecture + frozen dataclasses = easy testing and composition (v2.0, v3.0)
3. `requirements_completed` frontmatter must be populated by executors — empty frontmatter recurred in v2.0 and v3.0, requiring audit to catch
4. Mid-milestone audits + decimal phases are the right pattern for fixing cross-phase integration gaps without disrupting the main sequence (v3.0)
