# Signals Simulation Thesis Guide

## Executive Summary

v1.0 through v3.0 (Phases 1-12) built the complete simulation pipeline for
commitment-weighted governance research. This guide maps proposed Sims C through
G to the infrastructure that now exists, identifying what is ready to run today
vs. what requires code changes before each simulation can execute.

**Bottom line:** Sim F can run TODAY with a TOML config and no code changes.
Sims C, G need small factory/sweep changes. Sims D and E require new code.

---

## Infrastructure Inventory

### Data Generation Layer

**Module:** `apps/simulations/src/backtesting/data/factory.py`

#### `generate_scenario()` — Full Parameter Signature

```python
def generate_scenario(
    n_voters: int = 200,
    n_proposals: int = 30,
    total_supply: float = 1_000_000.0,
    avg_participation_rate: float = 0.10,
    stake_profile: StakeProfile = 'pareto',
    lock_profile: LockProfile = 'independent',
    pareto_alpha: float = 0.7,
    l_max_days: float = 365.0,
    proposal_window_blocks: int = 50400,
    seed: int | None = None,
    budget_enabled: bool = True,
    allocation_strategy: AllocationStrategy = 'uniform_fraction',
    blocks_per_day: int = 7200,
    curve_type: ScenarioCurveType = 'sqrt',
    mc_dist: AllocationDistribution | None = None,
    vote_timing: VoteTimingConfig | None = None,
) -> list[GovernorEvent]
```

#### `StakeProfile` Options

```python
StakeProfile = Literal['pareto', 'uniform', 'bimodal']
```

| Profile   | What It Models                                                  |
|-----------|----------------------------------------------------------------|
| `pareto`  | Power-law distribution; pareto_alpha=0.7 gives realistic inequality (Gini ~0.65+) |
| `uniform` | All voters hold equal stake — flat distribution                  |
| `bimodal` | 10% of voters hold 90% of supply (top 10% get 9x weight). Models "whale + retail" |

#### `LockProfile` Options

```python
LockProfile = Literal['correlated', 'inverse_correlated', 'independent', 'bimodal']
```

| Profile              | What It Models                                                 |
|----------------------|----------------------------------------------------------------|
| `correlated`         | Higher stake -> longer lock. Long-term aligned whales.          |
| `inverse_correlated` | Higher stake -> shorter lock. Whales seek liquidity.            |
| `independent`        | Uniform random lock durations [0, l_max_days]. No correlation.  |
| `bimodal`            | 30% short-term (0-30 days), 70% long-term (180-365 days).       |

#### `VoteTimingConfig` Dataclass

```python
@dataclass
class VoteTimingConfig:
    early: float = 0.30   # fraction of voters who vote in the first 20% of window
    mid: float = 0.40     # fraction of voters who vote in the 30-70% range
    # late_frac = 1.0 - early - mid (implicitly, votes in the 80-100% range)
```

**Constraint:** `early >= 0`, `mid >= 0`, `early + mid <= 1.0`

#### `ScenarioCurveType` — IMPORTANT LIMITATION

```python
ScenarioCurveType = Literal['sqrt', 'log', 'linear']
_VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear')
```

**The factory validates against this tuple and raises `ValueError` if 'exp' is passed.**
This is the primary gap for Sim C.

---

### Weighting Layer

**Module:** `apps/simulations/src/backtesting/weighting/signals.py`

#### `CurveType` — Full Set (Includes 'exp')

```python
CurveType = Literal['sqrt', 'linear', 'log', 'exp']
```

#### `lock_curve()` Function

```python
def lock_curve(
    lock_duration_days: float,
    curve_type: CurveType = 'sqrt',
    l_max_days: float = 365.0,
    floor: float = 0.1,       # <-- EXISTS but NOT exposed through generate_scenario()
) -> float
```

**Curve formulas (normalized so f(0) = floor, f(l_max) = 1.0):**

| Curve    | Formula                                                   | Shape             |
|----------|-----------------------------------------------------------|-------------------|
| `sqrt`   | `floor + (1-floor) * sqrt(L / L_max)`                    | Diminishing returns |
| `linear` | `floor + (1-floor) * (L / L_max)`                        | Proportional       |
| `log`    | `floor + (1-floor) * log1p(L) / log1p(L_max)`            | Fast early gains   |
| `exp`    | `floor + (1-floor) * (1-exp(-alpha*L)) / (1-exp(-alpha*L_max))` | Slow then fast |

**exp curve details:** alpha = 0.5/30 per day. Approximately 78% weight at 3 months.

#### Critical Mismatch: Weighting vs. Factory

| Module                  | Supports 'exp' |
|-------------------------|---------------|
| `weighting/signals.py`  | YES            |
| `data/factory.py`       | NO (ValueError) |

The `floor` parameter defaults to 0.1 in `lock_curve()` but is **not exposed** through
`generate_scenario()`. The factory calls weighting functions internally with the
hardcoded default floor=0.1. Sweeping floor values requires factory surgery.

---

### Budget and Allocation Layer

**Module:** `apps/simulations/src/backtesting/data/budget.py`

#### `AllocationStrategy` Options

```python
AllocationStrategy = Literal['uniform_fraction', 'conviction_weighted', 'aggressive']
```

| Strategy              | Range    | Behavior                                                      |
|-----------------------|----------|--------------------------------------------------------------|
| `uniform_fraction`    | 15-45%   | Random fraction of available balance. No correlation with lock. |
| `conviction_weighted` | 15-70%   | Longer lock -> bigger commitment. base = 0.15 + 0.55 * (lock/max) |
| `aggressive`          | 60-100%  | Commit nearly all available balance per vote.                  |

#### `AllocationDistribution` Hierarchy (for MC Sampling)

```python
class AllocationDistribution(ABC):
    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray: ...
```

| Subclass              | Parameters           | Use Case                              |
|-----------------------|----------------------|---------------------------------------|
| `BetaDistribution`    | `a: float, b: float` | Bounded [0,1]; flexible shape via a,b |
| `UniformDistribution` | `low=0.15, high=0.45`| Simple uniform draw                   |
| `TruncnormDistribution`| `mean=0.35, std=0.15, clip_low=0.0, clip_high=1.0` | Bell-curve allocation |

When `mc_dist` is passed to `generate_scenario()`, the factory uses a two-RNG
split (SeedSequence.spawn(2)) to draw ONE allocation fraction for the entire
scenario, ensuring reproducibility across MC runs.

#### `VoterLedger` — Budget Constraint Mechanics

```python
@dataclass
class VoterLedger:
    total_stake: float
    locks: list[LockEntry]

    def available_balance(self, at_block: int) -> float:
        # total_stake minus sum of active locks at at_block
```

Tokens locked for one proposal are unavailable for concurrent proposals. A voter
with total_stake=1000 who committed 400 tokens to proposal A cannot commit
more than 600 to concurrent proposal B.

---

### Sweep Engine

**Module:** `apps/simulations/src/backtesting/sweep.py`

#### `SweepConfig` — Cartesian Axes

```python
@dataclass
class SweepConfig:
    curve_types: list[str]          # e.g., ['sqrt', 'log', 'linear']
    alphas: list[float]             # Pareto alpha values, mapped to pareto_alpha
    lock_profiles: list[dict]       # [{'short': 30, 'long': 365}] — 'long' -> l_max_days
    allocation_strategies: list[str] # e.g., ['uniform_fraction', 'conviction_weighted']
    max_workers: int                # REQUIRED — no auto-detection
    cell_timeout_seconds: int = 120
    base: dict = field(default_factory=dict)  # passthrough to generate_scenario
    mc_dists: list[AllocationDistribution] | None = None
    vote_timings: list[VoteTimingConfig] | None = None
```

The sweep grid is computed as the full cartesian product:
`curve_types x alphas x lock_profiles x allocation_strategies x mc_dists x vote_timings`

**n_voters is NOT a sweep axis.** It lives in `base` dict, not in the cartesian grid.

#### `SweepCell` — One Grid Point

```python
@dataclass
class SweepCell:
    cell_id: int
    curve_type: str
    alpha: float
    lock_profile: dict   # {'short': ..., 'long': ...}
    allocation_strategy: str
    mc_dist: AllocationDistribution | None = None
    vote_timing: VoteTimingConfig | None = None
```

#### `SweepResult` — Output

```python
@dataclass
class SweepResult:
    config: SweepConfig
    summary_df: pd.DataFrame   # one row per cell, all metric columns
    failed_cells: list[int]    # cell_ids that timed out or raised exceptions
    output_dir: str
```

#### TOML Configuration Format

```toml
[base]
n_voters = 200
seed = 42
stake_profile = "pareto"
n_proposals = 30

[sweep]
curve_types = ["sqrt", "log", "linear"]
alphas = [0.5, 0.7, 1.0]
max_workers = 4                  # REQUIRED
cell_timeout_seconds = 120       # optional

[[sweep.lock_profiles]]
short = 30
long = 365

[[sweep.allocation_strategies]]
# Simple list: allocation_strategies = ["uniform_fraction"]

[[sweep.vote_timings]]          # optional
early = 0.30
mid = 0.40

[[sweep.vote_timings]]
early = 0.80
mid = 0.10
```

#### Execution Model

- `run_sweep()` uses `ProcessPoolExecutor(max_workers=config.max_workers)`
- Each cell runs in a separate process — fully parallelized
- `as_completed()` with `fut.result(timeout=cell_timeout_seconds)` for timeout handling
- On failure: logs error, adds to `failed_cells`, inserts NaN row, continues sweep
- Auto-exports: `summary.csv` and `config.json` to timestamped output directory
- Memory management: `del raw, events, results_df; gc.collect()` after each cell

---

### Analysis Layer

**Module:** `apps/simulations/src/backtesting/analysis.py`

All 6 functions are pure: input is `results_df` from `build_results_dataframe()`.
No side effects. All return frozen dataclasses.

| Function               | ID      | Input                              | Output                  | What It Measures |
|------------------------|---------|------------------------------------|-------------------------|-----------------|
| `margin_class_breakdown` | ANAL-01 | results_df                        | `MarginClassBreakdown`  | Flipped proposals grouped by tight/moderate/decisive legacy margin |
| `address_influence`    | ANAL-02 | results_df, curve_type            | `AddressInfluence`      | Per-voter share under legacy, signals, median-lock counterfactual; delta shows who benefits from commitment |
| `timing_sensitivity`   | ANAL-03 | results_df, windows_df, curve_type, n_quantiles | `TimingSensitivity` | 2D pivot heatmap of weight_ratio (signals/legacy) by timing quantile x lock quantile |
| `voter_archetypes`     | ANAL-04 | results_df                        | `VoterArchetypes`       | Classifies voters into retail/medium/whale by total stake tertile |
| `influence_significance` | ANAL-05 | group_a, group_b (ndarray)       | `SignificanceResult`    | Mann-Whitney U test on two influence distributions |
| `bootstrap_ci`         | ANAL-06 | values (ndarray), statistic, confidence_level | `BootstrapCI` | Bootstrap confidence interval (percentile method, n_resamples=999) |

**Statistical tests available:**
- Mann-Whitney U (two-sided) — non-parametric, does not assume normality
- Bootstrap CI (scipy.stats.bootstrap) — percentile method

---

### Metrics Layer

**Module:** `apps/simulations/src/backtesting/metrics.py`

All 10 functions are pure. Input: `results_df`. Timing metrics also take `windows_df`.
NaN-for-degenerate-inputs convention: zero-sum/zero-weight returns NaN (not 0.0).

| Function                      | ID      | Returns                 | What It Measures |
|-------------------------------|---------|-------------------------|-----------------|
| `compute_flip_rate`           | METR-01 | `FlipRateResult`        | Fraction of proposals where legacy vs. signals outcome differs |
| `compute_gini`                | METR-02 | `GiniResult`            | Gini coefficient of voting power (legacy and signals, participating voters only) |
| `compute_participation_rate`  | METR-03 | `ParticipationResult`   | Per-proposal voter participation rate (unique voters / total unique voters) |
| `compute_enp`                 | METR-04 | `ENPResult`             | Effective Number of Parties = 1/sum(s_i^2), FOR/AGAINST only |
| `compute_nakamoto_coefficient`| METR-05 | `NakamotoResult`        | Min voters controlling >50% of total weight, per proposal |
| `compute_margin_shift`        | METR-06 | `MarginShiftResult`     | Per-proposal (signals_margin - legacy_margin); positive = more decisive |
| `compute_transition_matrix`   | METR-07 | `TransitionMatrix`      | 2x2 outcome matrix: PP/PF/FP/FF counts and proportions |
| `compute_late_vote_share`     | METR-08 | `LateVoteShareResult`   | Fraction of weight cast in final 1/3 of voting window, per proposal |
| `compute_lockin_timing`       | METR-09 | `LockinTimingResult`    | Fraction of window elapsed when outcome mathematically locked in |
| `compute_top_k_concentration` | METR-10 | `TopKConcentrationResult` | Top-k weight concentration for k in [1, 5, 10], per proposal |

---

### Report Layer

**Module:** `apps/simulations/src/backtesting/report.py`

#### `generate_sweep_report()` — Main Orchestrator

```python
def generate_sweep_report(
    sweep_result: SweepResult,
    *,
    best_n: int = 3,
    worst_n: int = 3,
    ranking_metric: str = 'flip_rate',
    row_axis: str = 'curve_type',
    col_axis: str = 'alpha',
) -> ReportResult
```

#### Output Structure

```
{output_dir}/
  sweep_results.csv       # all summary_df rows and columns (REPT-02)
  sweep_summary.json      # aggregated statistics, NaN-safe (REPT-03)
  composite.png           # 2x2 multi-panel figure: flip/gini/enp/margin_shift (REPT-05)
  heatmaps/
    flip_rate.png         # heatmap per metric in _METRIC_CMAPS (REPT-01, REPT-07)
    gini_legacy.png
    gini_signals.png
    participation_rate.png
    enp_legacy_mean.png
    enp_signals_mean.png
    nakamoto_legacy_mean.png
    nakamoto_signals_mean.png
    margin_shift_mean.png
  detail/
    best_01_cell_N.png    # bar chart: all metric values for top-N cells (REPT-06)
    best_02_cell_N.png
    best_03_cell_N.png
    worst_01_cell_N.png
    worst_02_cell_N.png
    worst_03_cell_N.png
  timing_sensitivity/     # reserved directory (populated by custom analysis scripts)
```

**Heatmaps:** Annotated 2D imshow, dpi=300, origin='lower', contrasting text color.
**Detail plots:** Orange bar charts for best/worst N cells by ranking_metric.
**Composite:** 2x2 subplot_mosaic with flip_rate, gini_legacy, enp_signals_mean, margin_shift_mean.
**JSON export:** NaN and numpy int64 types converted to Python-native (null-safe).

---

### Monte Carlo Runner

**Module:** `apps/simulations/src/backtesting/mc.py`

```python
def run_mc_samples(
    mc_dist: AllocationDistribution,
    n_samples: int = 50,
    base_seed: int | None = None,
    vote_timing: VoteTimingConfig | None = None,
    *,
    n_voters, n_proposals, total_supply, avg_participation_rate,
    stake_profile, lock_profile, pareto_alpha, l_max_days,
    proposal_window_blocks, budget_enabled, allocation_strategy,
    blocks_per_day, curve_type,
) -> MCResult
```

Uses `SeedSequence.spawn(n_samples)` for statistically independent RNG streams.
Each sample has a distinct child seed — no inter-sample correlation.
Returns `MCResult` with list of `MCSample(index, seed, alloc_frac, events)`.

---

## Proposed Simulations

### Sim C: Curve Sensitivity (PRIORITY 1)

**Research Question:** Which lock curve shape best amplifies small holders while
maintaining whale accountability?

**Sweep Design:**
- `curve_types`: [sqrt, linear, log, exp]
- `floors`: [0.0, 0.1, 0.3]
- Fixed: pareto stake, independent locks, n_voters=200

**Infrastructure Status:**

| Component             | Status  | Notes |
|-----------------------|---------|-------|
| Sweep engine          | READY   | Handles curve_types axis natively |
| Metrics + report      | READY   | All 10 metrics work for any curve |
| sqrt, linear, log     | READY   | Three of four curves work end-to-end |
| `exp` curve           | GAP     | Exists in `weighting/signals.py` but factory rejects it (`ValueError`) |
| `floor` sweep         | GAP     | `lock_curve(floor=...)` accepts the param but `generate_scenario()` does not expose it |
| `floors` sweep axis   | GAP     | Not in `SweepConfig` — no cartesian enumeration possible |

**Required Code Changes:**

1. **Add 'exp' to `ScenarioCurveType` in `factory.py`** (lines 23-24):
   ```python
   # Before:
   ScenarioCurveType = Literal['sqrt', 'log', 'linear']
   _VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear')
   # After:
   ScenarioCurveType = Literal['sqrt', 'log', 'linear', 'exp']
   _VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear', 'exp')
   ```
   Note: The factory passes `curve_type` to `run_backtest()` and `_run_cell()` which
   call `compute_signals_weight()`. Since `lock_curve()` already handles 'exp', this
   single change unlocks the exp curve end-to-end.

2. **Add `floor` param to `generate_scenario()`** and thread it through to all
   internal weighting calls. Currently the factory does not call `lock_curve()`
   directly — it passes `curve_type` to the runner which calls `compute_signals_weight()`.
   The floor would need to be threaded through `run_backtest()` and the runner layer.

3. **Add `floors` axis to `SweepConfig`** and enumerate in `_enumerate_cells()`:
   ```python
   floors: list[float] = field(default_factory=lambda: [0.1])
   ```
   Then include in `itertools.product(... floors ...)` and pass to `_run_cell()`.

**Expected TOML (after code changes):**

```toml
[base]
n_voters = 200
seed = 42
stake_profile = "pareto"
n_proposals = 30

[sweep]
curve_types = ["sqrt", "linear", "log", "exp"]
floors = [0.0, 0.1, 0.3]
alphas = [0.7]
max_workers = 4

[[sweep.lock_profiles]]
short = 0
long = 365

[sweep]
allocation_strategies = ["uniform_fraction"]
```

**Key Metrics:** Gini delta (legacy vs. signals), ENP ratio, top-k concentration
shift (k=1, k=5), flip_rate by margin class.

**Complexity:** LOW-MEDIUM. Three distinct small changes to factory.py, sweep.py.
No new algorithms. Exp curve math already implemented in weighting/signals.py.

---

### Sim D: Sybil Splitting Attack (PRIORITY 2)

**Research Question:** Does splitting stake into many wallets game the sqrt curve?
Is an honest whale strategy better than sybil splitting under budget constraints
and lock duration requirements?

**Experiment Design:**
- Compare: 1 whale with S tokens vs. N wallets with S/N tokens each
- Both strategies: same total budget, same lock duration commitment
- Test across curve types to find which curves are sybil-resistant

**Infrastructure Status:**

| Component                   | Status  | Notes |
|-----------------------------|---------|-------|
| lock_curve() math           | READY   | Supports all curves for any voter |
| Metrics + report            | READY   | All metrics work on any results_df |
| Sybil scenario generator    | GAP     | Factory generates random voters; cannot model adversarial splitting |
| Side-by-side comparison     | GAP     | No harness for honest-whale vs. sybil runs |
| Sybil advantage metric      | GAP     | No metric for sybil_advantage ratio |

**Required New Code:**

1. **Custom sybil scenario builder** — new function (or factory extension):
   ```python
   def generate_sybil_scenario(
       whale_budget: float,
       split_count: int,         # 1 = honest whale, N > 1 = sybil split
       lock_duration_days: float,
       n_honest_voters: int,
       curve_type: str,
       ...
   ) -> list[GovernorEvent]
   ```
   Must generate: `split_count` wallets each holding `whale_budget / split_count`
   tokens, alongside `n_honest_voters` regular voters. The factory's `_generate_stakes()`
   and `_generate_lock_durations()` generate random voters and cannot model this pattern.

2. **Comparison harness** — runs honest-whale (split_count=1) and sybil
   (split_count=N) side-by-side, collects results for statistical comparison.

3. **New metric: `compute_sybil_advantage()`**:
   ```python
   sybil_advantage = signals_share(N sybil wallets) / signals_share(1 honest whale)
   ```
   A value > 1.0 means sybil splitting increases effective voting power.
   Should return < 1.0 for sublinear curves (sqrt/log) under ideal conditions.

**Key Metrics:** sybil_advantage ratio, Gini under sybil attack, ENP distortion,
effective weight comparison between honest and sybil strategies.

**Complexity:** MEDIUM-HIGH. Requires genuinely new scenario generation logic,
not just sweep parameterization. The factory cannot be parameterized to produce
this pattern — new code is needed.

---

### Sim E: Participation Incentive Effect (PRIORITY 4)

**Research Question:** Does vote timing matter for fairness? Do late-voting whales
get dampened by any time-based mechanism? What is the correlation between vote
timing and stake rank?

**Sweep Design:**
- `vote_timings`: Multiple `VoteTimingConfig` with varying early/mid/late splits
- Cross with: voter_archetypes() (whale/medium/retail) from ANAL-04
- Use: timing_sensitivity() heatmap from ANAL-03 (already built)

**Infrastructure Status:**

| Component                   | Status  | Notes |
|-----------------------------|---------|-------|
| VoteTimingConfig            | READY   | Dataclass with early/mid fractions |
| vote_timings sweep axis     | READY   | In SweepConfig, threaded through _enumerate_cells |
| timing_sensitivity() ANAL-03 | READY  | 2D heatmap of weight_ratio by timing x lock quantile |
| voter_archetypes() ANAL-04  | READY   | Whale/medium/retail classification by stake tertile |
| influence_significance()    | READY   | Mann-Whitney U for group comparison |
| generate_scenario() timing  | READY   | Accepts vote_timing param, passes to _generate_vote_timing |
| Timing decay mechanism      | GAP     | **Does NOT exist.** Current system does not penalize late votes. |

**Two interpretation paths:**

**Path A — Analyze Existing Behavior (LOW complexity, mostly ready):**
Sweep vote_timings (early-heavy vs. late-heavy configs) and use timing_sensitivity()
to see how stake rank correlates with timing patterns. No new code required beyond
setting up TOML configs with vote_timing arrays.

**Path B — Implement Timing Decay (HIGH complexity):**
If the research question requires testing whether a NEW decay function should be
added to penalize late votes, that mechanism does not exist. Would require:
1. New decay function in `weighting/signals.py` (e.g., `timing_decay(vote_block, window)`)
2. Integration into `compute_signals_weight()` or a wrapper
3. New sweep axis for decay parameters

**Recommendation:** Clarify research intent before implementation. Path A is
immediately executable. Path B is a significant new feature design decision.

**Key Metrics:** timing_sensitivity heatmap, address_influence by archetype,
correlation of vote_block_rank with stake_rank.

**Complexity:** LOW (Path A) or HIGH (Path B, new mechanism).

---

### Sim F: Bimodal Stakes with Conviction-Weighted Allocation (PRIORITY 3)

**Research Question:** With bimodal stake distribution (10% whales, 90% retail),
does conviction_weighted allocation force whales to spread thin across proposals?

**Sweep Design:**
- `stake_profile`: 'bimodal'
- `allocation_strategy`: 'conviction_weighted' vs. 'uniform_fraction' (control)
- Cross with: `curve_types`, `lock_profiles`

**Infrastructure Status:**

| Component                       | Status       | Notes |
|---------------------------------|--------------|-------|
| stake_profile='bimodal'         | READY        | In factory; top 10% hold 90% of supply |
| allocation_strategy='conviction_weighted' | READY | In budget module; longer lock -> bigger commitment |
| sweep engine                    | READY        | Handles both axes natively |
| margin_class_breakdown()        | READY        | Per-flip analysis by margin class |
| voter_archetypes()              | READY        | Classifies whale vs. retail voters |
| All metrics                     | READY        | No changes needed |
| generate_scenario() parameters  | READY        | All needed params accepted |

**THIS SIM CAN RUN TODAY.**

**Expected TOML:**

```toml
[base]
n_voters = 200
seed = 42
stake_profile = "bimodal"
n_proposals = 30

[sweep]
curve_types = ["sqrt", "linear", "log"]
allocation_strategies = ["conviction_weighted", "uniform_fraction"]
alphas = [0.7]
max_workers = 4

[[sweep.lock_profiles]]
short = 30
long = 365
```

**Key Metrics:** flip_rate by margin class, Gini delta (bimodal has high legacy
Gini — how does signals change it?), per-archetype influence shift
(address_influence with voter_archetypes overlay), budget utilization by archetype.

**Complexity:** LOW. All infrastructure exists. Zero code changes required.

---

### Sim G: Scale Sensitivity (PRIORITY 5)

**Research Question:** Does the Signals Protocol advantage hold at different voter
population sizes?

**Sweep Design:**
- `n_voters`: [50, 200, 500, 2000]
- Cross with: best curve_type from Sim C results
- Fixed: pareto stake, independent locks

**Infrastructure Status:**

| Component               | Status  | Notes |
|-------------------------|---------|-------|
| generate_scenario(n_voters=N) | READY | Accepts any voter count |
| sweep engine + metrics  | READY   | Work for any n_voters |
| n_voters as sweep axis  | GAP     | n_voters is in base dict, NOT in cartesian grid |
| Scale performance       | CONCERN | n_voters=2000 x 30 proposals will be slow; may need cell_timeout adjustment |

**Two implementation approaches:**

**Approach A — Separate TOML Sweeps (no code changes, simpler):**
Run 4 separate sweeps, one per n_voters value. Manually compare summary CSVs.
Fast to implement, slightly less elegant for cross-n_voters heatmaps.

**Approach B — Add n_voters as Sweep Axis (small-medium code change):**
1. Add `n_voters_list: list[int] = field(default_factory=lambda: [200])` to `SweepConfig`
2. Include in `_enumerate_cells()` cartesian product
3. Thread to `_run_cell()` via SweepCell or base_cfg override
4. Adjust `cell_timeout_seconds` upward for n_voters=2000

**Performance consideration:** n_voters=2000 with n_proposals=30 generates 60,000+
potential VoteCastEvents (at 10% participation: ~6,000 votes). Memory management
(del + gc.collect()) is already in `_run_cell()`. Set `cell_timeout_seconds=300+`.

**Key Metrics:** Gini delta vs. n_voters, ENP ratio vs. n_voters, flip_rate vs.
n_voters, margin_shift vs. n_voters. Expected finding: advantages should be
scale-invariant if the protocol design is sound.

**Note:** n_voters < 100 with stake_profile='pareto' triggers a UserWarning because
the Gini coefficient may not reach the 0.65 threshold needed for realistic
inequality modeling.

**Complexity:** LOW (Approach A, separate sweeps) or MEDIUM (Approach B, sweep axis).

---

## Dependency Map

```
Sim C (Curve Sensitivity) ──────────────────> Sim G (Scale)
    │  Determines best curve_type                 Uses best curve from C
    │
    ├─────────────────────────────────────────> Sim D (Sybil)
    │  Tests sybil resistance of each curve        Tests curve robustness
    │
    └─────────────────────────────────────────> Sim F (Bimodal + Conviction)
         F can run now, but best to use C's           Uses best curve from C
         recommended curve for main analysis

Sim E (Participation/Timing) — Independent
    Can run anytime after clarifying Path A vs. Path B intent
```

**Blocking dependency:** Sim C must run first because its output (which curve type
dominates on Gini delta, ENP improvement, flip rate) determines the fixed
`curve_type` parameter used in Sims D, F, and G.

---

## Priority Execution Order with Rationale

| Order | Sim | Rationale | Blocking Work Before Start |
|-------|-----|-----------|--------------------------|
| 1 | C | Foundation — determines which curve to use in all downstream sims | Add 'exp' to factory ScenarioCurveType; optionally add floor param + floors sweep axis |
| 2 | D | Security — must validate sybil resistance before recommending a curve | New sybil scenario builder + comparison harness + sybil_advantage metric |
| 3 | F | Mechanism — tests conviction_weighted with bimodal stakes | None (ready today; run while D is being developed) |
| 4 | E | Fairness — timing analysis; simpler path is immediately available | Decide Path A (ready) vs. Path B (new decay mechanism); clarify research intent |
| 5 | G | Scale — validates chosen design holds at scale | Choose Approach A (no code) or Approach B (add n_voters axis); wait for C results |

---

## Infrastructure Gaps Summary

| Gap | Affects | Effort | Specific Change Needed |
|-----|---------|--------|------------------------|
| `exp` curve not in `ScenarioCurveType` | Sim C | XS (< 1 hour) | Change `factory.py` lines 23-24: add 'exp' to Literal and tuple |
| `floor` param not exposed in `generate_scenario()` | Sim C | S (2-4 hours) | Add `floor: float = 0.1` param, thread through to weighting calls in runner |
| `floors` not a `SweepConfig` axis | Sim C | S (2-4 hours) | Add `floors: list[float]` to SweepConfig, include in `_enumerate_cells()` cartesian product |
| Sybil scenario builder | Sim D | M (1-2 days) | New `generate_sybil_scenario()` function with whale_budget + split_count params |
| Side-by-side comparison harness | Sim D | S (2-4 hours) | Script that runs honest vs. sybil scenarios and collects results |
| `sybil_advantage` metric | Sim D | XS (< 1 hour) | New `compute_sybil_advantage()` function in metrics.py |
| Timing decay mechanism | Sim E (Path B only) | L (3-5 days) | Design + implement + test new timing weight decay; not needed for Path A |
| `n_voters` as sweep axis | Sim G (Approach B only) | S (2-4 hours) | Add `n_voters_list` to SweepConfig, `_enumerate_cells()`, `_run_cell()` |

---

## Quick Wins (No Code Changes Needed)

**Sim F** can run TODAY:

```bash
# In apps/simulations/
cat > /tmp/sim_f.toml << 'EOF'
[base]
n_voters = 200
seed = 42
stake_profile = "bimodal"
n_proposals = 30
budget_enabled = true

[sweep]
curve_types = ["sqrt", "linear", "log"]
allocation_strategies = ["conviction_weighted", "uniform_fraction"]
alphas = [0.7]
max_workers = 4

[[sweep.lock_profiles]]
short = 30
long = 365
EOF

# Then in Python:
# from backtesting.sweep import load_sweep_config, run_sweep
# from backtesting.report import generate_sweep_report
# config = load_sweep_config('/tmp/sim_f.toml')
# result = run_sweep(config)
# report = generate_sweep_report(result, row_axis='curve_type', col_axis='allocation_strategy')
```

**Sim E (Path A)** requires only TOML setup — no code changes:
Add vote_timing arrays to any existing sweep TOML and analyze with `timing_sensitivity()`.

---

## v3.0 Milestone Reference

All infrastructure was built across v1.0-v3.0 (Phases 1-12). Shipped 2026-02-28.

| Milestone | Phases | What Was Built |
|-----------|--------|----------------|
| v1.0      | 1-2    | Poetry to uv migration |
| v2.0      | 3-7    | Foundation + cadCAD runner, Metrics (METR-01 to METR-10), Plots, Pipeline |
| v3.0      | 8-12   | Budget promotion (VoterLedger), MC allocation (AllocationDistribution), Sweep engine (SweepConfig + run_sweep), Extended analysis (ANAL-01 to ANAL-06), Report bundle (generate_sweep_report) |

**Test coverage:** 207+ tests passing. 33/33 v3.0 requirements shipped.

All core modules documented and verified:
- `data/factory.py` — scenario generation
- `data/budget.py` — budget constraints and MC sampling
- `weighting/signals.py` — pure lock curve math (all 4 curves)
- `sweep.py` — cartesian sweep engine with parallel execution
- `analysis.py` — 6 extended analysis functions
- `metrics.py` — 10 scalar metric functions
- `report.py` — full report bundle with heatmaps, detail plots, composite figures
- `mc.py` — Monte Carlo independent sample runner
