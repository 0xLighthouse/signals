# Repository Guidelines

## Project Structure & Module Organization
- Core contracts live under `src/`; the primary entry point is `src/PausableTokenFactory.sol`.
- Tests are in `test/` and use Foundry’s `forge-std` utilities for cheat codes and assertions.
- Deployment scripts belong in `script/`; use `script/DeployTokenFactory.s.sol` as the template for broadcasting factory + token deployments.
- External libraries sit in `lib/`; `lib/openzeppelin-contracts` supplies the ERC20, Ownable, and Pausable primitives.
- Build artifacts land in `out/` and cached compiler data in `cache/`; both can be safely cleaned with `forge clean`.

## Build, Test, and Development Commands
- `forge build` compiles the full contract set; add `-vv` for verbose diagnostics.
- `forge test` executes all `test_*` functions; run `forge test --fork-url <RPC>` to exercise fork-based scenarios.
- `forge lint` re-compiles with lint checks; resolve warnings before opening a PR.
- `forge fmt` auto-formats Solidity sources; run it prior to commits to avoid formatting churn.
- `forge script script/DeployTokenFactory.s.sol:DeployTokenFactoryScript --broadcast --rpc-url <RPC> --private-key <KEY>` deploys the factory and an example pausable token.

## Coding Style & Naming Conventions
- Target Solidity `^0.8.23`; keep pragma clauses consistent across `src/`, `test/`, and `script/`.
- Prefer OpenZeppelin primitives over bespoke security code; import them via the `@openzeppelin/` remapping configured in `foundry.toml`.
- Name contracts with `PascalCase` and interfaces with an `I` prefix. Storage variables use lowerCamelCase; constants use ALL_CAPS.
- Test functions should be prefixed `test_`, grouping words with Pascal casing after the underscore (e.g., `test_PauseBlocksTransfers`).
- Run `forge fmt` after edits; manual alignment is discouraged.

## Testing Guidelines
- Favor focused unit tests that assert revert selectors via `vm.expectRevert` or try/catch, as shown in `test/PausableTokenFactory.t.sol`.
- Use `makeAddr` for deterministic addresses and `vm.prank`/`vm.startPrank` for caller context.
- When adding new pausable behaviors, include tests that cover both paused and unpaused flows plus edge cases (zero supply, owner-less deployments).
- Capture gas-sensitive paths with `forge snapshot` when optimizing.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) to keep `git log` scannable; include scope tags like `feat(token):`.
- Group related changes—contracts, tests, and scripts—in a single commit when they ship together.
- PRs should describe deployment implications, new commands, and testing performed; attach logs from `forge test`/`forge lint` when possible.
- Link related issues or discussion threads and call out any follow-up tasks required post-merge (e.g., redeploying factory instances).
