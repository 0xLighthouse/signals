# Roadmap: Simulations Poetry to uv Migration

## Overview

A two-phase migration: rewrite the pyproject.toml from Poetry to uv/hatchling format (with clean dev/runtime dependency separation), then verify that all simulations and tests continue working identically.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Migrate** - Convert pyproject.toml to uv/hatchling format, generate uv.lock, remove Poetry artifacts (completed 2026-02-27)
- [ ] **Phase 2: Verify** - Confirm simulations and tests work identically after migration

## Phase Details

### Phase 1: Migrate
**Goal**: The simulations project is fully migrated to uv — pyproject.toml uses standard format with hatchling backend, dependencies are correctly categorized, and uv.lock replaces poetry.lock
**Depends on**: Nothing (first phase)
**Requirements**: MIG-01, MIG-02, MIG-03, MIG-04, CLN-01, CLN-02
**Success Criteria** (what must be TRUE):
  1. pyproject.toml uses `[project]` table with hatchling as build backend — no `[tool.poetry]` sections remain
  2. Runtime dependencies (pandas, matplotlib, seaborn, numpy, fastparquet, tabulate, cadcad) are listed under `[project.dependencies]`
  3. Dev dependencies (ruff, pytest, pytest-cov) are listed under `[dependency-groups]` or `[project.optional-dependencies]` dev group
  4. uv.lock exists and poetry.lock is deleted
  5. Python >=3.12 constraint is present in pyproject.toml
**Plans:** 1/1 plans complete

Plans:
- [ ] 01-01-PLAN.md — Rewrite pyproject.toml to uv/hatchling format and generate uv.lock

### Phase 2: Verify
**Goal**: All existing simulations and tests pass with the uv-managed environment, confirming behavioral parity
**Depends on**: Phase 1
**Requirements**: VER-01, VER-02, VER-03
**Success Criteria** (what must be TRUE):
  1. `uv run pytest` passes all existing tests
  2. Simulation modules can be imported and run without errors
  3. `uv run ruff check` works with the existing 100-char line length config
**Plans**: TBD

Plans:
- [ ] 02-01: Run verification suite and confirm parity

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Migrate | 1/1 | Complete   | 2026-02-27 |
| 2. Verify | 0/1 | Not started | - |
