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

## Typography System

Our application uses a consistent typography system for uniform text styling:

### Using CSS Classes

The easiest way to apply typography styles is with utility classes:

```tsx
<h1 className="text-h1">Main Heading</h1>
<h2 className="text-h2">Subheading</h2>
<p className="text-body">Regular paragraph text</p>
<span className="text-caption">Small caption text</span>
```

Available typography classes:
- `text-display`: Very large display text
- `text-h1`, `text-h2`, `text-h3`, `text-h4`: Heading styles
- `text-body-lg`, `text-body`, `text-body-sm`: Body text in different sizes
- `text-caption`: Small caption text
- `text-mono`: Monospace text for code or technical information

### Using the Typography Component

For more control, use the Typography component:

```tsx
import { Typography } from '@/components/ui/typography'

<Typography variant="h1">Main Heading</Typography>
<Typography variant="body" weight="medium">Medium weight body text</Typography>
<Typography variant="caption" as="label">Custom HTML element</Typography>
```

### Using the Typography Function

For custom components or complex scenarios, import the helper function:

```tsx
import { typography } from '@/config/theme'

<button className={typography('body-sm', 'bold')}>Bold Small Text</button>
```

### Color System

Use the color utilities for consistent text coloring:

```tsx
import { colorSystem } from '@/config/theme'

<p className={colorSystem.text.secondary}>Secondary text color</p>
<div className={colorSystem.bg.brand}>Brand background color</div>
```
