# Claude Instructions

## Build & Development Commands
- Root: `yarn build` - Build all packages
- Root: `yarn dev` - Run all dev servers
- Root: `yarn lint` - Lint all packages
- Interface: `yarn interface` - Run just the interface dev server

## Testing
- Contracts: `forge test` - Run all tests
- Contracts: `forge test src/__tests__/TestFilename.t.sol -vvvv` - Run specific test with verbose output
- Interface: `cd apps/interface && yarn jest TestName` - Run specific jest test

## Code Style
- TypeScript/JavaScript: Use single quotes, no semicolons, 2-space indentation
- Imports: Use organized imports (auto-sorted by Biome)
- Naming: camelCase for variables/functions, PascalCase for components/classes
- Types: Use explicit TypeScript types, avoid `any`
- React: Use functional components with hooks
- Error Handling: Use try/catch with meaningful error messages
- Use Shadcn UI components for consistent interface design