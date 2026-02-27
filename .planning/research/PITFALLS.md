# Pitfalls Research

**Domain:** cadCAD governance simulation + backtesting pipeline (commitment-weighted voting)
**Researched:** 2026-02-27
**Confidence:** HIGH (cadCAD specifics verified via official docs/issues; domain patterns from DAO research literature)

---

## Critical Pitfalls

### Pitfall 1: cadCAD State Mutation — Shared Mutable Objects Across Timesteps

**What goes wrong:**
cadCAD passes `previous_state` as a dict to every SUF and policy. If your state contains mutable Python objects — dicts, lists, sets, dataclasses — and you mutate them in-place inside a SUF instead of returning new copies, those mutations bleed into the next timestep. The existing `State` dataclass (in `state.py`) uses dicts for `balances`, `locks`, `initiatives`, `accepted_initiatives` (a `set`), and lists for `reward_history`. Any SUF that calls `.update()`, `.append()`, or `|=` on these without copying first silently corrupts state history.

**Why it happens:**
cadCAD intentionally does not deep-copy state on every timestep for performance reasons — it explicitly leaves copy discipline to the developer. The framework allows mutation of state history; it only blocks direct assignment to the current state object. The `get_state_obj()` helper in `base.py` re-constructs `State` from dicts on each SUF call, but the underlying dicts in `previous_state` are the same dict references that cadCAD holds. When two PSUBs run in the same timestep and PSUB 1 mutates a nested dict, PSUB 2 sees the mutated version even though it is reading `previous_state`.

**How to avoid:**
In every SUF that touches a mutable state variable, return a **new** object:
```python
# WRONG — mutates in place
def s_apply_actions(params, substep, history, prev_state, policy_input):
    balances = prev_state['balances']       # same dict reference
    balances['0x01'] += 100                 # corrupts shared state
    return ('balances', balances)

# CORRECT — return a copy
def s_apply_actions(params, substep, history, prev_state, policy_input):
    balances = dict(prev_state['balances'])  # shallow copy is enough for flat dicts
    balances['0x01'] += 100
    return ('balances', balances)
```
For nested structures (dict of dicts), use `{k: dict(v) for k, v in prev_state['initiatives'].items()}`. Reserve `copy.deepcopy()` only for deeply-nested objects — it is expensive at scale.

**Warning signs:**
- Metrics computed at timestep T differ when you re-run the same seed
- `accepted_initiatives` set grows faster than proposals finalized
- `reward_history` list length is unbounded and grows super-linearly
- Running with `N=2` Monte Carlo runs produces different results than `N=1`

**Phase to address:**
Phase implementing cadCAD simulation core (event replay SUFs). Add a test asserting that `prev_state['balances'] is not result_state['balances']` (reference inequality) on every SUF return.

---

### Pitfall 2: cadCAD Timestep Off-by-One Error in Early PSUBs

**What goes wrong:**
On cadCAD 0.5.x, the `timestep` state variable inside PSUB at substep=1 returns the *previous* timestep value (0 at initialization, not 1). The existing `model.py` uses a custom `current_epoch` state variable updated by `s_update_current_epoch` in the first PSUB. If any later PSUB reads `current_epoch` from `previous_state` expecting it to already be incremented, it reads the pre-increment value — producing lock expiry calculations one epoch too early.

**Why it happens:**
cadCAD evaluates state variables as they existed *before* the substep executes. At substep=1, `previous_state['current_epoch']` is still the epoch from the end of the prior timestep. The `timestep` variable in cadCAD's output is also subject to this: at the first substep of timestep 1 it reports 0. This is a documented open issue (#250 on cadCAD GitHub) with no framework fix — it requires a developer workaround.

**How to avoid:**
Use a helper function that computes current epoch from cadCAD's internal `timestep` counter rather than reading it from state. Alternatively, always pass `current_epoch` explicitly through policy output so SUFs that need the incremented value get it from `policy_input`, not `previous_state`:
```python
# In p_advance_time policy:
def p_advance_time(params, substep, history, prev_state):
    return {'next_epoch': prev_state['current_epoch'] + 1}

# In s_update_initiative_aggregate_weights SUF:
# Read epoch from policy_input if available, not from previous_state
epoch = policy_input.get('next_epoch', prev_state['current_epoch'])
```

**Warning signs:**
- Lock positions expiring one epoch earlier than their `expiry_epoch` field indicates
- Initiative acceptance threshold reached at epoch N-1 but logged as epoch N
- Sensitivity to PSUB ordering: reordering blocks changes metric outputs

**Phase to address:**
Phase implementing cadCAD simulation core. Write a test that runs 10 timesteps and asserts `current_epoch` in the final state equals exactly 10 (not 9 or 11).

---

### Pitfall 3: cadCAD Experiment Config — Global State Leaking Between Runs

**What goes wrong:**
When cadCAD runs multiple parameter sweep combinations (N>1 Monte Carlo runs, or M with multiple parameter lists), the `Configuration` object re-uses the same Python objects unless explicitly re-instantiated. The existing `model.py` constructs `initial_state` once outside `run_simulation()` and passes it into `Configuration`. If that dict contains mutable objects that cadCAD does not copy (sets, dicts of dataclasses), run 2 starts from the mutated state of run 1 rather than the intended initial state. This is particularly dangerous for `accepted_initiatives` (a set) and `reward_history` (a list) which grow monotonically.

**Why it happens:**
cadCAD's `Executor` does not deep-copy `initial_state` per run. The `generate_initial_state()` call in `state.py` returns a dict via `initial_state_obj.__dict__()`, which itself copies the objects — but only at construction time. If `run_simulation()` is called in a loop (e.g., for a parameter sweep), the same initial dict is reused unless regenerated each call.

**How to avoid:**
Call `generate_initial_state()` inside the loop body, not outside it. Use `copy.deepcopy(initial_state)` as a guard inside `run_simulation()` before passing to `Configuration`:
```python
import copy

def run_simulation(initial_state, num_epochs=None):
    safe_initial = copy.deepcopy(initial_state)   # always copy
    config = Configuration(initial_state=safe_initial, ...)
```
Also, confirm that `accepted_initiatives` is serialized as a list (not a set) in the state dict — Python sets are mutable and not safely shareable. The `__dict__()` method in `state.py` correctly makes copies of collections, but this is defeated if the same object is passed to multiple `Configuration` instantiations.

**Warning signs:**
- Run 2 of a parameter sweep starts with non-zero `accepted_initiatives`
- Gini coefficient for run 2 is lower than run 1 on identical parameters
- Increasing N Monte Carlo runs changes the mean metric value (it should not)

**Phase to address:**
Phase implementing parameter sweep support. Add an assertion that initial state for each run/sweep has `len(accepted_initiatives) == 0` and `len(reward_history) == 0`.

---

### Pitfall 4: Synthetic Data Distribution Mismatch — Uniform Token Allocation vs Real Power Law

**What goes wrong:**
The current `allocate_tokens()` function distributes tokens roughly uniformly or with `randomize=True` using uniform random sampling. Real DAO token distributions follow a heavy-tailed Pareto/power-law distribution: empirically, 1-10% of addresses hold 60-90% of tokens. If synthetic balances are uniform, the Gini coefficient of the *baseline* (legacy) scenario will be artificially low (~0.3-0.5), making the Signals weighting appear more impactful than it is. When swapped to real data, metrics will shift dramatically, invalidating conclusions.

**Why it happens:**
Uniform distribution is the easiest to implement and "feels fair." Research on real DAOs (Tally, Uniswap, Compound) consistently shows voter participation of under 1%, with top 5 addresses controlling >40% of votes. Using uniform synthetic data produces a fundamentally different governance dynamics.

**How to avoid:**
Generate token balances from a Pareto distribution calibrated to real DAO data:
```python
import numpy as np
# Zipf/Pareto: shape parameter ~1.5 matches empirical DAO distributions
alpha = 1.5
raw = np.random.pareto(alpha, num_users) + 1
balances = (raw / raw.sum() * circulating_supply).astype(int)
```
Also model realistic voting participation: 0.5-5% of token holders vote on any given proposal, concentrated in top holders. The `prob_support_initiative` parameter in the current model should be made heterogeneous — proportional to balance — not uniform.

**Warning signs:**
- Gini coefficient of initial balances is below 0.5 (real DAOs are 0.7-0.95)
- All users have similar voting weight in simulated proposals
- ENP metric consistently > 3 in baseline (real DAOs often < 2)
- Parameter sweeps show linear scaling between lock duration and outcome flips (real: nonlinear due to whale concentration)

**Phase to address:**
Phase implementing synthetic data generation. Validate generated distribution against empirical DAO data (Uniswap, Compound governance snapshots available via Tally API or Dune Analytics).

---

### Pitfall 5: Parameter Sweep Combinatorial Explosion — cadCAD M Parameter Constraint

**What goes wrong:**
cadCAD's `config_sim()` M parameter has a documented constraint: parameter value lists can have **at most 2 distinct lengths**. Attempting to sweep `lock_curve_shape` (3 values) × `decay_rate` (3 values) × `acceptance_threshold` (2 values) simultaneously will violate this constraint and produce incorrect or truncated results. Even within the 2-length limit, a 5-parameter sweep with lists of lengths [1,1,2,1,2] generates 2 combinations — but a 6-parameter sweep with [2,2,2,1,1,1] also generates only 2 (not 8), which surprises users expecting a full factorial design.

**Why it happens:**
cadCAD's sweep model is not a full factorial grid search. It zips parameter lists element-wise (like Python's `zip()`) rather than computing the Cartesian product. Users from scikit-learn or R backgrounds expect factorial behavior. The documentation states "params values require up to a maximum of 2 distinct lengths" but this is easy to miss.

**How to avoid:**
For full factorial sweeps, build the Cartesian product manually and run multiple `Configuration` objects, or use radCAD which supports arbitrary parameter grids more cleanly:
```python
from itertools import product
import pandas as pd

sweep_params = {
    'lock_curve_shape': [0.5, 1.0, 2.0],
    'decay_rate': [0.999, 0.9995, 0.9999],
    'acceptance_threshold': [50000, 100000],
}
all_combos = list(product(*sweep_params.values()))
# Run one cadCAD Config per combo, collect results, concat DataFrames
```
Cap total sweep combinations at 50-100 for interactive analysis; use batch/background jobs for larger sweeps.

**Warning signs:**
- Parameter sweep DataFrame has fewer rows than expected (`T × N × expected_combos`)
- Changing order of M keys changes which combinations are run
- `subset` column in results DataFrame has fewer unique values than combinations specified
- Metrics from "all combinations" are actually identical (same parameters used twice)

**Phase to address:**
Phase implementing parameter sweep support. Always log the number of expected vs actual simulation runs at the start of execution, and assert they match.

---

## Moderate Pitfalls

### Pitfall 6: Gini Coefficient — Division by Zero and Single-Voter Edge Cases

**What goes wrong:**
The standard Gini formula `G = sum(|xi - xj|) / (2n^2 * mean(x))` divides by `mean(x)`. When a proposal has zero votes cast (zero-voter proposals are valid in Governor-style governance), `mean(x) == 0` produces NaN or ZeroDivisionError. With a single voter (`n=1`), Gini is undefined (no inequality among one entity). When all voters cast equal weight, Gini=0 but the formula's numerator can accumulate floating point errors.

**How to avoid:**
Always guard Gini computation:
```python
def gini(weights: np.ndarray) -> float:
    if len(weights) == 0 or weights.sum() == 0:
        return np.nan   # undefined, not zero
    if len(weights) == 1:
        return 0.0      # single actor = perfect "equality" by convention
    weights = np.sort(weights)
    n = len(weights)
    index = np.arange(1, n + 1)
    return (2 * (index * weights).sum()) / (n * weights.sum()) - (n + 1) / n
```
Return `np.nan` for undefined cases and filter NaN in aggregation — do not substitute 0 (zero Gini incorrectly implies perfect equality rather than "undefined").

**Warning signs:**
- Gini values exactly 0.0 for proposals with 1-2 voters (likely incorrect)
- NaN propagation causing entire metric series to collapse
- Aggregated Gini using `.mean()` silently dropping NaN rows

**Phase to address:**
Phase implementing metrics computation (Gini, ENP). Test against edge-case inputs: empty array, single element, all-equal values, one dominant voter.

---

### Pitfall 7: ENP (Effective Number of Parties) — Herfindahl Bias at Extremes

**What goes wrong:**
ENP = 1 / Σ(pi²) where pi is the vote share of voter i. With a single dominant voter holding >90% of votes, ENP approaches 1.0 but never reaches it exactly, which can be misleading — a governance outcome determined by one whale reads as ENP=1.11 rather than ENP=1. More critically, when normalizing vote shares, floating point precision can produce Σ(pi²) slightly above or below 1.0 for the single-voter case, producing ENP slightly below 1.0 — which is theoretically impossible.

**How to avoid:**
Normalize vote shares explicitly before computing ENP, and clamp to valid range:
```python
def enp(weights: np.ndarray) -> float:
    total = weights.sum()
    if total == 0 or len(weights) == 0:
        return np.nan
    shares = weights / total
    return float(np.clip(1.0 / (shares ** 2).sum(), 1.0, len(weights)))
```
The ENP valid range is [1, n_voters]. Clamping catches floating-point artifacts. Document in the codebase that ENP ~= 1 means one entity controls the outcome.

**Warning signs:**
- ENP values below 1.0 appearing in results
- ENP time series jumping non-monotonically when one large voter joins mid-proposal
- ENP for a proposal with 1 voter returning NaN instead of 1.0

**Phase to address:**
Phase implementing metrics computation. Property-based test: for any weight vector, `1.0 <= ENP(weights) <= len(weights)`.

---

### Pitfall 8: Lock-Duration Inference Bias — Survivorship Bias in Observed Durations

**What goes wrong:**
When inferring "typical" lock durations from observed on-chain data (or from simulated results mid-run), only *active* locks are observable — expired locks have been consumed. This creates survivorship bias: shorter locks have already expired and are invisible, so the mean observed lock duration is always higher than the true distribution mean. If you calibrate synthetic lock duration parameters by fitting to observed active locks, you over-estimate how long voters commit. This biases Signals weight calculations upward, making the mechanism appear more effective than it is with realistic short-term committers.

**How to avoid:**
Track expired locks in the simulation state (the current model has `expired_initiatives` but not `expired_locks`). When computing lock duration statistics, use the full cohort at a consistent snapshot time (e.g., all locks opened in epoch 0-100, measured at epoch 50) or use survival analysis (Kaplan-Meier) to account for right-censoring. For synthetic data generation, sample lock durations from the *full* distribution (not the observed active-at-time-T distribution).

**Warning signs:**
- Mean lock duration increases as simulation progresses (short locks expire, biasing upward)
- Signals weight advantage grows over simulation time even with stable parameters
- Calibrated parameters produce unrealistically high lock durations vs historical DAO data

**Phase to address:**
Phase implementing synthetic data generation and metrics computation. Add lock duration distribution tracking to the results DataFrame, measuring full cohort vs snapshot distributions.

---

### Pitfall 9: Matplotlib Publication-Quality — Figure State Pollution and Non-Reproducible Outputs

**What goes wrong:**
Matplotlib uses global figure state (`plt.figure()`, `plt.gca()`). When multiple plots are generated in sequence (e.g., a full metrics suite), leftover state from earlier figures bleeds into later ones: axis limits carry over, color cycle resets unexpectedly, `rcParams` set by seaborn are not cleared, and `plt.tight_layout()` can silently clip labels. Running the plotting pipeline twice in the same Python session may produce different outputs from the same data.

**Why it happens:**
`plt.show()` in interactive mode does not close the figure. `plt.clf()` clears content but not figure-level properties. Seaborn's `set_theme()` modifies global `rcParams` permanently for the session.

**How to avoid:**
Use the object-oriented matplotlib API exclusively. Never call `plt.figure()` or `plt.gca()` in production plotting code:
```python
import matplotlib
matplotlib.use('Agg')          # non-interactive backend for batch runs
import matplotlib.pyplot as plt
import matplotlib.style as mstyle

# At module level, set rcParams once:
plt.rcParams.update({
    'figure.dpi': 300,
    'figure.figsize': (3.5, 2.5),  # single-column journal width
    'font.size': 9,
    'axes.labelsize': 9,
    'xtick.labelsize': 8,
    'ytick.labelsize': 8,
    'font.family': 'sans-serif',
    'text.usetex': False,          # set True only if LaTeX is confirmed installed
    'savefig.bbox': 'tight',
    'savefig.dpi': 300,
})

def plot_metric(data, output_path):
    fig, ax = plt.subplots(1, 1)   # always explicit axes
    ax.plot(data)
    fig.savefig(output_path, bbox_inches='tight')
    plt.close(fig)                  # ALWAYS close — prevents memory leak + state pollution
```
For publication, export PDF (vector) not PNG (raster) — PDF survives infinite zoom and journal submission requirements. Use `300 dpi` minimum for any PNG fallback.

**Warning signs:**
- Plot from second pipeline run looks different from first (same data, same code)
- Labels clipped at figure boundary
- Seaborn and matplotlib figures in the same session have inconsistent font sizes
- `MemoryError` after generating 50+ figures (unclosed figures accumulate in memory)

**Phase to address:**
Phase implementing plotting suite. Establish `matplotlib.use('Agg')` and global `rcParams` in a single `plotting_config.py` module imported by all plot functions. Test by running plotting pipeline twice and asserting file checksums are identical.

---

### Pitfall 10: Event-Replay vs ABM — Treating Replayed Votes as Independent Agent Decisions

**What goes wrong:**
Event-replay (deterministically re-running historical or synthetic events) and ABM (agents deciding based on state at each timestep) have fundamentally different causal structures. In a cadCAD event-replay, `VOTE_CAST` events are injected from the event log — agents do not "decide" anything. If you compute counterfactual comparisons (legacy vs Signals weighting) by re-running the same events with different weight functions, you are computing `f_signals(vote) vs f_legacy(vote)` — a *function comparison* not a *behavioral simulation*. The result shows what the outcome *would have been* under the different weighting function, holding behavior constant. This is valid for published claims like "under Signals weighting, proposal X would have passed/failed differently" but invalid for claims like "Signals weighting causes agents to change their voting behavior."

**Why it happens:**
The distinction is subtle. cadCAD supports both modes; the project description says "event-based cadCAD replay" which is the correct framing — but if any metric is described as measuring "incentive effects" or "behavior change," it overclaims beyond what replay can show.

**How to avoid:**
Clearly distinguish in documentation and code between:
1. **Replay mode**: events are fixed; only weight function changes. Valid claim: "Proposal X would have had a different tally."
2. **ABM mode**: agents decide based on current Signals weight incentives. Valid claim: "Agents who anticipate Signals rewards commit longer."
For v2.0, use replay mode and be explicit about its limitations in output comments and plots. Label plots as "counterfactual tally" not "simulated participation."

**Warning signs:**
- Metrics labeled "participation rate" when event stream is fixed
- Claims that Signals "increased participation" when participation events are pre-determined
- Confusion about why running N=10 Monte Carlo on an event-replay gives different results (it should not if the event stream is deterministic)

**Phase to address:**
Phase design (before any implementation). Establish in docstrings and comments the distinction between replay and ABM. Monte Carlo runs should only vary *parameters* (lock curves, decay), not *events*, in replay mode.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using uniform token distribution | Simpler initial state, easy to reason about | Gini/ENP metrics unrepresentative of real DAOs; results don't transfer to real data | Never for published results; acceptable for integration tests only |
| Shallow `dict(prev_state['x'])` copies everywhere | Avoids deep copy overhead | Misses nested mutable objects (dict-of-dataclasses); silent corruption at scale | Acceptable *only* for flat string→scalar dicts (e.g., `balances`) |
| Single-shot `generate_initial_state()` outside sweep loop | Less code | Run 2+ contaminated by run 1's terminal state | Never in parameter sweeps; only for single-run smoke tests |
| `plt.show()` in plotting functions | Interactive development convenience | Non-reproducible batch runs; memory leaks; state pollution | Never in production plotting pipeline |
| Sampling lock durations uniformly between `min_dur` and `max_dur` | Trivial implementation | Over-represents max durations; Signals weighting looks stronger than reality | Acceptable as placeholder; must be replaced before publishing conclusions |
| Hardcoding `acceptance_threshold` in `model.py` | Quick initial implementation | Parameter cannot be swept without touching model config | Never — always load from `system_params` dict |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| cadCAD `config_sim()` M parameter | Providing 3+ distinct list lengths expecting factorial sweep | Use at most 2 distinct lengths, or build Cartesian product externally and run N `Configuration` objects |
| cadCAD `Executor.execute()` return value | Ignoring `tensor_field` and `sessions` return values, assuming only `raw_result` matters | Log `sessions` count to verify expected number of runs completed; check `tensor_field` shape matches `T × N × subsets` |
| cadCAD + pandas DataFrame | Calling `pd.DataFrame(raw_result)` directly with nested objects (sets, dataclasses) | Pre-process: extract scalar fields, convert sets to sorted lists, convert dataclass instances to dicts before constructing DataFrame |
| matplotlib + seaborn in same session | `import seaborn as sns; sns.set_theme()` pollutes rcParams for matplotlib plots | Set `rcParams` after `sns.set_theme()`, or use seaborn with explicit `axes_style` context managers |
| Governor-schema synthetic data | Generating `VOTE_CAST` events without a preceding `PROPOSAL_CREATED` with matching `proposal_id` | Validate event stream referential integrity before feeding to simulation: every `VOTE_CAST.proposal_id` must exist in `PROPOSAL_CREATED` events |
| NumPy random seeding in cadCAD | Not seeding `np.random` and `random` per run before calling `run_simulation()` | Set `np.random.seed(run_id)` and `random.seed(run_id)` at the start of each sweep combination to ensure reproducibility |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `copy.deepcopy()` on full state every timestep | Simulation takes 10x longer than expected; profiler shows `deepcopy` dominating | Only deep-copy mutable nested structures; use shallow `dict()` copy for flat dicts | At ~500 voters with 1000 proposals, deepcopy overhead exceeds model computation |
| Storing full state history in `reward_history` list | Memory usage grows linearly with timesteps; OOM on large sweeps | Stream reward history to disk (parquet) or store only summary statistics in state | Breaks around T=10,000 with 1000 users |
| `previous_state['balances'].keys()` inside policy to get all users | Works fine, but list conversion on every timestep | Pre-compute user list once; pass as parameter | Performance cliff above 10,000 users |
| DataFrame with nested dicts/sets in cells | `df.to_parquet()` fails; slow `df.apply(lambda)` chains | Flatten all nested structures to scalar columns before writing results | On any non-trivial analysis of large sweep results |
| Running full parameter sweep interactively | Jupyter kernel OOM; incomplete results saved | Use `argparse` CLI with `--dry-run` to print combo count; run sweeps as background processes writing to parquet | Sweeps with >20 parameter combinations on T=744 timesteps |

---

## "Looks Done But Isn't" Checklist

- [ ] **cadCAD state copies:** Every SUF that modifies a collection returns a new copy — verify by asserting `id(result) != id(prev_state['key'])` in tests
- [ ] **Initial state purity per run:** `accepted_initiatives`, `expired_initiatives`, `reward_history` are empty at the start of each Monte Carlo run — verify by logging lengths before Executor runs
- [ ] **Gini/ENP edge case handling:** Functions return `np.nan` (not 0) for zero-vote proposals — verify with unit tests on empty and single-element inputs
- [ ] **Synthetic balance distribution:** `gini(initial_balances) > 0.65` — verify against known DAO benchmarks (Compound Gini ≈ 0.85, Uniswap ≈ 0.90)
- [ ] **Event stream referential integrity:** Every `VOTE_CAST` event references a valid `proposal_id` — verify with a schema validation step before simulation
- [ ] **Parameter sweep completeness:** `len(results_df['subset'].unique()) == expected_combo_count` — verify at end of sweep execution
- [ ] **Matplotlib figures closed:** No `plt.figure()` calls without corresponding `plt.close(fig)` — verify with `plt.get_fignums()` count being zero after plotting pipeline
- [ ] **Replay vs ABM framing:** All plot titles and metrics docstrings use "counterfactual" or "replay" language, not "simulated behavior" — verify by code review
- [ ] **Lock duration distribution:** `np.mean(lock_durations)` for synthetic data matches expected distribution mean (not inflated by survivorship) — verify against expected Pareto moment
- [ ] **Deterministic replays:** Two runs with identical seed and event stream produce bit-identical results DataFrames — verify by checksum comparison

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| State mutation corruption discovered in results | HIGH | Re-audit all SUFs for in-place mutation; add reference-inequality tests; re-run all simulations from scratch |
| Timestep off-by-one producing wrong expiry epochs | MEDIUM | Fix helper function; add regression test for epoch accounting; re-run simulations (results change numerically but structure is intact) |
| Parameter sweep global state leak (run contamination) | MEDIUM | Add deepcopy guard in `run_simulation()`; add initial-state-purity assertion; re-run sweeps |
| Uniform token distribution in published results | HIGH | Replace `allocate_tokens()` with Pareto sampler; re-generate all synthetic datasets; re-run all simulations; update all plots and conclusions |
| Matplotlib figure state pollution in plots | LOW | Add `plt.close(fig)` to all plot functions; establish `rcParams` config module; regenerate plots only |
| ENP/Gini NaN propagation collapsing metric series | LOW | Fix edge-case guards in metric functions; re-compute metrics from saved raw results (no simulation re-run needed) |
| Overclaiming behavioral effects in replay mode | MEDIUM | Update documentation, plot labels, and conclusions — no simulation re-run needed, but conclusions need re-framing |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| cadCAD state mutation (Pitfall 1) | cadCAD simulation core implementation | Unit test: reference inequality on every SUF return; integration test: N=2 runs give identical results |
| Timestep off-by-one (Pitfall 2) | cadCAD simulation core implementation | Test: `final_epoch == T` after T timesteps |
| Global state leaking between runs (Pitfall 3) | Parameter sweep implementation | Test: run 2 starts with empty `accepted_initiatives` |
| Synthetic distribution mismatch (Pitfall 4) | Synthetic data generation phase | Test: `gini(initial_balances) > 0.65` |
| Parameter sweep combinatorial explosion (Pitfall 5) | Parameter sweep implementation | Test: log expected vs actual combination count at sweep start |
| Gini edge cases (Pitfall 6) | Metrics computation phase | Unit test: zero-vote, single-vote, all-equal inputs |
| ENP edge cases (Pitfall 7) | Metrics computation phase | Property test: `1.0 <= ENP <= n_voters` |
| Lock-duration survivorship bias (Pitfall 8) | Synthetic data generation + metrics phase | Track full lock cohort at snapshot; test mean vs survivor mean |
| Matplotlib figure pollution (Pitfall 9) | Plotting suite implementation | Run plot pipeline twice; assert output file checksums match |
| Event-replay vs ABM overclaiming (Pitfall 10) | Design phase (before implementation) | Code review: metric docstrings use "counterfactual" framing |

---

## Sources

- cadCAD GitHub Issue #250 — Timestep off-by-one in first PSUB: https://github.com/cadCAD-org/cadCAD/issues/250
- cadCAD GitHub Issue #195 — Multi-config truncated results bug: https://github.com/cadCAD-org/cadCAD/issues/195
- cadCAD Parameter Sweep documentation: https://github.com/cadCAD-org/cadCAD/blob/master/documentation/System_Model_Parameter_Sweep.md
- cadCAD Simulation Execution documentation: https://github.com/cadCAD-org/cadCAD/blob/master/documentation/Simulation_Execution.md
- radCAD (cadCAD successor with improved performance): https://github.com/BenSchZA/radCAD
- DAO voting power analysis (voting concentration empirics): https://www.sciencedirect.com/science/article/pii/S2096720924000216
- DAO Large Scale Analysis (Gini, participation rates): https://arxiv.org/html/2410.13095v1
- DAO decentralization metrics (Nakamoto, Gini): https://www.cs.cornell.edu/~babel/papers/dao-vbe-dd.pdf
- ENP (Laakso-Taagepera 1979): https://journals.sagepub.com/doi/10.1177/001041407901200101
- ENP single-party limitation: https://en.wikipedia.org/wiki/Effective_number_of_parties
- Matplotlib publication-quality tips: https://medium.com/sissa-mathlab/tips-and-tricks-to-create-publication-ready-figures-with-matplotlib-5382b480232b
- matplotlib rcParams customization: https://matplotlib.org/stable/users/explain/customizing.html
- Publication-ready matplotlib workflow: https://www.dmcdougall.co.uk/publication-ready-the-first-time-beautiful-reproducible-plots-with-matplotlib
- Governor Bravo event schema: https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoDelegate.sol
- Backtesting lookahead bias: https://timkimutai.medium.com/how-i-built-an-event-driven-backtesting-engine-in-python-25179a80cde0

---
*Pitfalls research for: cadCAD governance simulation + backtesting pipeline (Signals Protocol)*
*Researched: 2026-02-27*
