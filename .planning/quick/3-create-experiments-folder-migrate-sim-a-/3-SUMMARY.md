---
phase: quick
plan: 3
subsystem: simulations
tags: [file-organization, git-mv, experiments, simulations]
dependency_graph:
  requires: []
  provides: [experiments-directory, sim-a-migrated, sim-b-migrated]
  affects: [apps/simulations/experiments/]
tech_stack:
  added: []
  patterns: [standalone-scripts, git-mv-history-preservation]
key_files:
  created:
    - apps/simulations/experiments/README.md
    - apps/simulations/experiments/sim_c/README.md
    - apps/simulations/experiments/sim_d/README.md
    - apps/simulations/experiments/sim_e/README.md
    - apps/simulations/experiments/sim_f/README.md
    - apps/simulations/experiments/sim_g/README.md
  modified:
    - apps/simulations/experiments/sim_a/sim_a.py (moved from src/figs/, updated docstring Usage path)
    - apps/simulations/experiments/sim_b/sim_b.py (moved from src/figs/, updated docstring Usage path)
decisions:
  - "Used git mv to preserve 100% file history for sim_a.py and sim_b.py"
  - "OUTPUT_DIR path unchanged (../../output resolves identically from experiments/sim_x/ as from src/figs/)"
  - "No __init__.py files created -- scripts are standalone, not importable packages"
  - "charts.py, incentives.py, signals-primer.py left untouched in src/figs/"
metrics:
  duration_seconds: 111
  completed_date: "2026-02-28"
  tasks_completed: 2
  files_created: 8
  files_modified: 0
---

# Quick Task 3: Create Experiments Folder and Migrate Sim A/B — Summary

**One-liner:** Organized simulation scripts into `experiments/` directory using `git mv` to preserve history, creating sim_a/ through sim_g/ subdirectories with migrated scripts and placeholder READMEs for planned sims C-G.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create experiments directory structure and migrate sim files | 415398c | experiments/README.md, experiments/sim_a/sim_a.py, experiments/sim_b/sim_b.py, sim_c-g/README.md (x5) |
| 2 | Verify migrated sims can import and run | (verification only) | None |

---

## What Was Built

### Directory Structure

```
apps/simulations/experiments/
  README.md           # Overview: all 7 sims, research questions, status, dependency order
  sim_a/
    sim_a.py          # Migrated via git mv; docstring Usage path updated
  sim_b/
    sim_b.py          # Migrated via git mv; docstring Usage path updated
  sim_c/
    README.md         # Placeholder: Curve Sensitivity
  sim_d/
    README.md         # Placeholder: Sybil Splitting Attack
  sim_e/
    README.md         # Placeholder: Participation Incentive Effect
  sim_f/
    README.md         # Placeholder: Bimodal Stakes with Conviction-Weighted Allocation
  sim_g/
    README.md         # Placeholder: Scale Sensitivity
```

### Git History Preserved

Both sim files show R100 (100% rename similarity) in git diff --cached. Running `git log --follow` on either file shows the full commit history from before the move.

### Path Verification

OUTPUT_DIR `../../output` resolves identically from `experiments/sim_x/` as it did from `src/figs/`:
- Old: `src/figs/` + `../../` = `apps/simulations/`
- New: `experiments/sim_a/` + `../../` = `apps/simulations/`

No path edits needed for OUTPUT_DIR. Only docstring Usage lines were updated.

### Untouched Files

`src/figs/` still contains: `charts.py`, `incentives.py`, `signals-primer.py`.

---

## Verification Results

- `ls apps/simulations/experiments/` shows sim_a/ through sim_g/ + README.md
- `git log --follow experiments/sim_a/sim_a.py` shows history from src/figs/sim_a.py (commits 2c8bfd4, d3dcf94)
- `grep -r "src/figs/sim_" apps/simulations/experiments/` returns no hits
- All backtesting imports resolve correctly from new location
- OUTPUT_DIR path resolves to correct `apps/simulations/output/` directory

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Self-Check: PASSED

Files verified:
- FOUND: apps/simulations/experiments/sim_a/sim_a.py
- FOUND: apps/simulations/experiments/sim_b/sim_b.py
- FOUND: apps/simulations/experiments/README.md
- FOUND: apps/simulations/experiments/sim_c/README.md
- FOUND: apps/simulations/experiments/sim_d/README.md
- FOUND: apps/simulations/experiments/sim_e/README.md
- FOUND: apps/simulations/experiments/sim_f/README.md
- FOUND: apps/simulations/experiments/sim_g/README.md

Commits verified:
- FOUND: 415398c feat(quick-3): Create experiments/ directory structure and migrate sim A/B
