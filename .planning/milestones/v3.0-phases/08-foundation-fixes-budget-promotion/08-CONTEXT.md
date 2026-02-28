# Phase 8: Foundation Fixes & Budget Promotion - Context

**Gathered:** 2026-02-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Clean up bugs that would silently corrupt sweep heatmaps (_gini, _enp edge cases), promote private budget internals from factory.py to a testable public `backtesting/data/budget.py` module, and thread `curve_type` as a first-class parameter through generate_scenario() and metrics computation. All 147 existing tests must pass after refactor.

</domain>

<decisions>
## Implementation Decisions

### budget.py Public API
- Class-based API: VoterLedger as a public class (promoted from _VoterLedger)
- VoterLedger is mutable, accumulates vote records over time (matches current behavior)
- compute_allocation_fraction is a standalone public function, not a VoterLedger method — keeps it composable for Phase 9's MC sampling
- budget.py is a leaf module: only imports numpy/stdlib, no internal backtesting imports — maximum testability and reusability

### AllocationDistribution Design
- Class hierarchy with base class, not a single discriminated dataclass
- Three concrete subclasses: BetaDistribution, UniformDistribution, TruncnormDistribution
- Each subclass has a .sample(rng, size) method that knows how to draw from itself
- Parameters validated on construction (e.g., Beta a,b > 0) — fail fast with clear errors before any simulation runs

### NaN Propagation Strategy
- _gini() returns np.nan for zero-sum arrays, _enp() returns np.nan for zero-weight arrays
- NaN propagates silently through downstream metrics — no logging, no warnings (NaN is a valid expected result for zero-participation proposals)
- Add explicit edge-case tests for zero-sum gini and zero-weight enp as regression tests
- Establish NaN-for-degenerate-inputs as a documented convention for all metric functions (sets pattern for Phase 11 extended analysis)

### curve_type Threading
- Represented as Literal['sqrt', 'log', 'linear'] — string literals, not Enum
- Default value is 'sqrt' (backward-compatible with current hardcoded behavior)
- Three curve types supported: sqrt, log, linear (linear is trivial to add and completes the sweep comparison set)
- Validated at the generate_scenario() boundary — fail fast before any work starts, clear error listing valid types

### Claude's Discretion
- Internal organization of budget.py (method ordering, helper functions)
- Exact VoterLedger method signatures beyond what's specified
- How factory.py delegates to the new budget.py module
- Test file organization for new edge-case tests

</decisions>

<specifics>
## Specific Ideas

- AllocationDistribution class hierarchy should be designed so Phase 9 can add .sample() calls without subclassing VoterLedger
- compute_allocation_fraction taking a ledger as first arg makes it natural to compose: `compute_allocation_fraction(ledger, curve_type='log', alpha=0.5)`
- NaN convention should be noted in a docstring or module-level comment so Phase 11 implementers follow the same pattern

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-foundation-fixes-budget-promotion*
*Context gathered: 2026-02-28*
