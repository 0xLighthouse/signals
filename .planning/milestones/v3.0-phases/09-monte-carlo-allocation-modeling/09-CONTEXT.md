# Phase 9: Monte Carlo Allocation Modeling - Context

**Gathered:** 2026-02-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Allocation fractions are drawn from configurable probability distributions rather than fixed values, with seed-safe independent generators per MC sample. Exposes vote-timing parameters (`early_frac`, `mid_frac`) through `generate_scenario()`. This phase does NOT add sweep-axis integration, QMC variance reduction, or convergence diagnostics.

</domain>

<decisions>
## Implementation Decisions

### Distribution Configuration
- Beta distribution only in this phase (naturally bounded [0,1])
- `AllocationDistribution` type with `type='beta'`, `a`, `b` parameters
- Invalid parameters (a<=0, b<=0) raise `ValueError` immediately at construction time — no silent clamping
- One allocation fraction drawn per scenario (not per proposal) — matches current fixed-value semantics

### Seed & Reproducibility
- Reproducibility guaranteed within same NumPy version only (no cross-version pinning)
- Use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent MC generators
- Per-sample spawned seeds included in output metadata — enables reproducing individual interesting samples
- Allocation RNG independent from vote-timing RNG (separate spawned generators) — changing allocation distribution doesn't affect vote-timing randomness
- If no base_seed provided, auto-generate one and log it in output metadata so runs are always reproducible after the fact

### Vote-Timing Parameters
- `early_frac` and `mid_frac` exposed via a nested `VoteTimingConfig` object (not top-level params)
- API: `generate_scenario(vote_timing=VoteTimingConfig(early=0.3, mid=0.5))`
- Fail fast with `ValueError` if `early_frac + mid_frac > 1.0` (remaining is implicitly `late_frac`)

### Backward Compatibility
- `generate_scenario()` without `mc_dist` must produce bit-identical output to v2.0 for the same seed
- SeedSequence spawning only activates when `mc_dist` is provided — old seed path untouched otherwise
- No snapshot regression test required — success criteria validation is sufficient

### Claude's Discretion
- `AllocationDistribution` type design (dataclass vs Pydantic model vs other — match codebase patterns)
- Whether `early_frac`/`mid_frac` are fixed floats or also support distributional draws in MC mode
- Default values for `early_frac`/`mid_frac` (match current `_generate_vote_timing` internals)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-monte-carlo-allocation-modeling*
*Context gathered: 2026-02-28*
