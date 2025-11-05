import { createConfig, factory } from 'ponder'
import { parseAbiItem } from 'viem'
import { resolveDeployment } from './src/utils/resolve-deployment'
import {
  SignalsABI,
  SignalsFactoryABI,
  ExperimentTokenABI,
  ExperimentTokenFactoryABI,
} from '../../packages/abis'
import { anvil, base, baseSepolia } from 'viem/chains'

// Note: This should hot-reload when the file is changed

const DEPLOYMENTS = {
  anvil: {
    SignalsFactory:
      'apps/protocol/broadcast/DeploySignalsFactory.s.sol/31337/run-latest.json',
    ExperimentTokenFactory:
      'apps/signals-token-factory/broadcast/DeployTokenFactory.s.sol/31337/run-latest.json',
  },
  baseSepolia: {
    SignalsFactory:
      'apps/protocol/broadcast/DeploySignalsFactory.s.sol/84532/run-latest.json',
    ExperimentTokenFactory:
      'apps/signals-token-factory/broadcast/DeployTokenFactory.s.sol/84532/run-latest.json',
  },
}

const latestSignalsFactory = resolveDeployment(
  'SignalsFactory',
  DEPLOYMENTS.baseSepolia.SignalsFactory,
)
const latestExperimentTokenFactory = resolveDeployment(
  'ExperimentTokenFactory',
  DEPLOYMENTS.baseSepolia.ExperimentTokenFactory,
)

// https://ponder.sh/docs/advanced/foundry
export default createConfig({
  chains: {
    // anvil: {
    //   id: anvil.id,
    //   rpc: anvil.rpcUrls.default.http[0],
    //   // === RPS OPTIMIZATION SETTINGS ===
    //   // Increase polling interval (default is 1000ms)
    //   pollingInterval: 1_000,
    //   disableCache: true,
    // },
    baseSepolia: {
      id: baseSepolia.id,
      rpc: process.env.PONDER_RPC_URL_84532,
      pollingInterval: 5_000,
    },
  },
  contracts: {
    // Track the factory itself to receive TokenDeployed events
    ExperimentTokenFactory: {
      chain: 'baseSepolia',
      abi: ExperimentTokenFactoryABI,
      address: latestExperimentTokenFactory.address,
      startBlock: latestExperimentTokenFactory.startBlock,
    },

    // Dynamically track all ExperimentToken instances created by the factory
    ExperimentToken: {
      chain: 'baseSepolia',
      abi: ExperimentTokenABI,
      address: factory({
        address: latestExperimentTokenFactory.address,
        event: parseAbiItem(
          'event TokenDeployed(address indexed token, string name, string symbol)',
        ),
        parameter: 'token',
      }),
      startBlock: latestExperimentTokenFactory.startBlock,
    },

    SignalsBoard: {
      chain: 'baseSepolia',
      abi: SignalsABI,
      address: factory({
        address: latestSignalsFactory.address,
        event: parseAbiItem(
          'event BoardCreated(address indexed board, address indexed owner)',
        ),
        parameter: 'board',
      }),
      // Start indexing from the last factory deployment
      startBlock: latestSignalsFactory.startBlock,
    },

    SignalsFactory: {
      abi: SignalsFactoryABI,
      chain: 'baseSepolia',
      address: latestSignalsFactory.address,
      startBlock: latestSignalsFactory.startBlock,
    },
  },
})
