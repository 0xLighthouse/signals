---
phase: quick-02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/simulations/src/backtesting/data/factory.py
  - apps/simulations/src/backtesting/simulation/runner.py
  - apps/simulations/src/backtesting/simulation/sufs.py
  - apps/simulations/src/backtesting/sweep.py
  - apps/simulations/tests/test_factory.py
  - apps/simulations/tests/test_sweep.py
autonomous: true
requirements: [SIMC-01, SIMC-02, SIMC-03]
must_haves:
  truths:
    - "generate_scenario(curve_type='exp') succeeds without ValueError"
    - "generate_scenario(floor=0.3) threads floor to signals weight computation"
    - "SweepConfig with floors=[0.0, 0.1, 0.3] produces cartesian product including floor axis"
    - "Existing tests pass with no regressions"
  artifacts:
    - path: "apps/simulations/src/backtesting/data/factory.py"
      provides: "ScenarioCurveType with 'exp', generate_scenario with floor param"
      contains: "exp"
    - path: "apps/simulations/src/backtesting/sweep.py"
      provides: "SweepConfig.floors axis, SweepCell.floor field, floors in cartesian product"
      contains: "floors"
  key_links:
    - from: "factory.py generate_scenario(floor=X)"
      to: "runner.py run_backtest(floor=X)"
      via: "floor kwarg passthrough"
      pattern: "floor"
    - from: "runner.py cadCAD M params"
      to: "sufs.py suf_tallies"
      via: "params['floor']"
      pattern: "params.get\\('floor'"
    - from: "sweep.py _run_cell"
      to: "factory.py generate_scenario"
      via: "kwargs['floor'] = cell.floor"
      pattern: "kwargs\\['floor'\\]"
---

<objective>
Add 'exp' curve type to factory validation, thread floor parameter through the full simulation pipeline (generate_scenario -> run_backtest -> cadCAD -> compute_signals_weight), and add floors as a sweep axis in the sweep engine.

Purpose: Unblock Sim C (Curve Sensitivity) which requires all 4 curve types and floor sweeping.
Output: Updated factory.py, runner.py, sufs.py, sweep.py with passing tests.
</objective>

<execution_context>
@/home/biscii/.claude/get-shit-done/workflows/execute-plan.md
@/home/biscii/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/simulations/src/backtesting/data/factory.py
@apps/simulations/src/backtesting/simulation/runner.py
@apps/simulations/src/backtesting/simulation/sufs.py
@apps/simulations/src/backtesting/sweep.py
@apps/simulations/tests/test_factory.py
@apps/simulations/tests/test_sweep.py

<interfaces>
From apps/simulations/src/backtesting/weighting/signals.py:
```python
CurveType = Literal['sqrt', 'linear', 'log', 'exp']

def lock_curve(lock_duration_days: float, curve_type: CurveType = 'sqrt', l_max_days: float = 365.0, floor: float = 0.1) -> float: ...
def compute_signals_weight(stake: float, lock_duration_days: float, curve_type: CurveType = 'sqrt', l_max_days: float = 365.0, floor: float = 0.1) -> float: ...
```

From apps/simulations/src/backtesting/simulation/runner.py:
```python
def run_backtest(event_records: list, curve_type: str = 'sqrt') -> list[dict]: ...
def build_results_dataframe(raw_result: list[dict], event_records: list) -> pd.DataFrame: ...
```

From apps/simulations/src/backtesting/sweep.py:
```python
@dataclass
class SweepConfig:
    curve_types: list[str]
    alphas: list[float]
    lock_profiles: list[dict]
    allocation_strategies: list[str]
    max_workers: int
    cell_timeout_seconds: int = 120
    base: dict = field(default_factory=dict)
    mc_dists: list[AllocationDistribution] | None = None
    vote_timings: list[VoteTimingConfig] | None = None

@dataclass
class SweepCell:
    cell_id: int
    curve_type: str
    alpha: float
    lock_profile: dict
    allocation_strategy: str
    mc_dist: AllocationDistribution | None = None
    vote_timing: VoteTimingConfig | None = None

def _enumerate_cells(config: SweepConfig) -> list[SweepCell]: ...
def _run_cell(cell: SweepCell, base_cfg: dict) -> dict: ...
def _make_failed_row(cell: SweepCell) -> dict: ...
def load_sweep_config(path: str | pathlib.Path) -> SweepConfig: ...
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add exp to factory + thread floor through pipeline</name>
  <files>
    apps/simulations/src/backtesting/data/factory.py
    apps/simulations/src/backtesting/simulation/runner.py
    apps/simulations/src/backtesting/simulation/sufs.py
    apps/simulations/tests/test_factory.py
  </files>
  <action>
Three changes in this task:

**1. factory.py — Add 'exp' to ScenarioCurveType (lines 23-24):**
```python
ScenarioCurveType = Literal['sqrt', 'log', 'linear', 'exp']
_VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear', 'exp')
```

**2. factory.py — Add floor param to generate_scenario():**
Add `floor: float = 0.1` parameter to the function signature (after `curve_type`). The factory does NOT call lock_curve directly — it just needs to store this value so the runner can access it. However, since generate_scenario returns a list of GovernorEvent objects (not config), the floor value must be passed separately to run_backtest. So this param is purely for API symmetry at the factory level — the actual threading happens in runner.py and sufs.py.

Actually, looking more carefully: generate_scenario does NOT compute signals weights — it generates raw events. The signals weight is computed in the cadCAD simulation via suf_tallies. So floor needs to flow through run_backtest, not generate_scenario.

BUT the task description says to add floor to generate_scenario for completeness (so the sweep can pass it to the factory and have it available). Since generate_scenario doesn't use floor itself, just add the parameter and ignore it in the function body (it will be used by callers who also call run_backtest with the same floor).

Add `floor: float = 0.1` to generate_scenario signature, after curve_type. Add it to the docstring. Do NOT use it in the function body — it's a passthrough for callers.

**3. runner.py — Add floor param to run_backtest():**
Add `floor: float = 0.1` parameter to `run_backtest()`. Pass it into the cadCAD sim_config `M` dict:
```python
'M': {
    'event_stream': tuple(event_records),
    'curve_type': curve_type,
    'floor': floor,
},
```

**4. sufs.py — Read floor from params in suf_tallies():**
In suf_tallies, line 51 area, after `curve_type = params.get('curve_type', 'sqrt')`, add:
```python
floor = params.get('floor', 0.1)
```
Then pass it to compute_signals_weight on line 54:
```python
tallies[pid]['signals'][support] += compute_signals_weight(stake, lock_days, curve_type=curve_type, floor=floor)
```

**5. test_factory.py — Update tests:**
- Change `test_generate_scenario_curve_type_validation()`: Remove the line that expects `curve_type='exp'` to raise ValueError. Instead, add 'exp' to the list of valid types that should NOT raise.
- Add a new test `test_generate_scenario_exp_curve_end_to_end()` that runs `generate_scenario(curve_type='exp')` and then `run_backtest(events, curve_type='exp')` to confirm the full exp pipeline works.
- Add a new test `test_generate_scenario_floor_param()` that calls `generate_scenario(floor=0.3)` and confirms it accepts the param without error.
- Add a new test `test_run_backtest_floor_affects_signals()` that runs the same events through run_backtest with floor=0.1 vs floor=0.5 and confirms different signals tallies result.
  </action>
  <verify>
    cd apps/simulations && uv run pytest tests/test_factory.py tests/test_weighting.py tests/test_simulation_runner.py -x -q
  </verify>
  <done>
    - generate_scenario(curve_type='exp') succeeds
    - generate_scenario(floor=0.3) accepted without error
    - run_backtest(events, curve_type='exp', floor=0.5) produces different signals tallies than floor=0.1
    - All existing factory and weighting tests still pass
  </done>
</task>

<task type="auto">
  <name>Task 2: Add floors sweep axis to SweepConfig and sweep engine</name>
  <files>
    apps/simulations/src/backtesting/sweep.py
    apps/simulations/tests/test_sweep.py
  </files>
  <action>
**1. sweep.py — SweepConfig: Add floors field:**
```python
floors: list[float] = field(default_factory=lambda: [0.1])
```
Add after `vote_timings` field. Default [0.1] preserves backward compatibility.

**2. sweep.py — SweepCell: Add floor field:**
```python
floor: float = 0.1
```
Add after `vote_timing` field.

**3. sweep.py — _enumerate_cells(): Add floors to cartesian product:**
Add `config.floors` to the itertools.product call:
```python
combos = itertools.product(
    config.curve_types,
    config.alphas,
    config.lock_profiles,
    config.allocation_strategies,
    mc_dist_values,
    vote_timing_values,
    config.floors,
)
```
Update the unpacking in the enumerate loop to include `floor` and pass it to SweepCell constructor:
```python
for cell_id, (curve_type, alpha, lock_profile, allocation_strategy, mc_dist, vote_timing, floor) in enumerate(combos):
    cells.append(SweepCell(
        cell_id=cell_id,
        curve_type=curve_type,
        alpha=alpha,
        lock_profile=lock_profile,
        allocation_strategy=allocation_strategy,
        mc_dist=mc_dist,
        vote_timing=vote_timing,
        floor=floor,
    ))
```

**4. sweep.py — _run_cell(): Pass floor to generate_scenario and run_backtest:**
After the existing kwargs setup (~line 349), add:
```python
kwargs['floor'] = cell.floor
```
In the run_backtest call (~line 366), add floor:
```python
raw = run_backtest(events, curve_type=cell.curve_type, floor=cell.floor)
```

**5. sweep.py — _make_failed_row(): Add floor to failed row dict:**
Add `'floor': cell.floor,` to the returned dict (after allocation_strategy).

**6. sweep.py — _run_cell() return dict: Add floor to result row:**
Add `'floor': cell.floor,` to the returned dict (after allocation_strategy).

**7. sweep.py — load_sweep_config(): Parse floors from TOML:**
After parsing vote_timings, add:
```python
floors = sweep.get('floors', [0.1])
```
Pass `floors=floors` to the SweepConfig constructor.

**8. test_sweep.py — Add tests for floors axis:**
- `test_enumerate_cells_with_floors()`: SweepConfig with floors=[0.0, 0.1, 0.3] and curve_types=['sqrt'] produces 3 cells (1x1x1x1x1x1x3). Verify cell.floor values match.
- `test_enumerate_cells_floors_default_backward_compat()`: SweepConfig with default floors produces cells with floor=0.1.
- `test_enumerate_cells_floors_cartesian()`: 2 curve_types x 2 floors = 4 cells (with other axes at 1).
- `test_make_failed_row_has_floor()`: _make_failed_row includes 'floor' key.
- `test_swep07_toml_floors(tmp_path)`: TOML with `floors = [0.0, 0.1, 0.3]` parses correctly.
- `test_swep07_toml_no_floors(tmp_path)`: TOML without floors key defaults to [0.1].
- Update `test_generate_scenario_curve_type_validation` if it references _VALID_CURVE_TYPES directly (it uses the function, so likely no change needed here — already handled in Task 1).
  </action>
  <verify>
    cd apps/simulations && uv run pytest tests/test_sweep.py -x -q
  </verify>
  <done>
    - SweepConfig accepts floors=[0.0, 0.1, 0.3] and includes them in cartesian product
    - SweepCell has floor field passed through to _run_cell
    - _run_cell passes floor to both generate_scenario and run_backtest
    - load_sweep_config parses floors from TOML, defaults to [0.1]
    - _make_failed_row includes floor in output dict
    - All existing sweep tests pass with no regressions
  </done>
</task>

</tasks>

<verification>
```bash
cd apps/simulations && uv run pytest tests/ -x -q
```
All 207+ existing tests pass plus new tests for exp curve, floor param, and floors sweep axis.
</verification>

<success_criteria>
- generate_scenario(curve_type='exp') works end-to-end (no ValueError)
- floor parameter threads from generate_scenario -> run_backtest -> cadCAD params -> suf_tallies -> compute_signals_weight
- SweepConfig.floors axis participates in cartesian product enumeration
- TOML loading supports optional floors key with default [0.1]
- Zero test regressions
</success_criteria>

<output>
After completion, create `.planning/quick/2-sim-c-add-exp-to-factory-thread-floor-pa/2-SUMMARY.md`
</output>
