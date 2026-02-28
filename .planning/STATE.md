---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Sweep Engine & Extended Analysis
status: unknown
last_updated: "2026-02-28T16:16:22.086Z"
progress:
  total_phases: 7
  completed_phases: 6
  total_plans: 13
  completed_plans: 12
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-27)

**Core value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes.
**Current focus:** v3.0 Phase 12 — Report Bundle

## Current Position

Phase: 12 of 12 (Report Bundle)
Plan: 01 complete (plan 1 of N) — generate_sweep_report orchestrator with heatmaps and CSV/JSON exports
Status: In Progress
Last activity: 2026-02-28 — Completed 12-01: report.py core module with generate_sweep_report, heatmaps, exports (REPT-01/02/03/04/07/08)

Progress: [██████████] ~85%

## Performance Metrics

**Velocity:**
- Total plans completed: 3 (v3.0)
- Average duration: ~2 min
- Total execution time: ~7 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 08-foundation-fixes-budget-promotion | 3 | ~7 min | ~2 min |

*Updated after each plan completion*
| Phase 08-foundation-fixes-budget-promotion P02 | 2 | 2 tasks | 4 files |
| Phase 08-foundation-fixes-budget-promotion P03 | 4 | 3 tasks | 6 files |
| Phase 09-monte-carlo-allocation-modeling P01 | 2 | 2 tasks | 2 files |
| Phase 09-monte-carlo-allocation-modeling P02 | 1 | 2 tasks | 2 files |
| Phase 10-sweep-runner P01 | 2 | 2 tasks | 2 files |
| Phase 10-sweep-runner P02 | 3 | 2 tasks | 3 files |
| Phase 10.1-integration-wiring-fixes P01 | 5 | 2 tasks | 7 files |
| Phase 11-extended-analysis P01 | 2 | 2 tasks | 2 files |
| Phase 11-extended-analysis P02 | 4 | 2 tasks | 2 files |
| Phase 11.1-vote-timing-sweep-wiring P01 | 5 | 2 tasks | 3 files |
| Phase 12-report-bundle P01 | 2 | 2 tasks | 2 files |

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

Recent decisions affecting current work:
- [v3.0 research]: cadCAD-once / metrics-N-times optimization must be built into sweep runner from day one — cannot be retrofitted
- [v3.0 research]: `SeedSequence.spawn()` for MC generators — cannot be retrofitted after first implementation
- [08-01]: NaN-for-degenerate-inputs convention: _gini and _enp return float(np.nan) for zero-sum/zero-weight arrays — Phase 11 extended analysis must follow this convention
- [Phase 08-foundation-fixes-budget-promotion]: budget.py is a leaf module importing only numpy/stdlib/scipy.stats — enables Phase 9 to import without circular dependency
- [Phase 08-foundation-fixes-budget-promotion]: AllocationDistribution ABC with BetaDistribution/UniformDistribution/TruncnormDistribution uses dataclass+__post_init__ for validated construction
- [08-03]: curve_type validated at generate_scenario() boundary only — 'exp' excluded from ScenarioCurveType per Phase 8 restriction even though weighting/signals.py supports it
- [08-03]: curve_type passes through cadCAD M dict (not initial_state) — M dict is the correct parameter carrier in cadCAD for per-run parameters
- [Phase 09-monte-carlo-allocation-modeling]: alloc_frac drawn once per scenario via SeedSequence.spawn(2) two-RNG split — mc_dist=None path bit-identical to v2.0
- [Phase 09-monte-carlo-allocation-modeling]: VoteTimingConfig placed in factory.py not budget.py — keeps budget.py a leaf module
- [Phase 09-monte-carlo-allocation-modeling]: Pass int seed (child.generate_state(1)[0]) to generate_scenario — generate_scenario wraps seed in SeedSequence internally, expects int not SeedSequence child
- [Phase 09-monte-carlo-allocation-modeling]: alloc_frac captured externally by mirroring generate_scenario's SeedSequence.spawn(2) split — avoids changing factory return type
- [Phase 10-sweep-runner]: lock_profile.long maps to l_max_days in generate_scenario; short captured for analysis only (no l_min_days param)
- [Phase 10-sweep-runner]: max_workers required in TOML sweep config — no auto-detection, KeyError if missing
- [10-02]: _run_cell() must be module-level (not nested) for ProcessPoolExecutor picklability — pickle cannot serialize closures
- [10-02]: Deferred imports inside _run_cell() body to avoid circular imports across worker process boundaries
- [10-02]: _make_failed_row extended with enp/nakamoto columns to match successful row schema for consistent DataFrame construction
- [Phase 10.1-integration-wiring-fixes]: _nakamoto() returns float(np.nan) for degenerate inputs — NaN-for-degenerate convention applied consistently with _gini/_enp
- [Phase 10.1-integration-wiring-fixes]: mc_dists TOML loader left as-is (sets None by default) — programmatic API only for mc_dist in Phase 10.1
- [Phase 10.1-integration-wiring-fixes]: VoteTimingConfig re-exported from backtesting.data.__init__ — consistent with existing factory export pattern
- [Phase 11-extended-analysis]: analysis.py is independent of metrics.py — _get_final_tallies replicated inline to keep module boundaries clean
- [Phase 11-extended-analysis]: pd.qcut with duplicates='drop' handles Pareto-distributed stake edge cases without full fallback
- [Phase 11-extended-analysis P02]: delta = signals_share - counterfactual_share (not legacy_share) — median-lock counterfactual isolates commitment signal
- [Phase 11-extended-analysis P02]: timing_sensitivity uses observed=True in pivot_table to suppress pandas 2.x FutureWarning for categorical axes
- [Phase 11.1-vote-timing-sweep-wiring]: VoteTimingConfig imported at module level in sweep.py — factory.py is a leaf module with no circular dependency risk
- [Phase 11.1-vote-timing-sweep-wiring]: vote_timings uses [None] sentinel in itertools.product (same pattern as mc_dists) — prevents TypeError from passing None to itertools.product
- [Phase 12-report-bundle P01]: _nan_to_none_extended casts np.integer to int() — np.int64 is NOT a Python int subclass and causes json.dumps() TypeError without this cast
- [Phase 12-report-bundle P01]: origin='lower' is mandatory for heatmaps — default 'upper' inverts the row axis visually

### Pending Todos

None.

### Blockers/Concerns

- [Phase 11 flag]: Counterfactual baseline for address influence ("median lock duration") lacks empirical grounding — may need literature validation
- [Phase 10 flag]: Sweep CLI interface design (new entry point vs. integrated into pipeline CLI) — resolve during Phase 10 planning
- [Phase 9 flag]: N=50 MC samples per config feasibility unknown without profiling — validate during Phase 9 execution

## Session Continuity

Last session: 2026-02-28
Stopped at: Completed 12-01-PLAN.md — report.py core module (REPT-01/02/03/04/07/08)
Resume action: Phase 12 Plan 01 complete — report.py with generate_sweep_report, heatmaps, CSV/JSON exports. Proceed to Plan 02 (composite figures, detail plots).
