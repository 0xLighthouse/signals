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
        project: 'apps/protocol',
        include: [
          'Signals.sol/**',
          'SignalsFactory.sol/**',
          // , 'Incentives.sol/**'
        ],
      }),
    ],
  },
  {
    out: 'packages/abis/signals-incentives-pool.ts',
    plugins: [
      foundry({
        project: 'apps/protocol',
        include: [
          'IncentivesPool.sol/**',
        ],
      }),
    ],
  },
  {
    out: 'packages/abis/signals-token-factory.ts',
    plugins: [
      foundry({
        project: 'apps/signals-token-factory',
        include: [
          'ExperimentToken.sol/ExperimentToken.json',
          'ExperimentTokenFactory.sol/ExperimentTokenFactory.json',
        ],
      }),
    ],
  },
])
