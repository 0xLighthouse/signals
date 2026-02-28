---
phase: quick
plan: 1
subsystem: documentation
tags: [thesis-guide, simulation-planning, infrastructure-mapping]
dependency_graph:
  requires: []
  provides: [THESIS_GUIDE.md, simulation-plans-C-G]
  affects: [apps/simulations]
tech_stack:
  added: []
  patterns: [infrastructure-inventory, gap-analysis]
key_files:
  created:
    - apps/simulations/THESIS_GUIDE.md
  modified: []
decisions:
  - "Document exp curve gap precisely: weighting supports it, factory rejects it with ValueError"
  - "Confirm Sim F is ready-to-run today with zero code changes"
  - "Separate Path A vs Path B for Sim E based on whether timing decay needs implementation"
  - "Document n_voters as NOT a sweep axis — lives in base dict, not cartesian grid"
metrics:
  duration_seconds: 205
  tasks_completed: 1
  files_created: 1
  completed_date: "2026-02-28"
---

# Quick Plan 1: Build Thesis Guide from Milestones — Summary

**One-liner:** Comprehensive 792-line simulation thesis guide mapping Sims C-G
to existing v3.0 infrastructure with precise READY/GAP/NEEDS status per component
and specific code change instructions for each gap.

## What Was Built

`apps/simulations/THESIS_GUIDE.md` — 792 lines organized as:

1. **Executive Summary** — v1.0-v3.0 built the full pipeline; Sim F runs today
2. **Infrastructure Inventory** — full API documentation of all 8 modules:
   - `factory.py`: generate_scenario() full signature, StakeProfile, LockProfile,
     VoteTimingConfig, ScenarioCurveType literals
   - `weighting/signals.py`: CurveType (includes exp), lock_curve() with floor param,
     formulas for all 4 curves
   - `budget.py`: AllocationStrategy, AllocationDistribution hierarchy
     (Beta/Truncnorm/Uniform), VoterLedger budget mechanics
   - `sweep.py`: SweepConfig axes, SweepCell, TOML format, ProcessPoolExecutor pattern
   - `analysis.py`: All 6 functions (ANAL-01 to ANAL-06) with input/output types
   - `metrics.py`: All 10 functions (METR-01 to METR-10) with what each measures
   - `report.py`: generate_sweep_report() output structure, all file types produced
   - `mc.py`: run_mc_samples() with SeedSequence.spawn() independence guarantee
3. **Proposed Simulations** — Sims C through G with research question, sweep design,
   infrastructure status table, required code changes, expected TOML, key metrics,
   and complexity rating
4. **Dependency Map** — Sim C is foundation; D/F/G depend on C's curve recommendation
5. **Priority Execution Order** — table with rationale and blocking work per sim
6. **Infrastructure Gaps Summary** — 8 gaps with XS/S/M/L effort estimates and
   specific file+line instructions
7. **Quick Wins** — Sim F runnable today with example TOML and Python snippet

## Key Findings

**Critical gaps documented precisely:**

- `exp` curve: exists in `weighting/signals.py` (`CurveType` Literal includes 'exp')
  but `factory.py` `ScenarioCurveType` is `Literal['sqrt', 'log', 'linear']` and
  raises `ValueError` for 'exp'. Fix: 2-line change in factory.py lines 23-24.

- `floor` param: exists in `lock_curve(floor=0.1)` but is NOT exposed through
  `generate_scenario()`. Hardcoded at 0.1 internally. Sweeping floor values
  requires threading the param through factory + runner.

- `n_voters` is NOT a SweepConfig axis. It lives in base dict passed to
  generate_scenario, not in the cartesian grid. To sweep n_voters, either run
  4 separate sweeps (no code) or add n_voters_list to SweepConfig.

**Sim F is the immediate win:** stake_profile='bimodal' + allocation_strategy=
'conviction_weighted' are both fully implemented and accepted by generate_scenario().
Run today with a TOML file.

## Deviations from Plan

None. Plan executed exactly as written. The document structure matches the plan's
specification precisely, including all required sections, gap callouts, TOML
examples, and priority ordering.

## Self-Check

- [x] `apps/simulations/THESIS_GUIDE.md` exists (792 lines, minimum was 200)
- [x] All 5 sims (C through G) have sections with research question, sweep design,
      infrastructure status (READY/GAP/NEEDS), key metrics, and complexity rating
- [x] Infrastructure inventory documents all 8 modules with public APIs
- [x] Dependency map shows inter-simulation dependencies
- [x] Gap summary table lists every code change with effort estimate
- [x] Priority ordering matches C->D->F->E->G with justification
- [x] Commit 582d6ce exists in git log

## Self-Check: PASSED
