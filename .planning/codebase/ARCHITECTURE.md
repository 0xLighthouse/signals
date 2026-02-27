# Architecture

**Analysis Date:** 2026-02-27

## Pattern Overview

**Overall:** Monorepo with modular separation of concerns - frontend (Next.js), blockchain indexing (Ponder), SDK layer, and smart contracts (Solidity).

**Key Characteristics:**
- Multi-layered web3 application with clear separation between UI, data indexing, SDK, and protocol layers
- Context-based state management for global application state
- Event-driven architecture for on-chain data synchronization
- GraphQL for indexed data queries
- Direct wallet integration via Privy and Viem

## Layers

**Smart Contracts (Protocol):**
- Purpose: Core blockchain logic for the Signals protocol
- Location: `apps/protocol/src`
- Contains: Factory contracts, board management, voting mechanisms, incentive logic
- Depends on: OpenZeppelin libraries, viem for testing
- Used by: Protocol layer events indexed by Ponder, SDK queries

**Indexing Layer (Ponder):**
- Purpose: Real-time indexing of blockchain events and contract state
- Location: `apps/indexers/src`
- Contains: Event handlers, schema definitions, GraphQL API endpoints, data transformations
- Depends on: Ponder framework, Drizzle ORM, PostgreSQL, Hono for HTTP routing
- Used by: Interface frontend via GraphQL queries, SDK for board data

**SDK Layer:**
- Purpose: Typed client library for Signals protocol interaction
- Location: `apps/sdk/src`
- Contains: GraphQL client, action definitions (listBoards, getBoard), type definitions
- Depends on: graphql-request, viem, generated GraphQL types
- Used by: Interface frontend, other applications consuming the protocol

**Frontend (Next.js Interface):**
- Purpose: User interface for board discovery, initiative management, and governance interaction
- Location: `apps/interface/src`
- Contains: Pages, components, contexts, hooks, stores, configuration, utilities
- Depends on: SDK, Privy authentication, Viem for wallet interaction, TailwindCSS
- Used by: End users in browsers

**Shared/Reusable Packages:**
- `packages/shared`: Empty index, reserved for shared TypeScript utilities
- `packages/ui`: Base UI components
- `packages/abis`: Generated contract ABIs from Solidity
- `packages/tsconfig`: Shared TypeScript configurations

## Data Flow

**Board Discovery & Initialization:**

1. User visits interface, ChainProvider and WalletProvider initialize
2. SignalsProvider fetches board list from Ponder GraphQL endpoint
3. useBoardsStore queries indexer for all boards on current chain
4. User navigates to specific board, SignalsContext loads board metadata
5. SignalsContext queries indexer GraphQL for board configuration, requirements, and state
6. Board metadata, requirements, and decay configuration populated for display

**Initiative Submission Flow:**

1. User submits initiative through propose-initiative-drawer component
2. Wallet interaction via Viem walletClient (signed by Privy)
3. Transaction confirmation monitored on-chain
4. Protocol contract emits InitiativeCreated event
5. Ponder event handler processes and indexes initiative
6. useInitiativesStore invalidates and refetches initiatives
7. UI updates with new initiative

**Lock/Support Flow:**

1. User locks tokens on initiative via user-locks component
2. Lock transaction signed via wallet client
3. Protocol emits Lock event with lock details
4. Ponder indexes lock with status tracking
5. useLocksStore refetches locks for user account and initiative
6. UI displays updated lock status and weight

**State Management:**

- Global state: ChainKey, theme, route parameters via contexts and stores
- Per-board state: SignalsContext provides board metadata, balances, requirements
- UI state: Zustand stores for boards, initiatives, locks, rewards, support drawer
- Wallet state: Privy integration for authentication, Viem for web3 interactions

## Key Abstractions

**SignalsProvider/SignalsContext:**
- Purpose: Provides board-scoped context including board metadata, user balances, and derived values (formatter, meets threshold checks)
- Examples: `apps/interface/src/contexts/SignalsContext.tsx`
- Pattern: React Context Provider with callbacks for board metadata fetching

**Zustand Stores:**
- Purpose: Client-side data fetching and caching for boards, initiatives, locks
- Examples: `apps/interface/src/stores/useBoardsStore.ts`, `useInitiativesStore.ts`, `useLocksStore.ts`
- Pattern: Centralized state machine per domain, lazy fetching on demand

**Ponder Schema & Relations:**
- Purpose: Define on-chain indexed entities and their relationships
- Examples: `apps/indexers/ponder.schema.ts`
- Pattern: Onchain tables with JSON serialized complex types (BoardConfig, DecayConfig), relations defining board→initiatives→locks hierarchy

**Viem Public/Wallet Clients:**
- Purpose: Abstract blockchain RPC interactions and wallet signing
- Examples: `apps/interface/src/lib/viem/publicClient.ts`, `walletClient.ts`
- Pattern: Chain-specific client instances memoized by ChainKey

## Entry Points

**Interface (Next.js App):**
- Location: `apps/interface/src/app/layout.tsx`
- Triggers: User visits web URL
- Responsibilities: Root layout, provider setup (Theme, Chain, Wallet, Signals), font loading, sidebar initialization

**Indexer (Ponder Server):**
- Location: `apps/indexers/ponder.config.ts`
- Triggers: Ponder dev/start command
- Responsibilities: Contract tracking configuration, network setup, schema definition

**Protocol (Smart Contracts):**
- Location: `apps/protocol/src/SignalsFactory.sol`
- Triggers: Blockchain transactions calling factory methods
- Responsibilities: Board creation, token setup, permission initialization

## Error Handling

**Strategy:** Try-catch with console error logging and fallback state

**Patterns:**
- GraphQL fetch failures in SignalsProvider fall back to initialBoard state
- Store fetch errors log to console and set empty state
- Wallet operations depend on Privy error handling
- Contract calls wrapped in try-catch with user-facing toast notifications (Sonner)

## Cross-Cutting Concerns

**Logging:** console.log/warn/error for debugging, structured logging via indexer API responses

**Validation:** Viem type system enforces address and numeric types, GraphQL schema enforces query shapes, Ponder schema enforces database structure

**Authentication:** Privy handles wallet authentication, no backend user accounts required

**Network Configuration:** ChainKey enum gates supported chains, network-config.ts provides chain-specific RPC endpoints and indexer GraphQL endpoints

---

*Architecture analysis: 2026-02-27*
