# Codebase Concerns

**Analysis Date:** 2026-02-27

## Tech Debt

**Immutable Configuration Parameters in Signals Contract:**
- Issue: Board configuration parameters (acceptance criteria, lock intervals, decay curve settings) set at initialization cannot be updated post-deployment. Breaking contracts requires full redeployment.
- Files: `apps/protocol/src/Signals.sol` (lines 122-165)
- Impact: Makes it impossible to adjust governance parameters in response to observed behavior or changing requirements without losing contract state
- Fix approach: Implement separate update functions for mutable parameters (accept criteria, token requirements) while keeping core constants immutable. Require owner authorization with timelock for safety.

**Duplicate Address Assignment in Development Config:**
- Issue: Alice and Bob are assigned the same hardcoded address in dev scripts, making it impossible to distinguish between two test accounts
- Files: `scripts/dev.sh` (lines 74-77)
- Impact: Development and testing scenarios that depend on multiple distinct accounts fail silently or produce incorrect results
- Fix approach: Use correct Anvil account addresses - currently Bob has the same address as Alice. Use proper Anvil-generated addresses with clear account separation.

**Inconsistent Type System in Curves Calculation:**
- Issue: Using JavaScript `number` type instead of `BigInt` for timestamp and lock duration calculations, causing precision loss in calculations involving large unix timestamps
- Files: `apps/interface/src/lib/curves.ts` (lines 80-81, 49)
- Impact: Potential calculation errors when dealing with future timestamps or long durations. Cryptographic precision required for financial calculations
- Fix approach: Convert all numeric calculations to use `BigInt` for timestamp/duration arithmetic, keeping only display values as number

**Fragmented Type Definitions Across Indexer/Contract:**
- Issue: `InitiativeDetails` interface in curves.ts duplicates/diverges from indexer types, creating source of truth conflicts
- Files: `apps/interface/src/lib/curves.ts` (lines 4-10)
- Impact: Schema changes at indexer require manual updates in multiple places, risk of type mismatches between contract data and UI
- Fix approach: Generate types from indexer schema, remove manual type definitions. Single source of truth approach.

**Expired Bounty Refund Logic Not Implemented:**
- Issue: Code recognizes when bounties have expired but lacks implementation for refunding contributors. Refund logic marked as TODO with TODO note about gas implications.
- Files: `apps/protocol/src/Bounties.sol` (lines 104-106, 193-195)
- Impact: If initiatives expire with unclaimed bounties, funds become stuck in contract. Contributors cannot recover their tokens.
- Fix approach: Implement `_refundExpiredBounties()` function with batch processing to handle gas limits. Add refund withdrawal interface for contributors to claim expired bounties.

**Token Mixing in Bounty Distribution:**
- Issue: Code explicitly marked FIXME acknowledges mixing various token denominations in bounty calculations, with sketchy implementation
- Files: `apps/protocol/src/Bounties.sol` (lines 302-304)
- Impact: Bounty distribution calculations may be incorrect when initiatives have bounties in multiple token types
- Fix approach: Implement separate accounting for each token denomination. Track and distribute bounties per-token rather than aggregating different tokens.

## Known Bugs

**IncentivesPool Rewards Exceeding Maximum Per Initiative:**
- Symptoms: Test `test_IncentivesPool_MultipleSupporter` fails because calculated rewards exceed `maxRewardPerInitiative` when multiple supporters contribute at different times
- Files: `apps/protocol/test/signals/Incentives.t.sol` (lines 201-203)
- Trigger: Two or more supporters locking tokens at different times in same initiative
- Status: Test is commented out, issue not yet fixed
- Workaround: Limit rewards per supporter rather than per initiative, or adjust bucket calculation logic

**Board Initialization Cannot Be Updated:**
- Symptoms: Any misconfiguration during contract initialization locks board into incorrect state permanently
- Files: `apps/protocol/src/Signals.sol` (lines 122-165)
- Trigger: Deploying with invalid parameters
- Workaround: None - requires full contract redeployment

## Security Considerations

**Type Safety Bypass - ts-ignore in Critical Logic:**
- Risk: Hardcoded `@ts-ignore` comments suppress TypeScript validation in several places, hiding potential type mismatches
- Files:
  - `apps/interface/src/components/drawers/create-board-from-factory-drawer.tsx` (line 186)
  - `apps/interface/src/contexts/IncentivesContext.tsx` (line 51)
  - `apps/interface/src/hooks/useApproveTokens.ts` (line 83)
- Current mitigation: Runtime testing, manual code review
- Recommendations: Properly type contract ABIs and return values. Avoid ts-ignore; fix underlying type issues instead.

**Historical Balance Verification Uncertainty:**
- Risk: Authorizer contract has unverified TODO around ERC20Votes historical balance checking - implementation correctness unclear
- Files: `apps/protocol/src/Authorizer.sol` (lines 72-84)
- Current mitigation: Fallback to reject if checkpoints unavailable
- Recommendations: Add comprehensive test coverage for all token types. Create clear documentation of supported token interfaces.

**Hardcoded Private Keys in Dev Script:**
- Risk: Private keys exposed in dev script (even though they're test keys) - bad security practice
- Files: `scripts/dev.sh` (lines 70-72)
- Current mitigation: These are Anvil default keys, not production
- Recommendations: Never commit real private keys. Use `.envrc.example` pattern exclusively. Document that these are test-only keys.

**Unimplemented Contract Deployment in Factory Drawer:**
- Risk: Factory deployment function shows success toast without actually deploying anything
- Files: `apps/interface/src/components/drawers/create-board-from-factory-drawer.tsx` (lines 51-53)
- Current mitigation: Frontend TODO prevents accidental misuse
- Recommendations: Implement deployment logic or remove placeholder success message. Add clear error if feature is unavailable.

## Performance Bottlenecks

**Decay Curve Weight Calculation Inefficiency:**
- Problem: `calculateWeight()` iterates through all locks for every single chart point, resulting in O(locks × points) complexity
- Files: `apps/interface/src/lib/curves.ts` (lines 45-75)
- Cause: Nested loops without optimization or memoization
- Impact: UI will freeze with large datasets (1000+ locks, 1000+ points = 1M iterations)
- Improvement path: Implement quadtree or interval tree structure for lock ranges, batch calculations by interval, add memoization layer

**Unbounded Incentive Bucket Array Iteration:**
- Problem: IncentivesPool uses fixed 24-bucket array but iterates through all buckets even when sparse
- Files: `apps/protocol/src/IncentivesPool.sol` (lines 72-73, 26)
- Cause: Array-based storage with no sparse lookup optimization
- Impact: Gas costs grow with bucket count regardless of actual usage
- Improvement path: Use mapping instead of fixed array, implement bucket lazy initialization

**Type Conversion Without Caching:**
- Problem: `useAsyncProp()` hook lacks proper generic typing and doesn't memoize results
- Files: `apps/interface/src/lib/useAsyncProp.ts` (lines 3-13)
- Cause: Missing dependency array, no memoization
- Impact: Unnecessary re-renders when promises resolve, inefficient async handling
- Improvement path: Add proper TypeScript generics, implement useCallback, add useEffect dependency optimization

## Fragile Areas

**SignalsFactory Clone Verification Not Tested:**
- Files: `apps/protocol/test/SignalsFactory.t.sol` (lines 119-126)
- Why fragile: No tests verify that deployed clones are independent or function correctly. Factory uses Solidity assembly or proxy pattern not fully tested.
- Safe modification: Add comprehensive clone verification tests before making factory pattern changes. Test state isolation between instances.
- Test coverage gaps: 15+ TODO test cases (lines 83-156) covering event emission, parameter validation, duplicate handling, fuzz testing

**Bounty Distribution Logic Without Full Test Coverage:**
- Files: `apps/protocol/src/Bounties.sol`, `apps/protocol/test/Bounties.t.sol`
- Why fragile: Multiple unimplemented allocation and expiration test cases (lines 142-264). Distribution math changes could break silently.
- Safe modification: Implement comprehensive test suite for allocation scenarios before modifying distribution logic. Test all token combinations.
- Test coverage gaps: Claim rewards tests, allocation tests, token registry tests, expiration handling tests all TODO

**Generalized Redux/Context Type System:**
- Files: `apps/interface/src/contexts/SignalsContext.tsx` (338 lines)
- Why fragile: Context manages complex board state with incomplete typing and multiple conversion functions
- Safe modification: Add integration tests for context state transitions, avoid direct state mutation, keep conversion logic pure
- Test coverage gaps: No visible tests for SignalsContext updates or data transformations

**ENS Name Resolution Unimplemented:**
- Files: `apps/interface/src/lib/resolveName.ts` (lines 3-5)
- Why fragile: Function returns shortened address instead of ENS name - inconsistent behavior
- Safe modification: Implement proper ENS resolution or remove feature. Clarify if function is placeholder.
- Test coverage gaps: No tests for ENS resolution path

## Scaling Limits

**Chart Rendering Performance with Large Lock Sets:**
- Current capacity: Handles ~100 locks with responsive UI
- Limit: Beyond ~500 locks, weight calculations cause noticeable lag
- Scaling path: Implement virtualized list rendering, server-side aggregation for historical data, progressive loading

**IncentivesPool Budget Allocation Across Initiatives:**
- Current capacity: Single board budgets calculated per initiative
- Limit: Multiple concurrent initiatives with overlapping locks create exponential bucket calculation overhead
- Scaling path: Implement bucket aggregation across initiatives, use mathematical approximation for historical periods instead of iteration

**Type Registry Lack of Pagination:**
- Current capacity: All token registrations held in simple mapping
- Limit: No enumeration interface for discovering registered tokens at scale
- Scaling path: Add pagination to token registry, implement enumerable token set, consider off-chain registry with proof validation

## Dependencies at Risk

**Zod Version Duplication:**
- Risk: Project uses both `zod@3.22.4` and `zod@3.25.76` in lock file
- Impact: Inconsistent validation behavior, potential incompatibility
- Migration plan: Standardize on latest compatible Zod version across all workspaces

**@types/node Fragmentation:**
- Risk: Multiple incompatible @types/node versions (12.20.55 exists alongside 20.x versions)
- Impact: Type conflicts between packages, outdated type definitions
- Migration plan: Audit all packages, upgrade Node to current LTS (20+), standardize on matching type versions

**Missing Critical ABI Definitions:**
- Risk: UniswapV4PoolManager ABI marked as TODO with commented-out placeholder
- Files: `apps/sdk/src/constants.ts` (lines 17, 46)
- Impact: Cannot interact with Uniswap integration; feature blocked
- Migration plan: Add proper ABI, implement full Uniswap integration or remove placeholder

## Missing Critical Features

**Board Creation Factory Deployment Not Implemented:**
- Problem: UI shows factory drawer, accepts all parameters, shows success toast, but doesn't actually deploy contracts
- Blocks: Users cannot create new boards from UI
- Impact: High - feature advertised but nonfunctional

**ENS Name Resolution:**
- Problem: All addresses rendered as shortened hex strings regardless of ENS availability
- Blocks: Better UX for address display
- Impact: Medium - quality-of-life feature

**GraphQL Indexer Hardcoded to Localhost:**
- Problem: SDK hardcodes indexer URL to `http://localhost:42069/graphql` with TODO to move to env
- Blocks: Production deployment impossible without code change
- Impact: High - blocks deployment without code modification

**Configuration File Persistence in Simulations:**
- Problem: Both `load_from_file` and `save_to_file` in simulations config raise NotImplementedError
- Files: `apps/simulations/src/cadcad/config.py` (lines 147-154)
- Blocks: Cannot persist or load simulation configurations
- Impact: Medium - feature expected but nonfunctional

## Test Coverage Gaps

**Smart Contract Factory Pattern - 15+ unimplemented test cases:**
- What's not tested: Event emission, multiple deployments, parameter validation, duplicate handling, fuzz testing, integration flows
- Files: `apps/protocol/test/SignalsFactory.t.sol` (lines 83-156)
- Risk: Factory pattern changes could break clone independence without detection
- Priority: High - Factory is core infrastructure

**Bounties Integration - 20+ unimplemented test cases:**
- What's not tested: Claim rewards, allocation distribution, expiration handling, token registry management, event emission, balance verification
- Files: `apps/protocol/test/Bounties.t.sol` (lines 142-264)
- Risk: Bounty logic errors could result in stuck funds or incorrect distributions
- Priority: High - Financial criticality

**IncentivesPool Reward Calculation:**
- What's not tested: Multi-supporter scenarios (test skipped due to bug), bucket-weighted reward accuracy
- Files: `apps/protocol/test/signals/Incentives.t.sol` (lines 201-204)
- Risk: Reward distribution could be incorrect for real-world usage patterns
- Priority: Critical - Financial calculations

**Interface Unit Tests:**
- What's not tested: Only 2 test files found (chart and curves), no tests for contexts, drawers, or components
- Files: `apps/interface/src/lib/__tests__/` (2 test files only)
- Risk: UI bugs in common paths go undetected
- Priority: Medium - Depends on backend correctness

---

*Concerns audit: 2026-02-27*
