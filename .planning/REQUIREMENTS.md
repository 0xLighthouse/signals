# Requirements: Signals Backtesting & Simulation

**Defined:** 2026-02-27
**Core Value:** Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes

## v2.0 Requirements

Requirements for the backtesting & simulation pipeline. Each maps to roadmap phases.

### Data

- [x] **DATA-01**: Governor-compatible event schema defines PROPOSAL_CREATED, VOTE_CAST, and PROPOSAL_FINALIZED as validated data structures with consistent field names
- [x] **DATA-02**: Synthetic event stream generator produces configurable voter counts, proposal counts, and participation rates
- [x] **DATA-03**: Synthetic stake distribution follows power-law (Pareto) with Gini >= 0.65 matching real DAO profiles
- [x] **DATA-04**: Synthetic vote timing follows tri-modal distribution (early, mid, late) within proposal windows
- [x] **DATA-05**: Synthetic data enforces referential integrity (no double votes, no votes outside proposal window)
- [x] **DATA-06**: Pydantic v2 validates all event data at construction time
- [x] **DATA-07**: User can select voter behavior profiles (power-law, uniform, bimodal stake distributions)
- [x] **DATA-08**: User can set a random seed for reproducible event stream generation
- [x] **DATA-09**: Data loader interface supports swapping synthetic for real Governor data with zero architecture changes

### Weighting

- [x] **WGHT-01**: Signals weight function computes W = stake × f(lock_duration) as a pure function independent of cadCAD
- [x] **WGHT-02**: Lock curve f(L) is parameterized and supports linear, log, sqrt, and exponential shapes
- [x] **WGHT-03**: Lock curve exhibits diminishing returns after ~3 months
- [x] **WGHT-04**: Legacy weight function computes W = stake (identity) for baseline comparison

### Simulation

- [ ] **SIM-01**: cadCAD event-replay state machine consumes a pre-sorted event list with one event per timestep
- [x] **SIM-02**: Policy function reads next event from the event stream by step index
- [x] **SIM-03**: State update functions apply PROPOSAL_CREATED, VOTE_CAST, and PROPOSAL_FINALIZED events to state
- [x] **SIM-04**: Legacy tally accumulates For/Against by stake per proposal
- [x] **SIM-05**: Signals tally accumulates For/Against by W_signals per proposal in the same simulation pass
- [x] **SIM-06**: Dual-tally state carries both legacy and Signals results per proposal simultaneously
- [x] **SIM-07**: SUFs return new state copies (never mutate in-place) to prevent cadCAD state corruption
- [ ] **SIM-08**: Simulation outputs a flat results DataFrame with one row per event per tally regime

### Metrics

- [ ] **METR-01**: Flip rate computed per-proposal (legacy_winner != signals_winner) and as aggregate
- [ ] **METR-02**: Gini coefficient computed over legacy stake distribution and over Signals-weighted distribution
- [ ] **METR-03**: Participation rate computed per-proposal and as aggregate
- [ ] **METR-04**: Effective Number of Participants (ENP) computed as 1/sum(s_i^2) for both regimes
- [ ] **METR-05**: Nakamoto coefficient computed as minimum voters controlling >50% of voting power for both regimes
- [ ] **METR-06**: Margin shift computed as difference between legacy and Signals margins per proposal
- [ ] **METR-07**: Outcome transition matrix classifies proposals into Pass→Pass, Pass→Fail, Fail→Pass, Fail→Fail
- [ ] **METR-08**: Late-vote share computed as proportion of voting power cast in final third of proposal window
- [ ] **METR-09**: Lock-in timing identifies when each proposal's outcome becomes irreversible under each regime
- [ ] **METR-10**: Top-k concentration computed for top-1, top-5, top-10 voters under both regimes

### Plotting

- [ ] **PLOT-01**: Flip rate summary bar chart
- [ ] **PLOT-02**: Margin shift histogram (legacy vs Signals margins)
- [ ] **PLOT-03**: Outcome transition matrix visualization
- [ ] **PLOT-04**: Gini before vs after comparison per regime
- [ ] **PLOT-05**: Top-k share comparison chart
- [ ] **PLOT-06**: ENP comparison visualization
- [ ] **PLOT-07**: Cumulative vote curve per selected proposal (legacy and Signals overlaid)
- [ ] **PLOT-08**: Late-vote share comparison
- [ ] **PLOT-09**: Lorenz curve (legacy vs Signals voting power distributions)
- [ ] **PLOT-10**: Proposal story plots showing time evolution of net margin and voter power composition
- [ ] **PLOT-11**: Lock duration distribution histogram with Signals weight overlay
- [ ] **PLOT-12**: All plots use matplotlib OO API, publication-grade styling, and consistent rcParams

### Pipeline

- [ ] **PIPE-01**: Single entry point orchestrates data generation → simulation → metrics → plots
- [ ] **PIPE-02**: Pipeline outputs are saved to a configurable output directory
- [ ] **PIPE-03**: Pipeline can be run from CLI or imported as a Python module

## v2.1 Requirements

Deferred to next milestone. Tracked but not in current roadmap.

### Parameter Sweeps

- **SWEP-01**: Multi-dimensional parameter sweep over lock curve shape, decay steepness, and max lock duration
- **SWEP-02**: Sweep uses external Cartesian product (not cadCAD M-param) to avoid 2-length constraint
- **SWEP-03**: Flip rate heatmap vs sweep parameters
- **SWEP-04**: Gini reduction heatmap vs sweep parameters
- **SWEP-05**: Tradeoff curve (delta-Gini vs flip rate)
- **SWEP-06**: Sensitivity analysis across lock curve exponent range

### Extended Analysis

- **EXTA-01**: Timing sensitivity analysis (vote bucketing by proposal lifecycle position)
- **EXTA-02**: Outcome flip breakdown by legacy margin class (close/moderate/blowout)
- **EXTA-03**: Address-level voting power change visualization
- **EXTA-04**: Turnout vs concentration scatterplot

## Out of Scope

| Feature | Reason |
|---------|--------|
| Predictive behavioral economics | Not needed for validation — replay is counterfactual, not behavioral |
| On-chain deployment / gas modeling | Simulation only — gas is a separate engineering concern |
| Full delegate strategy modeling | Future extension — adds behavioral assumptions with no ground truth |
| Agent-based strategic voter modeling | Explodes complexity; overclaims beyond replay scope |
| Real-time / streaming simulation | Premature — adds web3.py/RPC infra with zero validation benefit |
| Interactive Streamlit/Dash dashboard | Static publication figures are the deliverable |
| Full Shapley value computation | O(2^n) infeasible at realistic voter counts; Nakamoto is sufficient |
| Voting-Bloc Entropy (VBE) | Research-level; requires voter clustering — defer to post-publication |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 3 | Complete |
| DATA-02 | Phase 3 | Complete |
| DATA-03 | Phase 3 | Complete |
| DATA-04 | Phase 3 | Complete |
| DATA-05 | Phase 3 | Complete |
| DATA-06 | Phase 3 | Complete |
| DATA-07 | Phase 3 | Complete |
| DATA-08 | Phase 3 | Complete |
| DATA-09 | Phase 3 | Complete |
| WGHT-01 | Phase 3 | Complete |
| WGHT-02 | Phase 3 | Complete |
| WGHT-03 | Phase 3 | Complete |
| WGHT-04 | Phase 3 | Complete |
| SIM-01 | Phase 4 | Pending |
| SIM-02 | Phase 4 | Complete |
| SIM-03 | Phase 4 | Complete |
| SIM-04 | Phase 4 | Complete |
| SIM-05 | Phase 4 | Complete |
| SIM-06 | Phase 4 | Complete |
| SIM-07 | Phase 4 | Complete |
| SIM-08 | Phase 4 | Pending |
| METR-01 | Phase 5 | Pending |
| METR-02 | Phase 5 | Pending |
| METR-03 | Phase 5 | Pending |
| METR-04 | Phase 5 | Pending |
| METR-05 | Phase 5 | Pending |
| METR-06 | Phase 5 | Pending |
| METR-07 | Phase 5 | Pending |
| METR-08 | Phase 5 | Pending |
| METR-09 | Phase 5 | Pending |
| METR-10 | Phase 5 | Pending |
| PLOT-01 | Phase 6 | Pending |
| PLOT-02 | Phase 6 | Pending |
| PLOT-03 | Phase 6 | Pending |
| PLOT-04 | Phase 6 | Pending |
| PLOT-05 | Phase 6 | Pending |
| PLOT-06 | Phase 6 | Pending |
| PLOT-07 | Phase 6 | Pending |
| PLOT-08 | Phase 6 | Pending |
| PLOT-09 | Phase 6 | Pending |
| PLOT-10 | Phase 6 | Pending |
| PLOT-11 | Phase 6 | Pending |
| PLOT-12 | Phase 6 | Pending |
| PIPE-01 | Phase 7 | Pending |
| PIPE-02 | Phase 7 | Pending |
| PIPE-03 | Phase 7 | Pending |

**Coverage:**
- v2.0 requirements: 46 total
- Mapped to phases: 46
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after roadmap creation*
