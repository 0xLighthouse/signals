# External Integrations

**Analysis Date:** 2026-02-27

## APIs & External Services

**Wallet Authentication:**
- Privy - User wallet connection and authentication
  - SDK: @privy-io/react-auth 3.8.1
  - Auth: Configured via `NEXT_PUBLIC_PRIVY_APP_ID` env var
  - Used in: `apps/interface/src/contexts/WalletProvider.tsx`
  - Provides: Wallet connection, user authentication, multi-chain support

**Blockchain RPC:**
- QuickNode (Base Sepolia) - JSON-RPC endpoint
  - Endpoint: `https://small-twilight-market.base-sepolia.quiknode.pro/...`
  - Config: `apps/interface/src/config/network-config.ts`
  - Used for: Contract reads via Viem public clients
  - Env: `NEXT_PUBLIC_RPC_URL`

**Indexer/Data:**
- Ponder GraphQL API - Blockchain indexer
  - Endpoint: Configurable via `NEXT_PUBLIC_INDEXER_ENDPOINT` (default: http://localhost:42069)
  - Client: @ponder/client 0.10.4
  - Location: `apps/interface/src/config/ponder.ts`
  - Schema: Generated from `apps/indexers/ponder.schema.ts`
  - Provides: Indexed on-chain events, boards, initiatives, locks, transfers

## Data Storage

**Databases:**
- PostgreSQL - Production data store for Ponder indexer
  - Connection: Configured via Railway environment
  - Client: Drizzle ORM 0.41.0
  - Location: `apps/indexers/` - uses Drizzle for query building
  - Schema: `apps/indexers/ponder.schema.ts`
  - Tables: Token, Board, Initiative, Lock, Transfer, Incentive, InitiativeWeight, Pool
  - Access: Via Ponder SQL client endpoint (`/sql/*` routes in `apps/indexers/src/api/index.ts`)

**Cache:**
- LRU Cache - In-memory caching via lru-cache 11.0.2
  - Used in: Ponder for event processing optimization
  - Scope: Runtime only, not persistent

**File Storage:**
- None detected - File references stored as URIs in contract metadata
  - Attachments stored as JSON: `uri`, `mimeType`, `description`
  - Schema location: `apps/indexers/ponder.schema.ts` (Board.boardMetadata, Initiative.attachments)

## Authentication & Identity

**Auth Provider:**
- Privy (custom merchant wallet auth)
  - Implementation: OAuth-style via @privy-io/react-auth
  - Supported methods: MetaMask, Coinbase Wallet, embedded wallet
  - Config file: `apps/interface/src/contexts/WalletProvider.tsx`
  - Chains supported: Base, Arbitrum, Optimism (via Privy config)
  - User data: Encrypted on Privy servers, app ID based multi-tenancy

**Smart Contract Authentication:**
- No traditional auth - uses Ethereum wallet signatures
- Proposals/supports verified by sender address in contract logs

## Monitoring & Observability

**Error Tracking:**
- None detected in production configuration

**Logs:**
- Console logging in indexer handlers
  - Example: `apps/indexers/src/index.ts` logs SignalsBoard:Transfer events
  - Environment logging configured via Ponder runtime
- Application logs via standard output (suitable for Railway)

**Health Checks:**
- Railway health endpoint: `/health`
  - Configured in `apps/indexers/railway.toml`
  - Timeout: 300 seconds
  - Path-based health check for indexer availability

## CI/CD & Deployment

**Hosting:**
- Railway (primary) - Containerized Ponder indexer deployment
  - Dockerfile: `apps/indexers/Dockerfile`
  - Config: `apps/indexers/railway.toml`
  - Start command: `pnpm start` with schema rotation strategy
  - Restart policy: ON_FAILURE with up to 10 retries

**Frontend Deployment:**
- Not explicitly configured (Next.js capable of Vercel, Railway, or standard Node hosting)
- Build output: Standard Next.js build format (`.next` directory)

**CI Pipeline:**
- GitHub Actions (via `.github/` directory presence)
- Husky pre-commit hooks enabled (`.husky/` directory)
- No explicit CI configuration detected, but infrastructure in place

**Contract Deployment:**
- Foundry Scripts - Located in `apps/protocol/script/` and `apps/signals-token-factory/script/`
- Deployment artifacts stored in broadcast JSON:
  - `apps/protocol/broadcast/DeploySignalsFactory.s.sol/84532/run-latest.json`
  - `apps/signals-token-factory/broadcast/DeployTokenFactory.s.sol/84532/run-latest.json`
- Resolved by Ponder at indexing startup

## Environment Configuration

**Required env vars (Frontend - apps/interface):**
```
NEXT_PUBLIC_PRIVY_APP_ID          # Privy app ID for wallet auth
NEXT_PUBLIC_RPC_URL                # Ethereum RPC endpoint
NEXT_PUBLIC_INDEXER_ENDPOINT       # Ponder indexer base URL
NEXT_PUBLIC_SIGNALS_PROTOCOL_ADDRESS  # Main protocol contract
NEXT_PUBLIC_BOARD_TOKEN_ADDRESS    # Board token contract
NEXT_PUBLIC_SIGNALS_FACTORY_ADDRESS # Factory contract
NEXT_PUBLIC_TOKEN_FACTORY_ADDRESS  # Token factory contract
NEXT_PUBLIC_SIGNALS_ENV            # Environment identifier
NEXT_PUBLIC_FEATURE_ENABLE_CONTRIBUTIONS # Feature flag
```

**Required env vars (Indexer - apps/indexers):**
```
PONDER_RPC_URL_84532          # Base Sepolia RPC for event indexing
DATABASE_URL                  # PostgreSQL connection string (set by Railway)
```

**Optional env vars (SDK - apps/sdk):**
```
CUSTOM_RPC_{chainId}          # Override RPC per chain
```

**Secrets location:**
- Environment variables via hosting platform (Railway for indexer)
- `.env` files (local development only, listed in `.gitignore`)
- No .env file committed to repository

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- None detected

**Event-driven Architecture:**
- Ponder listens to Ethereum events from contracts:
  - `ExperimentTokenFactory:TokenDeployed` - New token creation
  - `SignalsBoard:InitiativeProposed` - Proposal submission
  - `SignalsBoard:Transfer` - Bond NFT transfers
  - `SignalsFactory:BoardCreated` - Board creation (commented out in indexer)
  - Other events from `Signals.sol` and `IncentivesPool.sol` ABI

## GraphQL Integration

**Schema Source:**
- Generated from Ponder database tables
- Endpoint: `/graphql` at indexer URL
- Auto-generated GraphQL types via @ponder/client
- Schema location: `apps/indexers/ponder.schema.ts`

**SDK Code Generation:**
- GraphQL Code Generator 5.0.5
- Config: `apps/sdk/codegen.yml`
- Generates TypeScript types from indexer schema
- Output: `apps/sdk/src/types/graphql.ts`
- Documents: GraphQL queries in `apps/sdk/src/**/*.ts`

**API Routes (Indexer REST):**
- GET `/initiatives/:chainId/:address` - List initiatives for a board
- GET `/locks/account/:chainId/:address/:accountAddress` - User's locks
- GET `/locks/:chainId/:address/:initiativeId` - Locks for initiative
- GET `/bonds/:chainId/:address/:supporter` - Bonds owned by supporter
- GET `/stats/:chainId/:address` - Board statistics
- GET `/graphql` - GraphQL endpoint
- GET `/sql/*` - Direct SQL query interface (Ponder SQL client)
- GET `/health` - Health check endpoint

---

*Integration audit: 2026-02-27*
