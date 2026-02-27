# Requirements: Simulations Poetry to uv Migration

**Defined:** 2026-02-27
**Core Value:** The simulations project uses uv for dependency management with a clean, modern pyproject.toml — no Poetry artifacts remain.

## v1 Requirements

Requirements for the migration. Each maps to roadmap phases.

### Migration

- [ ] **MIG-01**: pyproject.toml uses `[project]` table instead of `[tool.poetry]`
- [ ] **MIG-02**: Build backend is hatchling instead of poetry-core
- [ ] **MIG-03**: uv.lock replaces poetry.lock
- [ ] **MIG-04**: poetry.lock is deleted

### Cleanup

- [ ] **CLN-01**: ruff, pytest, pytest-cov are dev dependencies (not runtime)
- [ ] **CLN-02**: Runtime dependencies (pandas, matplotlib, seaborn, numpy, fastparquet, tabulate, cadcad) are correctly categorized

### Verification

- [ ] **VER-01**: All existing tests pass after migration
- [ ] **VER-02**: Simulations can be imported and run
- [ ] **VER-03**: Ruff linting still works with existing config

## v2 Requirements

None — this is a one-time migration.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dependency version upgrades | Migration-only scope, minimize risk |
| CI/CD pipeline updates | Handle separately if needed |
| Monorepo/pnpm workspace changes | Only Python sub-project affected |
| Simulation code or test modifications | Preserve behavioral parity |
| Adding new dependencies | Migration-only scope |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MIG-01 | — | Pending |
| MIG-02 | — | Pending |
| MIG-03 | — | Pending |
| MIG-04 | — | Pending |
| CLN-01 | — | Pending |
| CLN-02 | — | Pending |
| VER-01 | — | Pending |
| VER-02 | — | Pending |
| VER-03 | — | Pending |

**Coverage:**
- v1 requirements: 9 total
- Mapped to phases: 0
- Unmapped: 9 ⚠️

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after initial definition*
