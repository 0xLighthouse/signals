---
phase: quick
plan: 3
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/simulations/experiments/sim_a/sim_a.py
  - apps/simulations/experiments/sim_b/sim_b.py
  - apps/simulations/experiments/sim_c/README.md
  - apps/simulations/experiments/sim_d/README.md
  - apps/simulations/experiments/sim_e/README.md
  - apps/simulations/experiments/sim_f/README.md
  - apps/simulations/experiments/sim_g/README.md
  - apps/simulations/experiments/README.md
autonomous: true
requirements: [QUICK-3]

must_haves:
  truths:
    - "experiments/ directory exists with sim_a through sim_g subdirectories"
    - "sim_a.py and sim_b.py run successfully from their new locations"
    - "git history is preserved for migrated files (used git mv)"
    - "Placeholder READMEs exist for sims C-G referencing THESIS_GUIDE.md"
  artifacts:
    - path: "apps/simulations/experiments/sim_a/sim_a.py"
      provides: "Migrated Sim A script"
    - path: "apps/simulations/experiments/sim_b/sim_b.py"
      provides: "Migrated Sim B script"
    - path: "apps/simulations/experiments/README.md"
      provides: "Experiments directory overview"
  key_links:
    - from: "apps/simulations/experiments/sim_a/sim_a.py"
      to: "apps/simulations/output/"
      via: "OUTPUT_DIR relative path"
      pattern: "OUTPUT_DIR.*output"
---

<objective>
Create the `apps/simulations/experiments/` folder structure for all seven simulations (A-G), migrate existing sim_a.py and sim_b.py from `apps/simulations/src/figs/` into it using `git mv`, and fix relative paths so they still run.

Purpose: Organize simulation scripts into a dedicated experiments directory as the project grows from 2 sims to 7.
Output: experiments/ directory with sim_a/ through sim_g/ subdirectories, migrated scripts, and placeholder READMEs.
</objective>

<execution_context>
@/home/biscii/.claude/get-shit-done/workflows/execute-plan.md
@/home/biscii/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/simulations/src/figs/sim_a.py
@apps/simulations/src/figs/sim_b.py
@apps/simulations/THESIS_GUIDE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create experiments directory structure and migrate sim files</name>
  <files>
    apps/simulations/experiments/sim_a/sim_a.py
    apps/simulations/experiments/sim_b/sim_b.py
    apps/simulations/experiments/sim_c/README.md
    apps/simulations/experiments/sim_d/README.md
    apps/simulations/experiments/sim_e/README.md
    apps/simulations/experiments/sim_f/README.md
    apps/simulations/experiments/sim_g/README.md
    apps/simulations/experiments/README.md
  </files>
  <action>
    1. Create all experiment directories:
       ```
       mkdir -p apps/simulations/experiments/sim_{a,b,c,d,e,f,g}
       ```

    2. Use `git mv` to migrate the two sim files (preserves history):
       ```
       git mv apps/simulations/src/figs/sim_a.py apps/simulations/experiments/sim_a/sim_a.py
       git mv apps/simulations/src/figs/sim_b.py apps/simulations/experiments/sim_b/sim_b.py
       ```

    3. Fix the OUTPUT_DIR path in BOTH migrated files. The old path was:
       ```python
       OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'output')
       ```
       The new location is `experiments/sim_a/sim_a.py` which is 2 levels deep from `apps/simulations/`.
       Update to:
       ```python
       OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'output')
       ```
       Actually the depth is the same (experiments/sim_a/ is 2 levels, same as src/figs/), so the relative path `../../output` still resolves correctly. VERIFY this by checking: from `experiments/sim_a/`, `../..` = `apps/simulations/`, and `output/` exists there. The path is UNCHANGED -- no edit needed for OUTPUT_DIR.

    4. Update the docstring Usage lines in both files:
       - sim_a.py: Change `uv run python src/figs/sim_a.py` to `uv run python experiments/sim_a/sim_a.py`
       - sim_b.py: Change `uv run python src/figs/sim_b.py` to `uv run python experiments/sim_b/sim_b.py`

    5. Create `apps/simulations/experiments/README.md` with an overview listing all 7 sims, their research questions (from THESIS_GUIDE.md), and status (A/B = implemented, C-G = planned).

    6. Create placeholder README.md files for sims C through G. Each should contain:
       - Sim letter and name (from THESIS_GUIDE.md)
       - Research question (from THESIS_GUIDE.md)
       - Status: "Planned -- see THESIS_GUIDE.md for infrastructure status and required code changes"
       - Reference: `../../THESIS_GUIDE.md`

       Sim descriptions from THESIS_GUIDE.md:
       - Sim C: Curve Sensitivity -- "Which lock curve shape best amplifies small holders while maintaining whale accountability?"
       - Sim D: Sybil Splitting Attack -- "Does splitting stake into many wallets game the sqrt curve?"
       - Sim E: Participation Incentive Effect -- "Does vote timing matter for fairness?"
       - Sim F: Bimodal Stakes with Conviction-Weighted Allocation -- "With bimodal stake distribution, does conviction_weighted allocation force whales to spread thin?"
       - Sim G: Scale Sensitivity -- "Does the Signals Protocol advantage hold at different voter population sizes?"

    7. Do NOT create __init__.py files -- these are standalone scripts, not importable packages.

    8. Do NOT move signals-primer.py, charts.py, or incentives.py -- they are not sims and stay in src/figs/.
  </action>
  <verify>
    <automated>cd /home/biscii/src/signals/apps/simulations && test -f experiments/sim_a/sim_a.py && test -f experiments/sim_b/sim_b.py && test -f experiments/README.md && test -f experiments/sim_c/README.md && test -f experiments/sim_d/README.md && test -f experiments/sim_e/README.md && test -f experiments/sim_f/README.md && test -f experiments/sim_g/README.md && echo "PASS: all files exist"</automated>
  </verify>
  <done>All 7 experiment directories exist. sim_a.py and sim_b.py are migrated via git mv. Placeholder READMEs exist for C-G. Overview README exists at experiments/README.md.</done>
</task>

<task type="auto">
  <name>Task 2: Verify migrated sims can import and run</name>
  <files></files>
  <action>
    Run a dry import check for both migrated sim files to confirm all imports resolve correctly from the new location. The imports use `from backtesting.data import generate_scenario` etc., which resolve via the Python path set by `uv run` from the `apps/simulations/` working directory. The working directory is what matters, not the script location.

    1. Verify sim_a.py imports resolve:
       ```bash
       cd apps/simulations && uv run python -c "import importlib.util; spec = importlib.util.spec_from_file_location('sim_a', 'experiments/sim_a/sim_a.py'); mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); print('sim_a imports OK')"
       ```
       NOTE: This will actually RUN main() because the module-level code is guarded by `if __name__ == '__main__'`. A safer approach is to just test the imports:
       ```bash
       cd apps/simulations && uv run python -c "
       import sys; sys.path.insert(0, 'src')
       from backtesting.data import generate_scenario
       from backtesting.simulation import run_backtest, build_results_dataframe
       from backtesting.metrics import compute_flip_rate, compute_gini
       print('All backtesting imports OK')
       "
       ```

    2. Verify OUTPUT_DIR resolves correctly from new location:
       ```bash
       cd apps/simulations && uv run python -c "
       import os
       sim_a_dir = os.path.dirname(os.path.abspath('experiments/sim_a/sim_a.py'))
       output = os.path.join(sim_a_dir, '..', '..', 'output')
       output = os.path.normpath(output)
       print(f'OUTPUT_DIR resolves to: {output}')
       assert output.endswith('apps/simulations/output'), f'Bad path: {output}'
       print('OUTPUT_DIR path OK')
       "
       ```

    3. Verify git tracks the move (not a delete+add):
       ```bash
       git diff --cached --name-status | grep sim_[ab]
       ```
       Should show R (rename) status for both files.
  </action>
  <verify>
    <automated>cd /home/biscii/src/signals/apps/simulations && uv run python -c "import sys; sys.path.insert(0, 'src'); from backtesting.data import generate_scenario; from backtesting.simulation import run_backtest; from backtesting.metrics import compute_flip_rate; print('imports OK')" && echo "PASS"</automated>
  </verify>
  <done>Both migrated sim scripts can resolve all their backtesting imports from the new location. OUTPUT_DIR paths resolve to apps/simulations/output/ correctly.</done>
</task>

</tasks>

<verification>
- `ls apps/simulations/experiments/` shows sim_a/ through sim_g/ directories
- `git log --follow experiments/sim_a/sim_a.py` shows history from src/figs/sim_a.py
- `grep -r "src/figs/sim_" apps/simulations/experiments/` returns no hits (old paths removed from docstrings)
- src/figs/ still contains charts.py, incentives.py, signals-primer.py (untouched)
</verification>

<success_criteria>
- experiments/ directory has 7 subdirectories (sim_a through sim_g)
- sim_a.py and sim_b.py moved via git mv with updated docstring usage paths
- Placeholder READMEs for C-G reference THESIS_GUIDE.md
- Overview README at experiments/README.md lists all 7 sims
- No files accidentally removed from src/figs/ (charts.py, incentives.py, signals-primer.py remain)
</success_criteria>

<output>
After completion, create `.planning/quick/3-create-experiments-folder-migrate-sim-a-/3-SUMMARY.md`
</output>
