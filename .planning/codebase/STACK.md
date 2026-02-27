# Technology Stack

**Analysis Date:** 2026-02-27

## Languages

**Primary:**
- TypeScript 5.0+ - All backend services, frontend, SDK, and shared packages
- Solidity 0.8.26 - Smart contracts in `apps/protocol` and `apps/signals-token-factory`

**Secondary:**
- JavaScript/JSX/TSX - React components and Next.js configuration

## Runtime

**Environment:**
- Node.js v25.0.0+ (specified in `.nvmrc`)
- Foundry/Forge - Smart contract testing and deployment (`apps/protocol`)

**Package Manager:**
- pnpm 10.30.3 - Monorepo dependency management
- Lockfile: `pnpm-lock.yaml` (present)

## Frameworks

**Core Web:**
- Next.js 16.1.6 - Frontend framework at `apps/interface`
- React 18 - UI library across interface and packages
- TailwindCSS 4.0.16 - Styling and utility classes

**Blockchain/Web3:**
- Viem 2.x - Ethereum client library (2.41.2 in interface, 2.21.3 in indexers, 2.23.11 in SDK)
- Wagmi CLI 2.2.0 - Contract ABI generation from Foundry
- Foundry 0.8.26 - Smart contract development, testing, and deployment

**Backend/Indexing:**
- Ponder 0.16.3 - Blockchain indexer/event processor at `apps/indexers`
- Hono 4.11.10 - Lightweight HTTP framework for indexer API
- Drizzle ORM 0.41.0 - Database query builder for indexer

**Testing:**
- Jest 29.7.0 - JavaScript testing framework
- Forge Test - Solidity testing (Foundry)

**Build/Dev:**
- Turbo 2.4.4 - Monorepo task runner and build orchestration
- Biome 1.9.3 - Linter and formatter
- TypeScript compiler - Type checking
- GraphQL Code Generator 5.0.5 - Schema-based type generation for SDK

## Key Dependencies

**Critical:**
- @privy-io/react-auth 3.8.1 - Wallet connection and authentication
- @ponder/client 0.10.4 - GraphQL client for ponder indexer queries
- graphql-request 7.1.2 - Lightweight GraphQL HTTP client
- pg 8.13.1 - PostgreSQL client for Ponder
- lru-cache 11.0.2 - In-memory caching utility

**Infrastructure:**
- @openzeppelin/merkle-tree 1.0.5 - Merkle tree utilities for proofs
- abitype 1.2.3 - ABI type utilities
- @ponder/utils 0.2.17 - Ponder utility functions
- clsx 2.1.1 - Conditional CSS class merging
- radix-ui 1.4.3 - Headless UI component library
- shadcn 3.8.5 - Component generation for shadcn/ui
- recharts 2.15.4 - React charts library
- zustand 5.0.0 - State management library
- date-fns 4.1.0 & luxon 3.5.0 - Date manipulation libraries
- sonner 2.0.7 - Toast notification library
- lucide-react 0.575.0 - Icon library

## Configuration

**Environment:**
- Variables configured via `.env` files (see `.envrc.example`)
- Required public vars (prefixed with `NEXT_PUBLIC_`):
  - `NEXT_PUBLIC_PRIVY_APP_ID` - Privy authentication app ID
  - `NEXT_PUBLIC_RPC_URL` - Ethereum RPC endpoint
  - `NEXT_PUBLIC_INDEXER_ENDPOINT` - Ponder indexer GraphQL endpoint
  - `NEXT_PUBLIC_SIGNALS_PROTOCOL_ADDRESS` - Signals contract address
  - `NEXT_PUBLIC_BOARD_TOKEN_ADDRESS` - Board token contract address
  - `NEXT_PUBLIC_SIGNALS_FACTORY_ADDRESS` - Factory contract address
  - `NEXT_PUBLIC_TOKEN_FACTORY_ADDRESS` - Token factory address
  - `NEXT_PUBLIC_SIGNALS_ENV` - Environment identifier (development/production)

- Foundry private keys:
  - `DEPLOYER_TESTNET_SEED_PHRASE` - Testnet deployer seed
  - `ALICE_PRIVATE_KEY` - Test account key
  - `DEPLOYER_TESTNET_PRIVATE_KEY` - Testnet deployer key
  - `LOCAL_RPC` - Local Anvil RPC endpoint

**Build:**
- `biome.json` - Linting and formatting (2-space indentation, single quotes, no semicolons)
- `turbo.json` - Task pipeline orchestration
- `pnpm-workspace.yaml` - Monorepo workspace configuration
- `tsconfig.json` - Base TypeScript config in `packages/tsconfig`
- `wagmi.config.ts` - ABI generation from Foundry contracts

## Code Style

**Formatting:**
- Tool: Biome 1.9.3
- Indentation: 2 spaces
- Quotes: Single quotes preferred
- Line width: 100 characters
- Semicolons: AsNeeded

**Linting:**
- Tool: Biome with ESLint for packages (custom config)
- Import organization: Automatic via Biome
- Recommended rules enabled with exceptions:
  - `useExhaustiveDependencies`: off
  - `noNonNullAssertion`: off
  - `useImportType`: off

## Platform Requirements

**Development:**
- Node.js v25.0.0 or higher
- pnpm package manager
- Foundry (for contract work)
- Git with Husky hooks enabled (pre-commit linting)

**Production:**
- Node.js v25.0.0+
- PostgreSQL database (for Ponder indexer)
- Ethereum RPC endpoint (Base Sepolia testnet or mainnet)
- Railway platform (current deployment target - see `apps/indexers/railway.toml`)

**Supported Chains:**
- Base Sepolia (84532) - Primary testnet
- Arbitrum Sepolia (421614) - Secondary testnet
- Base Mainnet (8453) - Production capability
- Local Anvil (31337) - Development

---

*Stack analysis: 2026-02-27*
