# Phase 5: Metrics - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

10 governance metrics as pure functions on the results DataFrame (from Phase 4). Each metric compares legacy (stake-only) vs Signals (commitment-weighted) voting regimes. No cadCAD imports. No side effects.

</domain>

<decisions>
## Implementation Decisions

### Metric return types
- Each metric function returns a frozen dataclass with named fields (e.g., `FlipRateResult(per_proposal=Series, aggregate=float)`)
- Dual-regime metrics return both legacy and Signals results in a single call (e.g., `GiniResult(legacy=0.82, signals=0.71)`)
- All 10 metric functions live in a single `metrics.py` module
- No `compute_all_metrics()` convenience function — callers compose what they need

### Outcome classification
- Pass/Fail determined by simple majority: FOR > AGAINST = Pass, no quorum threshold
- Tie (FOR == AGAINST) = Fail — matches Governor behavior
- Transition matrix returns both counts (2x2 int) and proportions (2x2 float) in a `TransitionMatrix` dataclass
- Margin computed as percentage: (FOR - AGAINST) / (FOR + AGAINST) — normalizes across proposals

### Timing boundaries
- "Late" for late-vote share = final third of the proposal window (last 33% of blocks between start_block and end_block)
- Late-vote share weighted by voting power, not voter count — captures whale timing behavior
- Lock-in = earliest block where remaining uncast voting power cannot flip the outcome
- Lock-in timing reported as fraction of voting window elapsed (0.0 = start, 1.0 = end) — comparable across proposals

### Concentration thresholds
- Top-k values hardcoded as [1, 5, 10] — not configurable
- When k >= num_voters, return 100% share (all voting power captured)
- Nakamoto coefficient uses voting power per regime (legacy = raw stake, Signals = W_signals)
- ENP and Nakamoto computed per-proposal (not just aggregate) — shows variance across proposals

### Claude's Discretion
- Exact dataclass field names and types
- Internal helper function structure
- Test fixture design
- Whether to use numpy or pandas internals for computation

</decisions>

<specifics>
## Specific Ideas

- Margin as percentage of total is standard in political science — good for publication credibility
- Per-proposal granularity is important for showing variance, not just averages
- Lock-in as fraction elapsed makes for cleaner plots than raw block numbers

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-metrics*
*Context gathered: 2026-02-27*
