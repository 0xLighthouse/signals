# Repository Guidelines

## Project Structure & Module Organization
- Monorepo managed by pnpm and Turborepo; root scripts orchestrate workspace tasks.
- `apps/interface` hosts the Next.js client; `apps/protocol` contains Foundry contracts with scripts and tests.
- Supporting services live in `apps/indexers`, `apps/sdk`, `apps/docs`, `apps/signals-token-factory`, and `apps/simulations`; consult local READMEs before editing.
- Shared TypeScript utilities, UI primitives, ABIs, and configs sit under `packages/`.
- Operational helpers reside in `scripts/`; use them for local chain setup and seeded data.

## Build, Test, and Development Commands
- `pnpm install` syncs workspace dependencies; rerun after pulling lockfile changes.
- `pnpm dev` runs `turbo run dev` and starts all watchable apps; `pnpm interface` limits to the web client.
- `pnpm build` (or `pnpm build:interface`) compiles production bundles through Turbo.
- `pnpm lint` aggregates package linters; `pnpm format` applies Prettier to `ts/tsx/md`.
- Contracts: start Anvil (`anvil --block-time 5`), export `LOCAL_RPC`, `LOCAL_DEPLOYER_PRIVATE_KEY`, `BOND_ISSUER`, then execute `bash scripts/dev.sh`.

## Coding Style & Naming Conventions
- Biome enforces two-space indentation, 100-character lines, single quotes, and minimal semicolons.
- React components live in PascalCase files; hooks use `useCamelCase.ts`; colocate tests beside implementations.
- Solidity modules belong in `apps/protocol/src`; interfaces adopt the `IName.sol` pattern, and libraries use `NameLib.sol`.
- Prefer explicit type exports from `packages/shared`; keep shared UI tokens within `packages/ui`.

## Testing Guidelines
- Frontend unit tests run via Jest: `pnpm --filter interface exec jest`.
- Solidity suites rely on Foundry: `forge test` inside `apps/protocol`.
- Regenerate fixtures with `scripts/dev.sh` when scenarios depend on forked state.
- Name new specs after behaviour (`locks_extend_when_time_increases`) and cover edge cases around token locking and decay math.

## Commit & Pull Request Guidelines
- `.commitlintrc` enforces Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) with sentence-case subjects.
- Keep commits focused; run `pnpm lint`, relevant tests, and contract scripts before pushing.
- PRs must state intent, validation steps, and linked issues; UI diffs need before/after visuals, while protocol changes should note deployment or ABI impacts.

## Environment & Security Notes
- Never commit secrets; mirror new variables in `.env.example` and `turbo.json` `globalEnv`.
- Scripts under `scripts/` may broadcast transactions—use fork or dry-run flags when experimenting.
- Coordinate with protocol owners before altering factory defaults or emitting new ABIs.
