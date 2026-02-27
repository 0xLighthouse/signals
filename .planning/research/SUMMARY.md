# Project Research Summary

**Project:** Signals — Backtesting & cadCAD Simulation Pipeline (v2.0)
**Domain:** DAO Governance Simulation — commitment-weighted voting backtester
**Researched:** 2026-02-27
**Confidence:** HIGH

## Executive Summary

This project builds a Python backtesting pipeline to validate the Signals Protocol — a commitment-weighted voting mechanism where voting power equals `W = stake × f(lock_duration)`. The pipeline replays synthetic Governor-compatible events through cadCAD, computes dual tallies (legacy token-weighted vs Signals commitment-weighted) per proposal, and produces publication-grade metrics and plots. The existing codebase already has a working cadCAD PSUB pipeline and a `GovernanceMetrics` class; v2.0 extends it with a new `backtesting/` package without touching existing modules. The core deliverable is evidence — specifically, flip rate statistics and Gini/ENP comparisons — sufficient for academic publication.

The recommended approach is schema-first: define Governor-compatible event types as Python dataclasses before writing any generator, replayer, or metric. Everything downstream — synthetic data factory, cadCAD state update functions, and metrics — depends on this schema contract. Event replay is implemented as a single cadCAD simulation pass that accumulates both tallies simultaneously in state, producing one clean results DataFrame. Parameter sweeps over lock curve shape (alpha) and decay rate are handled via cadCAD's `Experiment` API with externally-built Cartesian product configurations, since cadCAD's M parameter has a documented 2-distinct-length constraint that prevents true factorial sweeps natively.

The critical risks are cadCAD-specific: state mutation in SUFs silently corrupts history; global initial state leaks between sweep runs inflate later metrics; and the cadCAD timestep off-by-one at substep=1 shifts epoch-dependent calculations. A second category of risk is scientific: uniform token distributions produce unrealistically low Gini coefficients that won't hold when swapped to real DAO data, and event-replay results must be explicitly framed as "counterfactual tally" — not as "simulated participation" — to avoid overclaiming behavioral effects. Both categories require upfront discipline, not post-hoc patching.

---

## Key Findings

### Recommended Stack

The existing `apps/simulations/pyproject.toml` is nearly complete. Three additions are required and one latent bug must be fixed. `scipy` is already imported in `src/statistical_analysis/metrics.py` but is not listed as a dependency — it must be pinned explicitly at `>=1.13.0,<2`. `plotly>=6.0.0,<7` adds interactive HTML sweep heatmaps as a complement to matplotlib's static publication PDFs. `pydantic>=2.0.0,<3` validates Governor event schemas at construction time, making the synthetic-to-real data swap zero-cost. `kaleido>=0.2.1,<1.0` enables plotly static export without Chrome in CI. `tqdm>=4.66.0,<5` provides progress feedback for long sweeps.

**Core technologies:**
- `scipy>=1.13.0,<2` — statistical tests (Mann-Whitney U, KS) and confidence intervals — already used, must be pinned (latent bug fix)
- `plotly>=6.0.0,<7` — interactive sweep heatmaps for exploratory analysis; complement to matplotlib, not replacement
- `pydantic>=2.0.0,<3` — Governor event schema validation; Rust-backed v2 catches schema drift before it corrupts runs
- `kaleido>=0.2.1,<1.0` — plotly static export; pin `<1.0` to avoid Chrome dependency in headless CI
- `tqdm>=4.66.0,<5` — progress bars for parameter sweeps; zero-config, works in terminal and Jupyter

**What NOT to add:** scikit-learn, dask/ray, polars, hvplot, altair. None are needed and each adds costly transitive dependencies or library conflicts.

### Expected Features

The feature dependency graph is unambiguous: Governor-compatible event schema blocks everything. Define it first. From there, synthetic data factory and cadCAD event-replay state machine unblock all tallies, which unblock flip rate, which unblocks all analysis and visualization.

**Must have — Phase 1 (table stakes for a credible dual-tally pipeline):**
- Governor-compatible event schema (dataclasses for `PROPOSAL_CREATED`, `VOTE_CAST`, `PROPOSAL_FINALIZED`) — foundation for all else
- Synthetic event stream generator — power-law stake distribution, configurable participation rate
- cadCAD event-replay state machine — PSUB consuming pre-sorted event list, one event per timestep
- Legacy tally (token-weighted) — `W = stake`; per-proposal For/Against sums and winner
- Signals tally (commitment-weighted) — `W = stake × f(L)` with parameterized lock curve
- Dual-tally state — both results per proposal carried simultaneously in a single sim pass
- Flip rate metric — per-proposal and aggregate; core evidence for the paper
- Gini coefficient — over stake and over `W_signals` distributions
- Participation rate — per-proposal and aggregate
- Results DataFrame and basic plots — distribution histogram, dual-tally bar, flip summary

**Should have — Phase 2 (complete metrics and analysis suite):**
- ENP (Effective Number of Parties) and Nakamoto coefficient — one numpy formula each, high publication value
- Lorenz curve + Gini visualization — publication-expected inequality plot
- Configurable voter behavior profiles — power-law / uniform / bimodal for scenario testing
- Reproducible seed control — `numpy.random.default_rng(seed)` threaded through generator and cadCAD
- Lock duration distribution plot — histogram with Signals weight overlay

**Defer to Phase 3+ (nice to have):**
- Parameter sweep over lock curve exponent and decay rate
- Sensitivity analysis plots (flip rate vs alpha)
- Timing sensitivity analysis (vote bucketing by proposal lifecycle position)
- Outcome flip breakdown by legacy margin class

**Anti-features — do not build:**
- Real-time / streaming simulation (premature; adds web3.py/RPC infra)
- Agent-based strategic voter modeling (overclaims beyond replay scope)
- Interactive Streamlit/Dash dashboard (matplotlib static figures are the deliverable)
- Full Shapley value computation (O(2^n), infeasible at realistic voter counts)

### Architecture Approach

The architecture isolates all new v2.0 code in a single new top-level package `backtesting/` while extending (not reorganizing) existing `cadcad/` modules by appending new functions and dataclasses alongside existing ones. The key structural decision is that `backtesting/weighting/signals.py` contains only pure functions — no cadCAD dependency — making the core scientific claim (`W = S × f(L)`) independently testable. The data schema defined in `backtesting/data/schema.py` is the contract that makes synthetic-to-real data swappable: only `loader.py` changes when real Governor data becomes available.

**Major components:**
1. `backtesting/data/` — schema, synthetic factory, loader; produces a sorted `pd.DataFrame` of events
2. `backtesting/weighting/signals.py` — pure functions: `lock_curve()`, `compute_signals_weight()`, `compute_legacy_weight()`
3. `cadcad/` extensions — `BacktestConfig`, `BacktestState`, `p_replay_event()`, `sufs/replay.py`; orchestrates event-driven simulation via `Experiment` API
4. `backtesting/metrics/` — Gini, ENP, flip rate, sensitivity; pure functions on `pd.DataFrame` inputs
5. `backtesting/plots/` — publication-grade matplotlib figures; one function per chart type using OO API exclusively
6. `backtesting/pipeline.py` — single entry point orchestrating all layers: data → sim → metrics → plots

**Build order matters:** schema → weighting → factory → loader → cadCAD extensions → metrics → plots → pipeline. Tests at each layer boundary before proceeding.

### Critical Pitfalls

1. **cadCAD state mutation (Pitfall 1, CRITICAL)** — SUFs that mutate dicts/lists/sets in-place corrupt state history silently. Every SUF touching a mutable state variable must return a new copy (`dict(prev_state['x'])`). Test by asserting `id(result) != id(prev_state['key'])` in every SUF test. Corruption manifests as non-reproducible metrics under identical seeds.

2. **Global initial state leaking between sweep runs (Pitfall 3, CRITICAL)** — If `generate_initial_state()` is called once outside the sweep loop, run 2+ starts from run 1's terminal state (non-empty `accepted_initiatives`, inflated `reward_history`). Always call `generate_initial_state()` inside each sweep iteration, or guard with `copy.deepcopy()`. Test by asserting initial state purity (len == 0) before each run.

3. **cadCAD M parameter sweep constraint (Pitfall 5, HIGH)** — cadCAD's `config_sim()` M parameter allows at most 2 distinct list lengths and zips (not Cartesian products) parameter lists. Build Cartesian products externally with `itertools.product` and run N `Configuration` objects. Always log expected vs actual combination count at sweep start; assert they match.

4. **Uniform token distribution producing misleading Gini (Pitfall 4, HIGH)** — Real DAOs have Gini ≈ 0.7–0.95. Uniform synthetic balances produce Gini ≈ 0.3–0.5, making Signals appear more impactful than realistic. Generate balances from a Pareto distribution (alpha ≈ 1.5). Validate: `gini(initial_balances) > 0.65` in tests.

5. **Event-replay vs ABM framing (Pitfall 10, MEDIUM)** — Event replay computes a counterfactual tally (what outcome would have occurred under different weighting), not a behavioral simulation. Label all plots and metrics as "counterfactual" — never as "simulated participation" or "behavior change." Establish this in docstrings before any implementation begins.

---

## Implications for Roadmap

Based on combined research, 5 phases are recommended. The first three deliver the complete dual-tally pipeline and publication-ready metrics. Phases 4 and 5 add sweep infrastructure and sensitivity analysis.

### Phase 1: Foundation — Schema, Data, and Weighting

**Rationale:** The Governor event schema is a hard dependency for everything else. Nothing can be built, tested, or validated without it. The weighting pure functions are equally foundational and trivially testable — establishing them early de-risks the core scientific claim.

**Delivers:** A complete, testable data layer that can be exercised without cadCAD. Synthetic event stream, canonical schema, and weight functions ready for cadCAD integration.

**Addresses:** Governor-compatible event schema, synthetic event stream generator, Signals tally formula — all P1 features from FEATURES.md.

**Avoids:** Lock-duration survivorship bias (Pitfall 8) by sampling from full Pareto distribution at generation time; Uniform distribution mismatch (Pitfall 4) by validating Gini > 0.65 immediately; Governor schema referential integrity violations by validating every VOTE_CAST references a valid PROPOSAL_CREATED.

**Files:** `backtesting/data/schema.py`, `backtesting/data/factory.py`, `backtesting/data/loader.py`, `backtesting/weighting/signals.py`

### Phase 2: cadCAD Integration — Event Replay and Dual Tally

**Rationale:** cadCAD integration is the highest-complexity phase and has the most pitfall exposure. Isolating it from metrics and plotting means cadCAD-specific failures are immediately attributable. A single integration test (3 proposals, 10 votes each) validates the entire path before metrics are added.

**Delivers:** A working end-to-end simulation that consumes the Phase 1 event stream, produces both legacy and Signals tallies in a single pass, and outputs a flat results DataFrame. Flip rate is computable from this output.

**Addresses:** cadCAD event-replay state machine, legacy tally, Signals tally, dual-tally state, flip rate, results DataFrame — all P1 from FEATURES.md.

**Implements:** Event-replay via M parameters (Pattern 1), dual tally accumulation in single pass (Pattern 2), `Experiment` API for sweep config (Architecture).

**Avoids:** State mutation corruption (Pitfall 1) — test SUF reference inequality from day one; Global state leak (Pitfall 3) — always regenerate initial state per run; Timestep off-by-one (Pitfall 2) — pass epoch through policy output, not state; N misuse for sweeps (anti-pattern 3) — use M lists, not N.

**Stack additions:** `pydantic` for event validation; `tqdm` for sweep progress.

### Phase 3: Metrics and Basic Plots

**Rationale:** Metrics are pure functions on the results DataFrame — no cadCAD dependency. They can be written and fully tested against recorded DataFrame snapshots from Phase 2. Plots follow directly. This phase completes the P1 MVP and delivers the publication-grade output.

**Delivers:** Gini, participation rate, and flip rate metrics; basic plots (voting power distribution, dual-tally bar, flip rate summary). The core paper appendix is complete at end of this phase.

**Addresses:** Gini coefficient, participation rate, flip rate visualization, basic plots — all P1 from FEATURES.md.

**Avoids:** Gini edge cases (Pitfall 6) — guard for zero-vote proposals, return `np.nan` not 0; ENP floating-point bias (Pitfall 7) — clamp to `[1, n_voters]`; Matplotlib figure state pollution (Pitfall 9) — OO API only, `plt.close(fig)` always, `rcParams` set once at module level.

**Stack additions:** `matplotlib` (existing), `scipy` (pinned fix for latent bug).

### Phase 4: Extended Metrics and Analysis Suite

**Rationale:** ENP, Nakamoto coefficient, Lorenz curve, and seed control are P2 features with no new architectural complexity. They extend the existing metrics module and plotting suite. Configurable voter behavior profiles (power-law / uniform / bimodal) extend the factory from Phase 1. Group together because they share the same DataFrame interface and can be added iteratively.

**Delivers:** Complete publication-grade metrics suite (Gini + ENP + Nakamoto trio), Lorenz curve visualization, reproducible seed control, configurable scenario profiles. Results are academically defensible.

**Addresses:** ENP, Nakamoto coefficient, Lorenz curve, seed control, voter behavior profiles, lock duration distribution plot — all P2 from FEATURES.md.

**Uses:** numpy (existing), plotly for interactive Lorenz exploration alongside matplotlib publication version.

### Phase 5: Parameter Sweeps and Sensitivity Analysis

**Rationale:** Sweep infrastructure is P2/P3 and requires all earlier phases to be stable. cadCAD's M parameter constraint means sweeps need external Cartesian product management — this is a contained complexity that should not block the core pipeline. Add last, after the pipeline is validated end-to-end.

**Delivers:** Full parameter sweep over lock curve alpha and decay rate, sensitivity analysis plots (flip rate vs alpha heatmap), outcome flip breakdown by legacy margin class. This is the "stress test" evidence layer for the paper.

**Addresses:** Parameter sweep support, sensitivity analysis, timing sensitivity, outcome flip breakdown — all P3 from FEATURES.md.

**Avoids:** Combinatorial explosion (Pitfall 5) — always use `itertools.product` externally; assert expected vs actual combo count; cap at 50-100 combos for interactive work.

**Stack additions:** `plotly` sweep heatmaps, `kaleido` for static export.

---

### Phase Ordering Rationale

- Schema before everything: FEATURES.md feature dependency graph is unambiguous — Governor schema is a hard prerequisite for 8+ other features.
- cadCAD integration before metrics: Cannot validate metrics without real simulation output. Integration test with minimal dataset proves the pipeline before investing in analysis.
- Metrics before plots: Plots are pure consumers of metrics output. Decoupling them lets both be independently tested.
- Sweeps last: Sweep correctness depends on the underlying single-run pipeline being verified. Adding sweeps to a broken pipeline produces amplified confusion.
- Pitfall avoidance is phase-specific: State mutation (Phase 2), distribution realism (Phase 1), and figure pollution (Phase 3) each have natural entry points where the cost of prevention is lowest.

### Research Flags

Phases needing deeper research during planning:

- **Phase 2 (cadCAD Integration):** cadCAD's event-replay pattern is documented but not heavily demonstrated in official examples. The exact SUF composition order within PSUBs and the `Experiment` API for backtest sweeps warrants a targeted research-phase before implementation to confirm behavior of `substep` filtering in results.
- **Phase 5 (Parameter Sweeps):** The cadCAD M parameter 2-length constraint is a known pitfall (GitHub issue #195). The external Cartesian product pattern is the workaround, but its interaction with cadCAD's `subset` indexing in results should be validated with a small spike before building full sweep infrastructure.

Phases with standard patterns (skip research-phase):

- **Phase 1 (Schema and Data):** Python dataclasses and Pareto distribution sampling are well-documented. No ambiguity.
- **Phase 3 (Metrics and Plots):** Gini, ENP, Nakamoto are standard formulae. Matplotlib OO API is fully documented. No ambiguity.
- **Phase 4 (Extended Metrics):** All additions are incremental to Phase 3 patterns. No new integration surfaces.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified via PyPI; scipy latent bug confirmed by direct codebase read; cadCAD sweep constraint confirmed via official docs and GitHub issues |
| Features | HIGH | Feature dependency graph built from existing codebase analysis and DAO governance literature (2023-2025 papers); P1/P2/P3 split is unambiguous |
| Architecture | HIGH | Existing code read directly; cadCAD API verified via official docs; module boundaries are explicit and testable |
| Pitfalls | HIGH | cadCAD pitfalls verified via GitHub issues; distribution mismatch validated against empirical DAO data from published papers; matplotlib pollution is a documented known issue |

**Overall confidence:** HIGH

### Gaps to Address

- **Real DAO data schema conformance:** The Governor-compatible schema is designed for Compound/Uniswap/ENS Governor Bravo data, but no real data was fetched during research to validate the field mapping. When swapping from synthetic to real data, validate `loader.py` against at least one real Compound proposal event log before claiming zero-cost swap.
- **Lock curve calibration:** The alpha parameter for `f(L) = 1 - exp(-alpha × L)` has no empirically-grounded default. Research suggests alpha ≈ 0.5 gives ~78% of max weight at 3 months, but this should be validated against veToken (Curve, Velodrome) real locking data during Phase 4 or 5.
- **cadCAD 0.5.x vs 0.4.x API:** The existing codebase uses `cadCAD>=0.5.3`. The research references cadCAD API patterns from official docs and README, but the internal API has changed between 0.4.x and 0.5.x. Confirm that `Experiment.append_model()` behaves as documented in 0.5.x before Phase 2 implementation.

---

## Sources

### Primary (HIGH confidence)
- cadCAD official docs (Parameter Sweep, Simulation Execution, Configuration API) — cadCAD sweep constraints, Experiment API, result row structure
- cadCAD GitHub issues #250, #195 — timestep off-by-one, multi-config truncation bugs
- Existing codebase (`apps/simulations/src/`) — read directly; confirmed scipy usage, cadCAD PSUB patterns, GovernanceMetrics implementation
- scipy PyPI (v1.15.3 current), plotly PyPI (v6.5.2 current), pydantic PyPI (v2.12.x current) — version verification
- Governor Bravo source (compound-finance/compound-protocol) — event schema field names

### Secondary (MEDIUM confidence)
- DAO Large Scale Analysis (arxiv 2410.13095) — Gini benchmarks across 10K+ DAOs; participation rates; Nakamoto baselines
- Analyzing Voting Power in Decentralized Governance (ScienceDirect 2096720924000216) — Nakamoto, Gini empirical values for real DAOs
- Voting-Bloc Entropy paper (Fabrega et al. USENIX Security / arxiv 2509.22620) — VBE definition, Gini/Nakamoto comparison; confirms our metric trio is sufficient
- Laakso-Taagepera ENP formula (1979) — verified via Wikipedia; standard political science reference

### Tertiary (LOW confidence — validate during implementation)
- Lock curve alpha calibration (inferred from veToken mechanisms) — no peer-reviewed source; validate against real locking data
- cadCAD 0.5.x `Experiment` API behavior (inferred from README + 0.4.x patterns) — confirm against actual 0.5.x source before Phase 2

---
*Research completed: 2026-02-27*
*Ready for roadmap: yes*
