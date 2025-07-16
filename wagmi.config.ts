import { defineConfig } from '@wagmi/cli'
import { foundry } from '@wagmi/cli/plugins'

/**
 * https://wagmi.sh/cli/api/plugins/foundry
 */
export default defineConfig([
  {
    out: 'packages/abis/bond-hook.ts',
    plugins: [
      foundry({
        project: 'apps/bond-hook',
        include: ['BondHook.sol/**'],
      }),
    ],
  },
  {
    out: 'packages/abis/uniswap.ts',
    plugins: [
      foundry({
        project: 'apps/bond-hook',
        include: ['StateView.sol/**'],
      }),
    ],
  },
  {
    out: 'packages/abis/signals.ts',
    plugins: [
      foundry({
        project: 'apps/signals',
        include: ['Signals.sol/**', 'SignalsFactory.sol/**', 'Incentives.sol/**'],
      }),
    ],
  },
])
