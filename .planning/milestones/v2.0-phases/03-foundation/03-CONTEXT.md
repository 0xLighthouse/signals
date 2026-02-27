# Phase 3: Foundation - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Governor-compatible event schema, synthetic data factory, and Signals weight functions — a testable data and weighting layer that works without cadCAD. Delivers validated data structures, a synthetic event stream generator, pure weighting functions, and a data loader contract that makes synthetic/real data interchangeable.

</domain>

<decisions>
## Implementation Decisions

### Data Loader Contract
- Loader returns a pandas DataFrame (not raw event list)
- Real data will be loaded from Parquet files (not CSV, not live RPC)
- Loader validates data on load — rejects malformed events immediately (fail fast)
- Synthetic factory and file loader share a Python Protocol class defining `load() -> DataFrame`
- Loader always loads everything — no filtering on load, downstream filters as needed
- Lock duration placement: Claude's discretion (in VOTE_CAST event vs separate table)
- DataFrame structure (single vs separate per event type): Claude's discretion

### Event Schema Design
- Vote support: For / Against / Abstain (Governor Bravo tri-state)
- Typed fields use Python enums (EventType.VOTE_CAST, VoteSupport.FOR, etc.)
- Timestamps: block_number as primary, unix timestamp as optional derived field
- PROPOSAL_CREATED includes optional quorum field (defaults to 0 = no quorum)

### Synthetic Data Realism
- Scale: configurable with sensible defaults (medium: ~200 voters, ~30 proposals)
- Participation: power-law profile — few voters vote on everything, most vote rarely (matches real DAO turnout 5-15%)
- Contentiousness: mixed distribution — some blowouts, some competitive, some coin-flips
- Lock duration distribution: configurable scenarios — correlated with stake, independent, bimodal (short-term traders vs long-term holders)

### Lock Curve Behavior
- Default curve shape: square root — f(L) = sqrt(L / L_max)
- L_max: configurable, default 12 months
- Output range: normalized 0 to 1 (Signals weight is always ≤ raw stake)
- f(0): small floor (e.g., 0.1) — uncommitted voters still get minimal weight, not completely silenced
- All curve types (linear, log, sqrt, exp) must be available as options

### Claude's Discretion
- Lock duration placement: in VOTE_CAST events vs separate locks table — pick what works best for cadCAD event-replay
- DataFrame structure: single DataFrame with type discriminator vs separate per event type — pick what cadCAD consumes most naturally
- Exact default values for synthetic parameters (voter count, proposal count, participation rate)
- Pareto alpha parameter for stake distribution (research suggests ~1.5)
- Tri-modal timing distribution parameters

</decisions>

<specifics>
## Specific Ideas

- Schema should align with Governor Bravo field naming where possible (future real data swap)
- Parquet for real data import (typed columns, compact, fast)
- Protocol class for loader interface — explicit, type-checkable contract
- Python enums for all categorical fields — type-safe, IDE autocomplete
- "Configurable with sensible default" pattern throughout — parameters have good defaults but can be overridden

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-foundation*
*Context gathered: 2026-02-27*
