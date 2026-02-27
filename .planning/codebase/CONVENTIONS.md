# Coding Conventions

**Analysis Date:** 2026-02-27

## Naming Patterns

**Files:**
- Component files: kebab-case (e.g., `page-section.tsx`, `text-input.tsx`, `accept-initiative-dialog.tsx`)
- Utility/lib files: camelCase (e.g., `curves.ts`, `utils.ts`, `chart.ts`)
- Context/Provider files: PascalCase (e.g., `SignalsContext.tsx`, `WalletProvider.tsx`)
- API route files: dot-notation (e.g., `get.stats.ts`, `get.initiatives.ts`)

**Functions:**
- Use camelCase for all functions (e.g., `calculateWeight`, `generateTicks`, `formatNumber`)
- Arrow functions preferred for utility functions and callbacks
- Named exports for reusable utilities: `export const functionName = (...) => {}`
- Named exports for React components: `export function ComponentName({...}) { ... }`

**Variables:**
- Use camelCase for all variable names
- Use descriptive names for clarity: `walletBalance`, `lockInterval`, `boardAddress`
- Use abbreviated names sparingly and with context (e.g., `w` for weight in mathematical functions, `c` for context in Hono handlers)

**Types:**
- Use PascalCase for type/interface names (e.g., `InitiativeDetails`, `ChartLock`, `FormInputProps`)
- Use generic descriptive names: `InitiativeLock`, `BoardByAddressQueryResponse`, `SignalsContextValue`
- Omit type objects with `Omit` and extend with `&` operator: `type ChartLock = Omit<InitiativeLock, 'initiativeId' | 'tokenId'> & { nominalValueAsWAD: number }`

## Code Style

**Formatting:**
- Tool: Biome 1.9.3 (primary) + Prettier (fallback)
- Indent: 2 spaces (configured in both biome.json and .prettierrc)
- Line width: 100 characters (both tools configured)
- No semicolons (configured in both Biome and Prettier)
- Single quotes only (singleQuote: true)

**Linting:**
- Tool: Biome with recommended rules
- Key overrides in `biome.json`:
  - `useExhaustiveDependencies`: off (for React hooks flexibility)
  - `noNonNullAssertion`: off (allows non-null assertions when needed)
  - `useImportType`: off (allows regular imports for types)
- Line width enforcement: 100 characters

## Import Organization

**Order:**
1. Node.js built-in modules (e.g., `import { createContext } from 'react'`)
2. Third-party dependencies (e.g., `import { DateTime } from 'luxon'`)
3. Local absolute imports with path aliases (e.g., `import { useWeb3 } from '@/contexts/WalletProvider'`)
4. Local relative imports (rare; usually avoided with path aliases)

**Path Aliases:**
- `@/` points to `src/` directory (configured in tsconfig)
- Use absolute imports with `@/` instead of relative paths throughout the codebase
- Examples: `@/lib/routing`, `@/components/ui/card`, `@/indexers/api/types`, `@/config/network-types`

**Auto-sorting:**
- Biome's `organizeImports` is enabled and automatically sorts all imports
- Do not manually organize imports; let Biome handle it

## Error Handling

**Patterns:**
- Use explicit `throw new Error('message')` for synchronous errors with descriptive messages
- Use try/catch for async operations (e.g., fetch requests, contract reads)
- In catch blocks, log the error and either re-throw or return a safe default
- Example pattern:
  ```typescript
  try {
    const result = await fetch(url)
    if (!result.ok) throw new Error(`Request failed: ${result.status}`)
    return await result.json()
  } catch (error) {
    console.error('Error fetching data:', error)
    return null
  }
  ```

**Console logging for errors:**
- Use `console.error()` for errors in catch blocks
- Use `console.warn()` for warnings (missing configuration, fallbacks)
- Use `console.info()` for informational logs (initialization)
- Allow `console.log()` for debugging (will be left in code)

## Logging

**Framework:** console (standard browser/Node.js logging)

**Patterns:**
- Error logs: `console.error('Context: description', error)`
- Warning logs: `console.warn('Missing configuration')`
- Info logs: `console.info('Starting process...', variable)`
- Debug logs: `console.log('variable', value)` (acceptable for debugging)

**When to log:**
- Errors and exceptions should always be logged
- Missing configuration warnings should be logged
- Initialization/connection events should use info level
- Debug logs acceptable during development but reviewed before merge

## Comments

**When to Comment:**
- Complex mathematical operations or algorithms need explanation
- Non-obvious business logic requires context
- TODOs and FIXMEs should include description of what needs to be done
- Deprecated features should note the replacement
- Do not comment obvious code

**JSDoc/TSDoc:**
- Used selectively for public APIs and important functions
- Required for API route handlers with @route, @returns annotations
- Example from `get.stats.ts`:
  ```typescript
  /**
   * @route GET /stats/:chainId/:address
   * @returns Basic board stats: active initiatives, unique supporters, and total locked (humanized)
   */
  ```
- Function parameters documented when behavior is non-obvious

**TODO/FIXME style:**
- Format: `// TODO: Description of what needs to be done`
- Format: `// FIXME: Description of the issue`
- Examples in codebase:
  - `// FIXME: This type needs to be merged into our indexer types`
  - `// FIXME: We should use BigInt here`
  - `// TODO: Resolve ENS name`
  - `// TODO: Implement contract deployment using viem`

## Function Design

**Size:**
- Keep functions under 50 lines when possible
- Aim for single responsibility principle
- Extract complex logic into separate utility functions

**Parameters:**
- Use object parameters for functions with 2+ arguments
- Named parameters improve readability: `function generateTicks({ initiative, chartInterval, ... }: ChartOptions)`
- Use destructuring in function signatures when appropriate

**Return Values:**
- Always explicitly type return values in TypeScript
- Prefer specific types over `any`
- Return `null` or `undefined` explicitly rather than implicit undefined
- Example: `formatNumber(value: number, options: FormatNumberOptions = {}): string`

## Module Design

**Exports:**
- Use named exports for reusable functions and components
- Export types separately from implementations
- Avoid default exports; use named exports throughout codebase
- Barrel files with index.ts files list exports explicitly

**Barrel Files:**
- Minimal usage; most modules export directly
- Example: `apps/indexers/src/api/index.ts` exports API handlers
- Preference is direct imports from module files rather than through barrels

## Styling & React Patterns

**CSS:**
- TailwindCSS utility classes for styling
- className: Use clsx and tailwind-merge via `cn()` utility
- Example: `<div className={cn('p-6 mb-6', className)}>`

**Components:**
- Functional components with hooks (no class components)
- Use React hooks: `useState`, `useCallback`, `useEffect`, `useMemo`, `useContext`
- Props interface naming: `ComponentNameProps`
- Props destructured in function signature

**React Hooks:**
- Dependencies arrays always included and reviewed by Biome (with rule disabled by config)
- useCallback for memoized callbacks passed to children
- useMemo for expensive computations
- useContext with custom hooks (e.g., `useSignalsContext()`)

---

*Convention analysis: 2026-02-27*
