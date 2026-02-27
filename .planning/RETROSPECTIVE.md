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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 1/2 | Initial project setup, quick depth |
| v2.0 | ~5 | 5/5 | Full pipeline, balanced profile, wave execution |

### Cumulative Quality

| Milestone | Tests | LOC (src) | LOC (test) |
|-----------|-------|-----------|------------|
| v1.0 | — | — | — |
| v2.0 | 147 | 2,621 | 2,398 |

### Top Lessons (Verified Across Milestones)

1. Verification should match the scope of work — don't plan separate verify phases for simple tasks (v1.0), but do verify every phase in multi-phase milestones (v2.0)
2. Pure function architecture + frozen dataclasses = easy testing and composition
