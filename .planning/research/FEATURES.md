# Feature Research

**Domain:** DAO Governance Simulation — Backtesting & cadCAD Simulation Pipeline
**Researched:** 2026-02-27
**Confidence:** HIGH (cadCAD pipeline patterns), MEDIUM (governance metrics standards), HIGH (existing codebase context)

---

## Context: What Already Exists

The project already has a working cadCAD pipeline in `apps/simulations/src/cadcad/` using cadCAD 0.4.x
(PSUBs, policy functions, state update functions, `config_sim`, `Executor`). It also has a
`GovernanceMetrics` class with Gini, preference intensity, opportunity cost, sybil resistance,
and inclusivity metrics. The v2.0 milestone replaces the initiative/support model with a
Governor-style proposal/vote event stream and adds dual-tally comparison.

**Existing infrastructure the new features depend on:**
- cadCAD 0.4.x installation + PSUB pipeline pattern
- `GovernanceMetrics` class with `_calculate_gini_coefficient()`
- `StatisticalTests` class with Mann-Whitney U, t-test, KS test, Cohen's d
- uv + Python 3.12 + src/ layout

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features a governance simulation researcher expects. Missing any of these makes the tool
unconvincing as a validation instrument.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Synthetic event stream generator | Simulation requires data; no real DAO data available yet | MEDIUM | Must emit `PROPOSAL_CREATED`, `VOTE_CAST`, `PROPOSAL_FINALIZED` events matching Governor schema. Configurable voter count, proposal count, stake distribution (power-law), participation rate. |
| Governor-compatible event schema | Required for zero-cost swap to real Compound/Uniswap/ENS data later | LOW | Define a dataclass or TypedDict schema. Stick to fields: proposal_id, voter, stake, lock_duration, vote (for/against/abstain), timestamp, block_number. |
| cadCAD event-replay state machine | Core of "backtesting" — replaying events through simulation | HIGH | Each event becomes a timestep input. Policy function consumes next event from the stream, state update functions apply it. Requires event iterator/generator pattern inside cadCAD PSUB. |
| Legacy tally (token-weighted) | Baseline to compare against Signals — without this, no diff | LOW | Simple: `W_legacy = stake`. Sum For/Against by stake. Determine winner. Store per-proposal. |
| Signals tally (commitment-weighted) | Core hypothesis: `W_signals = stake × f(lock_duration)` | MEDIUM | Implement `f(L)` as monotonic curve (log or sqrt) with diminishing returns after ~3 months. Parameterized. Sum For/Against by W_signals. Store per-proposal. |
| Dual-tally per proposal | The comparison is the entire point — both tallies must run in parallel | MEDIUM | State must carry both `legacy_result` and `signals_result` per proposal. Winner (For/Against/Tie) derived from each. |
| Gini coefficient (voting power) | Standard decentralization metric; expected by any governance researcher | LOW | Already implemented in `GovernanceMetrics._calculate_gini_coefficient()`. Apply to stake distribution and to W_signals distribution. |
| Participation rate | Most basic governance health metric | LOW | `participating_voters / eligible_voters` per proposal and aggregated. |
| Flip rate | Core evidence for the paper — how often does Signals change the outcome? | MEDIUM | Per-proposal: `legacy_winner != signals_winner`. Aggregate: `flipped_proposals / total_proposals`. Requires dual-tally. |
| Parameter sweep support | Without sweeps, results are single-scenario anecdotes, not evidence | HIGH | Use cadCAD `M` param dict with multiple values per key. Or radCAD `Experiment` pattern. Sweep lock curve exponent, decay rate, max_lock_duration. Returns DataFrame with `run_id`, `subset` columns. |
| Results DataFrame output | Standard cadCAD output — all downstream analysis depends on it | LOW | cadCAD `Executor.execute()` returns raw_result list. Convert to pandas DataFrame. Already done in existing model.py. |

### Differentiators (Competitive Advantage)

Features that make this tool produce *publication-grade* evidence rather than just a demo.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Effective Number of Parties (ENP) | More interpretable than Gini for "how many effective voters?" — used in political science | LOW | `ENP = 1 / sum(s_i^2)` where s_i is voter i's share of total voting power. Standard Herfindahl-Hirschman inverse. One function, zero deps beyond numpy. |
| Nakamoto coefficient | Answers "how many whales control 51%?" — cited heavily in DAO research | LOW | Sort voters by stake descending, cumsum until >50% total. Count. Trivial to compute, high publication value. |
| Lorenz curve + Gini visualization | Publication-grade inequality plot — reviewers expect it | MEDIUM | Plot cumulative share of voters vs cumulative share of voting power. Use matplotlib, add 45° equality line. One plot per condition (legacy vs signals). |
| Timing sensitivity analysis | When in proposal lifecycle voters commit affects outcomes | HIGH | Bucket votes by time-into-proposal (early/mid/late). Compute tally at each bucket boundary. Show how Signals vs legacy diverge over time. Requires timestamped vote replay. |
| Lock duration distribution plot | Shows voter commitment profile — validates that the lock curve drives differentiation | LOW | Histogram of lock_duration at vote time, colored by For/Against. Signals weight overlaid. Pure matplotlib. |
| Outcome flip breakdown by proposal type | Not all flips are equal — some proposals are closer to threshold | MEDIUM | Classify proposals by "margin of victory under legacy": close (<5%), moderate (5-20%), blowout (>20%). Flip rate by class. |
| Sensitivity analysis (lock curve exponent) | Answers "does Signals work under a range of curve shapes?" | HIGH | Sweep `f(L)` exponent from 0.3 to 1.0 in steps. Plot flip rate vs exponent. Requires parameter sweep infra. |
| Reproducible seed control | Required for academic reproducibility — reviewers may try to replicate | LOW | Pass `random_seed` into synthetic data generator and cadCAD config. Use `numpy.random.default_rng(seed)`. |
| Configurable voter behavior profiles | Allows testing "whales vs minnows vs mixed" scenarios | MEDIUM | Three pre-built profiles: power-law distribution (realistic), uniform distribution (baseline), bimodal (whale-dominated). Controls stake and lock_duration sampling. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time / streaming simulation | "Let's process live on-chain events" | Premature — the goal is validation via backtesting synthetic data; real data is a v3 concern. Adds infra complexity (web3.py, node RPC, rate limiting) with zero validation benefit. | Keep data source as a swappable generator; plug in real data later by conforming to Governor schema. |
| Agent-based voter strategy modeling | "Voters are strategic, let them optimize" | Explodes model complexity; behavioral assumptions become load-bearing and hard to validate. The project goal is mechanism validation, not agent behavior modeling. | Use realistic stake/lock distributions sampled from veToken real data as proxy for strategic behavior. |
| On-chain deployment / gas modeling | "Let's simulate gas costs" | Out of scope per PROJECT.md. Adds Solidity/EVM dependencies to the Python sim sub-project. | Simulation only — gas is a separate engineering concern. |
| Interactive dashboard (Streamlit/Dash) | "Plots should be interactive" | Matplotlib/seaborn publication-grade static figures are the deliverable. Interactive adds a runtime UI dep, complicates CI, and is unnecessary for a paper appendix. | Export high-DPI PNG/PDF from matplotlib. Plotly optional for exploratory work only, not the primary output. |
| Full Shapley value computation | "Shapley is the gold standard for voting power" | O(2^n) complexity — infeasible for realistic voter counts (>30). Produces identical narrative to Nakamoto + Gini at far higher cost. | Use Nakamoto coefficient as the coalitional power proxy. |
| Predictive / forward-looking simulation | "Forecast what will happen to this DAO" | Requires behavioral economics assumptions with no ground truth. The goal is backward-looking validation. | Restrict to event-replay backtesting against synthetic data with known ground truth. |

---

## Feature Dependencies

```
[Governor-compatible event schema]
    └──required by──> [Synthetic event stream generator]
    └──required by──> [cadCAD event-replay state machine]
    └──required by──> [Legacy tally]
    └──required by──> [Signals tally]

[cadCAD event-replay state machine]
    └──required by──> [Dual-tally per proposal]
                          └──required by──> [Flip rate]
                          └──required by──> [Outcome flip breakdown by proposal type]
                          └──required by──> [Timing sensitivity analysis]

[Legacy tally] + [Signals tally]
    └──both required by──> [Dual-tally per proposal]

[Results DataFrame output]
    └──required by──> [Gini coefficient]
    └──required by──> [Participation rate]
    └──required by──> [ENP]
    └──required by──> [Nakamoto coefficient]
    └──required by──> [Flip rate]
    └──required by──> [All visualizations]

[Parameter sweep support]
    └──enhances──> [Sensitivity analysis (lock curve exponent)]
    └──enhances──> [Configurable voter behavior profiles]

[Gini coefficient] ──enhances──> [Lorenz curve visualization]

[Flip rate] ──enhances──> [Outcome flip breakdown by proposal type]
```

### Dependency Notes

- **Governor-compatible event schema blocks everything:** Define the schema as the first deliverable. All generators, replay, tallies, and metrics depend on consistent field names.
- **Dual-tally requires the event-replay state machine:** You cannot compute per-proposal flip without replaying events and tracking both tallies simultaneously in cadCAD state.
- **Parameter sweep is independent but high-value:** The core pipeline (schema → generator → replay → dual-tally → metrics → plots) can be built and validated before adding sweeps. Add sweeps in a later phase.
- **ENP / Nakamoto coefficient have zero additional deps:** They are pure numpy functions over the stake distribution. Build them alongside Gini.
- **Lorenz curve visualization depends on Gini being computed:** Both use the same sorted cumulative distribution. Compute together, visualize separately.
- **Timing sensitivity depends on timestamped votes in the event stream:** The event schema must include `timestamp` and the synthetic generator must produce realistic arrival distributions (not uniform).

---

## MVP Definition

### Launch With (Phase 1 of v2.0)

Minimum to produce credible dual-tally comparison results.

- [ ] Governor-compatible event schema (dataclass/TypedDict with proposal_id, voter, stake, lock_duration, vote, timestamp) — foundation for everything
- [ ] Synthetic event stream generator — configurable voter count, proposal count, power-law stake distribution, participation rate, lock duration sampling
- [ ] cadCAD event-replay state machine — PSUB that consumes events from iterator, replays them as timesteps
- [ ] Legacy tally (token-weighted) — `W = stake`, per-proposal For/Against sums, winner
- [ ] Signals tally (commitment-weighted) — `W = stake × f(lock_duration)` with parameterized curve
- [ ] Dual-tally state — carry both results per proposal in cadCAD state
- [ ] Flip rate metric — per-proposal and aggregate
- [ ] Gini coefficient — over stake and over W_signals distributions
- [ ] Participation rate — per-proposal and aggregate
- [ ] Results DataFrame — standard cadCAD output, already proven in existing model.py
- [ ] Basic plots — voting power distribution (histogram), dual-tally comparison (bar), flip rate summary

### Add After Core Pipeline Validates (Phase 2 of v2.0)

- [ ] ENP (Effective Number of Parties) — add once metrics module exists; one numpy formula
- [ ] Nakamoto coefficient — same; add alongside ENP
- [ ] Lorenz curve + Gini visualization — add to plotting suite after basic plots work
- [ ] Configurable voter behavior profiles (power-law / uniform / bimodal) — swap the generator's sampling distribution
- [ ] Reproducible seed control — thread a `random_seed` parameter through generator and cadCAD config
- [ ] Lock duration distribution plot — histogram with Signals weight overlay

### Future Consideration (Phase 3 of v2.0 or later)

- [ ] Parameter sweep — cadCAD `M` multi-value sweep over lock curve exponent, decay, max_duration; produces multi-run DataFrame
- [ ] Sensitivity analysis plots — flip rate vs lock curve exponent; requires sweep infra
- [ ] Timing sensitivity analysis — vote bucketing by lifecycle position; adds complexity to event schema processing
- [ ] Outcome flip breakdown by proposal class — classify proposals by legacy margin; depends on a full sweep of scenarios

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Governor-compatible event schema | HIGH | LOW | P1 |
| Synthetic event stream generator | HIGH | MEDIUM | P1 |
| cadCAD event-replay state machine | HIGH | HIGH | P1 |
| Legacy tally | HIGH | LOW | P1 |
| Signals tally (W = S × f(L)) | HIGH | MEDIUM | P1 |
| Dual-tally state per proposal | HIGH | MEDIUM | P1 |
| Flip rate metric | HIGH | MEDIUM | P1 |
| Gini coefficient (stake + W_signals) | HIGH | LOW | P1 |
| Participation rate | MEDIUM | LOW | P1 |
| Results DataFrame output | HIGH | LOW | P1 |
| Basic plots (distribution, dual-tally, flip) | HIGH | MEDIUM | P1 |
| ENP / Nakamoto coefficient | MEDIUM | LOW | P2 |
| Lorenz curve visualization | MEDIUM | MEDIUM | P2 |
| Reproducible seed control | MEDIUM | LOW | P2 |
| Configurable voter behavior profiles | MEDIUM | MEDIUM | P2 |
| Lock duration distribution plot | MEDIUM | LOW | P2 |
| Parameter sweep support | HIGH | HIGH | P2 |
| Sensitivity analysis (lock curve exponent) | HIGH | HIGH | P3 |
| Timing sensitivity analysis | MEDIUM | HIGH | P3 |
| Outcome flip breakdown by proposal class | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for a working dual-tally pipeline
- P2: Should have for a complete metrics + analysis suite
- P3: Nice to have for publication-grade sensitivity analysis

---

## Competitor Feature Analysis

No direct competitors exist for a Signals-specific commitment-weighted governance backtester. The closest analogues are general-purpose governance analysis tools and cadCAD token engineering demos.

| Feature | Tally.xyz / Boardroom (analytics) | BlockScience cadCAD demos | Our Approach |
|---------|---------------------|--------------------------|--------------|
| Voting power distribution | On-chain historical only | Synthetic, initiative-based | Synthetic Governor-schema events, swappable to real |
| Dual-mechanism comparison | None — single tally | Not applicable | Core differentiator: legacy vs Signals side-by-side |
| Gini / concentration metrics | Dashboards exist, not scriptable | Implemented in experiments | Embed in metrics module, output to DataFrame |
| Parameter sweeps | Not applicable | cadCAD M-sweep | Full cadCAD sweep over lock curve parameters |
| Publication-grade plots | Dashboards only | Jupyter notebooks | Matplotlib static figures, DPI-controlled export |
| Reproducibility | On-chain data is reproducible | Seed not always documented | Explicit seed parameter threaded through entire pipeline |

---

## Implementation Notes for cadCAD Event-Replay

The existing codebase uses `p_user_actions` (a stochastic policy) at each timestep. The v2.0 model
replaces this with an event-stream consumer. The standard pattern for cadCAD event-replay:

1. Generator yields the next event from the sorted event list each timestep.
2. A policy function (`p_consume_event`) reads `params['event_stream']` (a Python iterator or
   indexed list) using the current `step` index. Returns the event as a signal.
3. State update functions receive the event signal and apply it:
   - `PROPOSAL_CREATED` → add proposal to proposals state
   - `VOTE_CAST` → apply vote to both legacy_tally and signals_tally in proposals state
   - `PROPOSAL_FINALIZED` → compute winners, store flip result
4. Timesteps T = total event count (not calendar time). Each event is one timestep.
5. Parameter sweep varies `lock_curve_exponent`, `decay_rate`, `max_lock_duration` in `M`.

This is a departure from time-based stepping but maps cleanly to cadCAD's PSUB model.
The cadCAD `step` index into a pre-sorted event list avoids lookahead bias structurally.

---

## Governance Metrics Standards (from Literature)

Metrics that appear in peer-reviewed DAO governance papers (2023-2025):

| Metric | Formula | What It Measures | Used In |
|--------|---------|------------------|---------|
| Gini coefficient | `G = (2 * sum(i*y_i) - (n+1)*sum(y_i)) / (n * sum(y_i))` | Voting power inequality | Ubiquitous in DAO research |
| Nakamoto coefficient | `min k s.t. sum(top_k stakes) > 0.5 * total` | Coalition control threshold | DAO decentralization papers |
| ENP (HHI inverse) | `ENP = 1 / sum(s_i^2)` where `s_i = stake_i / total_stake` | Effective number of independent voters | Political science; increasingly DAO research |
| Participation rate | `voters_on_proposal / eligible_voters` | Turnout | Universal baseline |
| Voting-Bloc Entropy (VBE) | Entropy over aligned voter clusters | Decentralization accounting for coordinated voting | Fabrega et al. USENIX Security 2025 |
| HHI | `sum(s_i^2) * 10000` | Market concentration equivalent | Used for proposal submitter concentration |

For this project, **Gini + ENP + Nakamoto** form a sufficient trio. VBE is research-level complexity
and requires clustering — defer to post-publication work.

---

## Sources

- [Announcing cadCAD 1.0](https://blog.block.science/announcing-cadcad-1-0-foundations-for-a-new-era-of-open-modeling/) — cadCAD 1.0 architecture (BlockScience, 2024)
- [cadCAD PyPI 0.4.28](https://pypi.org/project/cadCAD/0.4.28/) — current stable version used in project
- [radCAD GitHub](https://github.com/CADLabs/radCAD) — simpler cadCAD-compatible alternative with Model/Simulation/Experiment hierarchy
- [cadCAD Parameter Sweep docs](https://github.com/cadCAD-org/cadCAD/blob/master/documentation/System_Model_Parameter_Sweep.md) — M-sweep configuration
- [Voting-Bloc Entropy: A New Metric for DAO Decentralization](https://arxiv.org/html/2509.22620) — VBE definition, Gini/Nakamoto/Shannon comparison (Fabrega et al. 2025)
- [Future of Algorithmic Organization: Large Scale DAO Analysis](https://arxiv.org/pdf/2410.13095) — Gini, HHI, entropy, participation metrics across 10K+ DAOs
- [Analyzing Voting Power in Decentralized Governance](https://www.sciencedirect.com/science/article/pii/S2096720924000216) — Nakamoto, Gini, Shapley for DAO voting power
- [DAO Governance: Voting Power, Participation, and Controversy](https://dl.acm.org/doi/pdf/10.1145/3777416) — comprehensive metrics review
- Existing codebase: `apps/simulations/src/cadcad/model.py` — PSUB pipeline pattern
- Existing codebase: `apps/simulations/src/statistical_analysis/metrics.py` — GovernanceMetrics with Gini, inclusivity, sybil resistance

---

*Feature research for: Signals Backtesting & cadCAD Simulation Pipeline*
*Researched: 2026-02-27*
