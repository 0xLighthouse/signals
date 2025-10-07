import { defineConfig } from '@wagmi/cli'
import { foundry } from '@wagmi/cli/plugins'

/**
 * https://wagmi.sh/cli/api/plugins/foundry
 */
export default defineConfig([
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
