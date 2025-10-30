import { createConfig, factory } from 'ponder'
import { parseAbiItem } from 'viem'

// Note: This should hot-reload when the file is changed

const DEPLOYMENTS = {
  anvil: {
    SignalsFactory: 'apps/protocol/broadcast/DeploySignalsFactory.s.sol/31337/run-latest.json'
  }
}

import { resolveDeployment } from './src/utils/resolve-deployment'
import {
  SignalsABI,
  SignalsFactoryABI,
} from '../../packages/abis'
import { anvil } from 'viem/chains'

const latestFactory = resolveDeployment('SignalsFactory', DEPLOYMENTS.anvil.SignalsFactory)

const factoryBoardCreatedEvent = parseAbiItem(
  'event BoardCreated(address indexed board, address indexed owner)',
)

// https://ponder.sh/docs/advanced/foundry
export default createConfig({
  chains: {
    anvil: {
      id: anvil.id,
      rpc: anvil.rpcUrls.default.http[0],
      // === RPS OPTIMIZATION SETTINGS ===
      // 1. Increase polling interval (default is 1000ms)
      // This reduces how often Ponder checks for new blocks
      pollingInterval: 1_000, // Check every 10 seconds instead of every 1 second
    },
  },
  contracts: {
    SignalsBoard: {
      chain: 'anvil',
      abi: SignalsABI,
      address: factory({
        address: latestFactory.address,
        event: factoryBoardCreatedEvent,
        parameter: 'board',
      }),
      // Start indexing from the last factory deployment
      startBlock: latestFactory.startBlock,
    },
    // // TODO: Move this to the Factory deployment
    // Incentives: {
    //   chain: 'anvil',
    //   abi: IncentivesABI,
    //   address: '0xe4D69c41Db5c5790e3DCA52E4416fbbd676E960a',
    //   startBlock: latestFactory.startBlock,
    // },
    SignalsFactory: {
      abi: SignalsFactoryABI,
      chain: 'anvil',
      address: resolveDeployment('SignalsFactory', DEPLOYMENTS.anvil.SignalsFactory).address,
      startBlock: resolveDeployment('SignalsFactory', DEPLOYMENTS.anvil.SignalsFactory).startBlock,
    },
  },
})
