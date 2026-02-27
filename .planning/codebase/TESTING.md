# Testing Patterns

**Analysis Date:** 2026-02-27

## Test Framework

**Runner:**
- Jest 29.7.0
- Config: `apps/interface/jest.config.js`
- Transform: ts-jest for TypeScript support

**Assertion Library:**
- Jest globals (expect) - imported via `@jest/globals`
- Available through Node.js test runner interface

**Run Commands:**
```bash
pnpm jest                                    # Run all tests
pnpm jest TestName                           # Run specific test by name/file pattern
cd apps/interface && pnpm jest --watch       # Watch mode (not configured in scripts)
pnpm jest --coverage                         # Coverage report (not configured in scripts)
```

## Test File Organization

**Location:**
- Tests co-located with source code
- Test directory: `__tests__/` folder at module level (e.g., `src/lib/__tests__/`)
- Separate from source but in same module directory

**Naming:**
- Pattern: `[module].test.ts` or `[module].spec.ts`
- Examples: `curves.test.ts`, `chart.test.ts`

**Structure:**
```
apps/interface/src/
├── lib/
│   ├── curves.ts
│   ├── chart.ts
│   └── __tests__/
│       ├── curves.test.ts
│       └── chart.test.ts
```

## Test Structure

**Suite Organization:**
```typescript
import { describe } from 'node:test'
import { calculateWeight, InitiativeDetails, Lock } from '../curves'

const DECAY_TYPE_LINEAR = 0
const LINEAR_DECAY_RATE = 1.2

describe('curves', () => {
  it('calculates linear decay as expected', () => {
    // Setup
    const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')
    const initiative: InitiativeDetails = { /* ... */ }
    const locks: Lock[] = []
    locks.push({ /* ... */ })

    // Execute
    const weights = calculateWeight(initiative, locks, LOCK_INTERVAL)

    // Assert
    expect(weights[0].y).toEqual(500_000)
    expect(weights[1].y).toEqual(500_000 - 50_000 * LINEAR_DECAY_RATE)
  })
})
```

**Patterns Observed:**
- Setup phase: Create test data and fixtures
- Execute phase: Call function with test data
- Assert phase: Verify results with expect() assertions
- Constants defined at top of file (DECAY_TYPE_LINEAR, LINEAR_DECAY_RATE, etc.)

## Mocking

**Framework:** Not explicitly used in current tests
- Current test suite focuses on unit tests without mocks
- No mocking dependencies detected in jest.config.js

**Patterns:**
- Test data is constructed inline using fixture objects
- No external service mocks detected
- All tests appear to be synchronous

**What to Mock:**
- External API calls should be mocked in future expansion
- Date/time operations use actual DateTime libraries (not mocked currently)

**What NOT to Mock:**
- Core business logic (decay calculations)
- Pure mathematical functions
- Type transformations

## Fixtures and Factories

**Test Data:**
```typescript
const CHART_OPTIONS: ChartOptions = {
  initiative: {
    createdAt: INITIATIVE_CREATED_AT.toUnixInteger(),
    lockInterval: LOCK_INTERVAL,
    decayCurveType: DECAY_TYPE_LINEAR,
    decayCurveParameters: [LINEAR_DECAY_RATE],
  },
  acceptanceThreshold: 500_000,
  chartInterval: LOCK_INTERVAL,
  minTimeWindow: 60 * 60 * 24 * 7,
  maxTimeWindow: 60 * 60 * 24 * 60,
}

const EXISTING_DATA: Lock[] = [
  {
    tokenAmount: 50_000,
    lockDuration: 10,
    createdAt: INITIATIVE_CREATED_AT.plus({day: 1}).toUnixInteger(),
    isWithdrawn: false,
  },
  // ... more locks
]
```

**Location:**
- Fixtures defined at top of test file
- Constants and data defined before test suite
- Shared across all tests in file

## Coverage

**Requirements:** Not enforced
- No coverage thresholds configured in jest.config.js
- No coverage gates in CI/CD detected

**View Coverage:**
```bash
pnpm jest --coverage        # Run with coverage output
pnpm jest --coverage --watch # Watch mode with coverage
```

**Current gaps:**
- Chart generation tests partially commented (assertions removed)
- Only 2 test files in active codebase
- API layer untested
- React component tests not implemented

## Test Types

**Unit Tests:**
- Scope: Pure functions (curves.ts, chart.ts)
- Approach: Test expected output given inputs
- Examples: decay calculations, weight calculations, tick generation
- No external dependencies tested

**Integration Tests:**
- Not currently implemented
- Would test API endpoints with database
- Would involve mock data fixtures at API level

**E2E Tests:**
- Not implemented
- No testing framework configured (no Cypress, Playwright, etc.)

## Common Patterns

**Async Testing:**
Not currently used - all tests are synchronous

```typescript
// If needed in future:
it('fetches data', async () => {
  const result = await fetchBoardMetadata()
  expect(result).toBeDefined()
})
```

**Error Testing:**
Not explicitly demonstrated in current tests

Pattern to follow:
```typescript
it('throws error when lock interval not set', () => {
  const initiative = { /* missing lockInterval */ }
  expect(() => calculateWeight(initiative, [], interval)).toThrow('Lock interval is not set')
})
```

**Skipping Tests:**
Partially commented test assertions indicate disabled tests:
```typescript
it('generates basic chart data', () => {
  const ticks = generateTicks(EXISTING_DATA, CHART_OPTIONS)
  console.log(ticks)
  // expect(weights[0].y).toEqual(500_000)  // Commented out
  // expect(weights[1].y).toEqual(...)      // Commented out
})
```

## Test Dependencies

**Key libraries:**
- `jest` - Test runner
- `ts-jest` - TypeScript transformer
- `@jest/globals` - Jest type definitions
- `luxon` - Date/time in tests
- Node.js test module (`node:test`)

**Configuration reference:**
- `jest.config.js`: Minimal config, uses ts-jest for TypeScript transformation
- Test environment: `node` (not jsdom)
- No setup files or test utilities configured

## Gaps & Recommendations

**Untested areas:**
- API routes (`apps/indexers/src/api/`) have no tests
- React components have no unit tests
- Context providers untested
- No integration test suite

**Future improvements:**
- Enable and complete commented assertions in chart.test.ts
- Add error case tests (negative cases)
- Add integration tests for API layer
- Consider adding React Testing Library for component tests
- Set up coverage thresholds to prevent regression

---

*Testing analysis: 2026-02-27*
