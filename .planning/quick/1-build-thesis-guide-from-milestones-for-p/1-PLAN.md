---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/simulations/THESIS_GUIDE.md
autonomous: true
requirements: [QUICK-01]

must_haves:
  truths:
    - "Guide maps each proposed simulation (C through G) to specific infrastructure that exists"
    - "Guide identifies what new code/config is needed for each sim vs what is reusable"
    - "Priority ordering (C->D->F->E->G) is justified with dependency rationale"
  artifacts:
    - path: "apps/simulations/THESIS_GUIDE.md"
      provides: "Comprehensive simulation thesis guide"
      min_lines: 200
  key_links: []
---

<objective>
Create a comprehensive thesis guide document that synthesizes v1.0-v3.0 milestone work into actionable simulation plans for Sims C through G.

Purpose: Map the existing infrastructure (sweep engine, analysis module, metrics, report bundle, factory parameters) to each proposed simulation, identifying what is ready to use, what needs parameterization, and what needs new code.

Output: `apps/simulations/THESIS_GUIDE.md` -- a single reference document for planning and executing the next wave of simulations.
</objective>

<execution_context>
@/home/biscii/.claude/get-shit-done/workflows/execute-plan.md
@/home/biscii/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/milestones/v2.0-ROADMAP.md
@.planning/milestones/v3.0-ROADMAP.md
@.planning/milestones/v3.0-REQUIREMENTS.md

Key source files to reference for infrastructure inventory:
@apps/simulations/src/backtesting/sweep.py
@apps/simulations/src/backtesting/data/factory.py
@apps/simulations/src/backtesting/data/budget.py
@apps/simulations/src/backtesting/weighting/signals.py
@apps/simulations/src/backtesting/analysis.py
@apps/simulations/src/backtesting/metrics.py
@apps/simulations/src/backtesting/report.py
@apps/simulations/src/backtesting/mc.py
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build infrastructure inventory from codebase</name>
  <files>apps/simulations/THESIS_GUIDE.md</files>
  <action>
Read the following source files to build a complete inventory of existing capabilities:

1. `apps/simulations/src/backtesting/data/factory.py` -- extract `generate_scenario()` full parameter signature, `StakeProfile` literals (pareto/uniform/bimodal), `LockProfile` literals (correlated/inverse_correlated/independent/bimodal), `VoteTimingConfig` dataclass, `ScenarioCurveType` (sqrt/log/linear)
2. `apps/simulations/src/backtesting/weighting/signals.py` -- extract `CurveType` literal (sqrt/linear/log/exp), `lock_curve()` parameters including `floor` param, note that `exp` curve exists in weighting but NOT in factory's ScenarioCurveType
3. `apps/simulations/src/backtesting/data/budget.py` -- extract `AllocationStrategy` literal (uniform_fraction/conviction_weighted/aggressive), `AllocationDistribution` hierarchy, `VoterLedger`, `compute_allocation_fraction`
4. `apps/simulations/src/backtesting/sweep.py` -- extract `SweepConfig` axes (curve_types, alphas, lock_profiles, allocation_strategies, mc_dists, vote_timings), `SweepCell` fields, `run_sweep()` capabilities, `load_sweep_config()` TOML format
5. `apps/simulations/src/backtesting/analysis.py` -- extract all 6 public functions: margin_class_breakdown, voter_archetypes, address_influence, timing_sensitivity, influence_significance, bootstrap_ci
6. `apps/simulations/src/backtesting/metrics.py` -- extract all metric functions: compute_flip_rate, compute_gini, compute_participation_rate, compute_margin_shift, compute_enp, compute_nakamoto_coefficient, compute_late_vote_share, compute_lockin_timing, compute_top_k_concentration, compute_outcome_transition_matrix
7. `apps/simulations/src/backtesting/report.py` -- extract generate_sweep_report capabilities (heatmaps, detail plots, composite figures, CSV/JSON export)
8. `apps/simulations/src/backtesting/mc.py` -- extract MC runner capabilities

Then write `apps/simulations/THESIS_GUIDE.md` with the following structure:

```
# Signals Simulation Thesis Guide

## Executive Summary
Brief: v1.0-v3.0 built the complete simulation pipeline. This guide maps proposed Sims C-G to existing infrastructure and identifies gaps.

## Infrastructure Inventory

### Data Generation Layer
- generate_scenario() parameters (full list with types and defaults)
- StakeProfile options and what they model
- LockProfile options and what they model
- VoteTimingConfig and how early/mid/late fractions work

### Weighting Layer
- CurveType options (sqrt/linear/log/exp) and their formulas
- lock_curve() parameters: l_max_days, floor
- NOTE: exp curve exists in weighting but factory ScenarioCurveType only has sqrt/log/linear -- gap for Sim C

### Budget & Allocation Layer
- AllocationStrategy options
- AllocationDistribution for MC sampling (Beta/truncnorm/uniform)
- VoterLedger and budget constraint mechanics

### Sweep Engine
- SweepConfig axes and cartesian enumeration
- TOML configuration format (with example)
- ProcessPoolExecutor parallelism
- run_sweep() output: SweepResult with summary_df

### Analysis Layer
- All 6 analysis functions with input/output descriptions
- Statistical tests available (Mann-Whitney U, bootstrap CI)

### Metrics Layer
- All 10 metric functions with what they measure

### Report Layer
- generate_sweep_report() output structure
- Heatmaps, detail plots, composite figures, CSV/JSON

## Proposed Simulations

### Sim C: Curve Sensitivity (PRIORITY 1)
**Research Question:** Which lock curve shape best amplifies small holders while maintaining whale accountability?
**Sweep Design:**
- curve_types: [sqrt, linear, log, exp]
- floor values: [0.0, 0.1, 0.3]
- Fixed: pareto stake, independent locks, n_voters=200

**Infrastructure Status:**
- READY: sweep engine, metrics, report bundle, 3 of 4 curves (sqrt/linear/log)
- GAP: `exp` curve exists in weighting/signals.py but NOT in factory.py ScenarioCurveType -- factory validates against ('sqrt', 'log', 'linear') and will reject 'exp'
- GAP: `floor` parameter exists in lock_curve() but is NOT exposed through generate_scenario() -- hardcoded at 0.1 in factory
- NEEDS: (1) Add 'exp' to ScenarioCurveType in factory.py, (2) Thread `floor` param through generate_scenario() -> weighting calls, (3) Add `floors` axis to SweepConfig for cartesian sweep

**Key Metrics:** Gini delta (legacy vs signals), ENP ratio, top-k concentration shift, flip rate by margin class
**Expected TOML:**
```toml
[base]
n_voters = 200
seed = 42
stake_profile = "pareto"

[sweep]
curve_types = ["sqrt", "linear", "log", "exp"]
floors = [0.0, 0.1, 0.3]
alphas = [0.7]
max_workers = 4
```

### Sim D: Sybil Splitting Attack (PRIORITY 2)
**Research Question:** Does splitting stake into many wallets game the sqrt curve? Is honest whale strategy better than sybil splitting under budget constraints + lock duration?
**Experiment Design:**
- Compare: 1 whale with S tokens vs N wallets with S/N tokens each
- Both strategies: same total budget, same lock duration commitment
- Test across curve types to find which curves are sybil-resistant

**Infrastructure Status:**
- READY: generate_scenario() with configurable n_voters and stakes, lock_curve() math, all metrics
- GAP: No sybil-specific scenario generator -- factory generates random voters, cannot model "1 whale splits into N wallets" adversarial strategy
- NEEDS: (1) Custom scenario builder or factory extension that takes a whale_budget and split_count, generates split wallets alongside honest voters, (2) Comparison harness to run honest-whale vs sybil side-by-side, (3) New metric: sybil_advantage = signals_share(sybil) / signals_share(honest_whale)

**Key Metrics:** sybil_advantage ratio, Gini under sybil attack, ENP distortion, effective weight comparison
**Complexity:** MEDIUM-HIGH -- needs new scenario generation logic, not just sweep parameterization

### Sim E: Participation Incentive Effect (PRIORITY 4)
**Research Question:** Does vote timing matter for fairness? Do late-voting whales get dampened by decay? Correlation between timing and stake rank.
**Sweep Design:**
- vote_timings: multiple VoteTimingConfig with varying early/mid/late splits
- Correlate: timing_sensitivity() analysis already built (ANAL-03)
- Cross with: stake archetypes (whale/medium/retail from voter_archetypes ANAL-04)

**Infrastructure Status:**
- READY: VoteTimingConfig, vote_timings sweep axis, timing_sensitivity() 2D heatmap, voter_archetypes(), influence_significance()
- READY: generate_scenario() accepts vote_timing parameter, sweep engine passes it through
- GAP: No timing decay mechanism exists -- current system does NOT penalize late votes. The question "do late voters get dampened by decay" implies a decay function that does not exist in the codebase
- NEEDS: If testing existing system: just sweep vote_timings and analyze timing_sensitivity correlation with stake rank (mostly ready). If testing a NEW decay mechanism: need to design and implement a timing-weight decay function in weighting layer

**Key Metrics:** timing_sensitivity heatmap, address_influence by archetype, correlation of vote_block_rank with stake_rank
**Complexity:** LOW if analyzing existing behavior, HIGH if implementing timing decay

### Sim F: Bimodal Stakes with Conviction-Weighted Allocation (PRIORITY 3)
**Research Question:** With bimodal stake distribution (10% whales, 90% retail), does conviction_weighted allocation force whales to spread thin across proposals?
**Sweep Design:**
- stake_profile: 'bimodal'
- allocation_strategy: 'conviction_weighted'
- Cross with: curve_types, lock_profiles
- Compare against: uniform_fraction allocation as control

**Infrastructure Status:**
- READY: stake_profile='bimodal' in factory, allocation_strategy='conviction_weighted' in budget module, sweep engine, all metrics
- READY: generate_scenario() accepts all needed parameters
- READY: margin_class_breakdown for flip analysis, voter_archetypes for whale/retail classification
- MOSTLY READY: Can run immediately with existing infrastructure

**Key Metrics:** flip_rate by margin class, Gini delta, per-archetype influence shift, budget utilization by archetype
**Expected TOML:**
```toml
[base]
n_voters = 200
seed = 42
stake_profile = "bimodal"

[sweep]
curve_types = ["sqrt", "linear", "log"]
allocation_strategies = ["conviction_weighted", "uniform_fraction"]
alphas = [0.7]
max_workers = 4
```
**Complexity:** LOW -- all infrastructure exists

### Sim G: Scale Sensitivity (PRIORITY 5)
**Research Question:** Does Signals advantage hold at different voter population sizes?
**Sweep Design:**
- n_voters: [50, 200, 500, 2000]
- Cross with: best curve_type from Sim C results
- Fixed: pareto stake, independent locks

**Infrastructure Status:**
- READY: generate_scenario(n_voters=N) accepts any voter count, sweep engine, all metrics
- GAP: n_voters is NOT a SweepConfig axis -- it lives in base config, not in the cartesian grid
- NEEDS: (1) Add n_voters_list axis to SweepConfig, (2) Thread through _enumerate_cells and _run_cell, OR (3) Run 4 separate sweeps and manually compare results (simpler, no code changes)
- CONSIDERATION: n_voters=2000 with 30 proposals will be slow -- may need to reduce n_proposals or increase cell_timeout_seconds

**Key Metrics:** Gini delta vs n_voters, ENP ratio vs n_voters, flip_rate vs n_voters, margin_shift vs n_voters
**Complexity:** LOW if running separate sweeps, MEDIUM if adding n_voters as sweep axis

## Dependency Map

```
Sim C (Curve Sensitivity) -----> Sim G (Scale) uses best curve from C
    |
    +---> Sim D (Sybil) tests curve robustness
    |
    +---> Sim F (Bimodal + Conviction) uses best curve from C

Sim E (Participation/Timing) -- independent, can run anytime after infrastructure exists
```

## Priority Execution Order with Rationale

| Order | Sim | Rationale | Blocking Work |
|-------|-----|-----------|---------------|
| 1 | C | Foundation -- determines which curve to use in all others | Add exp curve + floor param to factory, add floors to SweepConfig |
| 2 | D | Security -- must validate sybil resistance before recommending a curve | New sybil scenario builder |
| 3 | F | Mechanism -- tests conviction_weighted with bimodal stakes | None (ready now, but benefits from C's curve recommendation) |
| 4 | E | Fairness -- timing analysis, may need decay mechanism | Clarify: analyze existing or build new decay? |
| 5 | G | Scale -- validates that chosen design holds at scale | Minor: n_voters sweep axis or separate runs |

## Infrastructure Gaps Summary

| Gap | Affects | Effort | Description |
|-----|---------|--------|-------------|
| exp curve not in factory | Sim C | Small | Add 'exp' to ScenarioCurveType, thread through factory |
| floor not exposed | Sim C | Small | Add floor param to generate_scenario(), thread to lock_curve() calls |
| floors not a sweep axis | Sim C | Small | Add floors list to SweepConfig, enumerate in cartesian product |
| Sybil scenario builder | Sim D | Medium | New function to generate adversarial split-wallet scenarios |
| Sybil advantage metric | Sim D | Small | New metric comparing sybil vs honest weight outcomes |
| Timing decay mechanism | Sim E | Medium-Large | Only if testing a NEW decay feature (not needed if analyzing existing behavior) |
| n_voters sweep axis | Sim G | Small-Medium | Add to SweepConfig or run separate sweeps |

## Quick Wins (No Code Changes Needed)

Sim F can run TODAY with a TOML config file:
- stake_profile='bimodal' + allocation_strategy='conviction_weighted' already work
- Just write the TOML and call run_sweep()

## v3.0 Milestone Reference

All infrastructure was built across v1.0-v3.0 (Phases 1-12):
- v1.0 (Phases 1-2): Poetry to uv migration
- v2.0 (Phases 3-7): Foundation, cadCAD, Metrics, Plots, Pipeline
- v3.0 (Phases 8-12): Budget promotion, MC allocation, Sweep engine, Extended analysis, Report bundle

207+ tests passing. 33/33 v3.0 requirements shipped.
```

IMPORTANT: The guide must be precise about what parameters factory.py actually accepts. Read the `generate_scenario()` signature carefully -- it has ScenarioCurveType = Literal['sqrt', 'log', 'linear'] (NO 'exp'). The weighting module has CurveType = Literal['sqrt', 'linear', 'log', 'exp'] (HAS 'exp'). This mismatch is a real gap that Sim C must address.

IMPORTANT: The `floor` parameter in `lock_curve()` defaults to 0.1 but is NOT exposed through `generate_scenario()`. The factory calls the weighting functions internally with whatever floor is hardcoded. This is a real gap for sweeping floor values.

IMPORTANT: For Sim D, there is NO existing mechanism to model sybil attacks. The factory generates random voters -- it cannot model "whale X splits into N wallets." This requires genuinely new code.
  </action>
  <verify>
    <automated>test -f apps/simulations/THESIS_GUIDE.md && wc -l apps/simulations/THESIS_GUIDE.md | awk '{if ($1 >= 200) print "PASS: "$1" lines"; else print "FAIL: only "$1" lines"}'</automated>
  </verify>
  <done>
    - THESIS_GUIDE.md exists in apps/simulations/ with 200+ lines
    - All 5 sims (C through G) have sections with research question, sweep design, infrastructure status (READY/GAP/NEEDS), key metrics, and complexity rating
    - Infrastructure inventory section documents all existing modules with their public APIs
    - Dependency map shows inter-simulation dependencies
    - Gap summary table lists every code change needed with effort estimate
    - Priority ordering matches C->D->F->E->G with justification
  </done>
</task>

</tasks>

<verification>
- Document exists at apps/simulations/THESIS_GUIDE.md
- All 5 simulations covered with actionable detail
- Infrastructure gaps are specific (file + function + what's missing), not vague
- No false claims about what exists (e.g., does not claim exp curve works in factory)
</verification>

<success_criteria>
A developer reading THESIS_GUIDE.md can:
1. Understand exactly what infrastructure exists and where it lives
2. Know which sims can run today (F) vs which need code changes (C, D, E, G)
3. Identify the specific code changes needed for each gap
4. Plan milestone work in the correct priority order
</success_criteria>

<output>
After completion, create `.planning/quick/1-build-thesis-guide-from-milestones-for-p/1-SUMMARY.md`
</output>
