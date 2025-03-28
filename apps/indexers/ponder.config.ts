import { createConfig, factory } from 'ponder'
import { http, parseAbiItem } from 'viem'

// Note: This should hot-reload when the file is changed
import signalsTestnet from '../signals/broadcast/Testnet.s.sol/421614/run-latest.json'
import { resolveDeployment } from './src/utils/resolve-deployment'
import { BondHookABI, PoolManagerABI, SignalsABI, SignalsFactoryABI } from '../../packages/abis'

const latestFactory = resolveDeployment('SignalsFactory', signalsTestnet)

const factoryBoardCreatedEvent = parseAbiItem(
  'event BoardCreated(address indexed board, address indexed owner)',
)

const poolManagerInitializeEvent = parseAbiItem(
  'event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)',
)

// https://ponder.sh/docs/advanced/foundry
export default createConfig({
  networks: {
    arbitrumSepolia: {
      chainId: 421614,
      transport: http(process.env.ARBITRUM_SEPOLIA_RPC_URL!),
      // === RPS OPTIMIZATION SETTINGS ===

      // 1. Increase polling interval (default is 1000ms)
      // This reduces how often Ponder checks for new blocks
      pollingInterval: 30_000, // Check every 10 seconds instead of every 1 second
    },
  },
  contracts: {
    SignalsBoard: {
      network: 'arbitrumSepolia',
      abi: SignalsABI,
      address: factory({
        address: latestFactory.address,
        event: factoryBoardCreatedEvent,
        parameter: 'board',
      }),
      // Start indexing from the last factory deployment
      startBlock: latestFactory.startBlock,
    },
    SignalsFactory: {
      abi: SignalsFactoryABI,
      network: {
        arbitrumSepolia: {
          ...resolveDeployment('SignalsFactory', signalsTestnet),
        },
      },
    },
    PoolManager: {
      abi: PoolManagerABI,
      network: {
        arbitrumSepolia: {
          address: '0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317',
          // Start indexing from the last factory deployment
          startBlock: latestFactory.startBlock,
        },
      },
    },
    BondMarket: {
      network: 'arbitrumSepolia',
      abi: BondHookABI,
      address: factory({
        address: '0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317',
        event: poolManagerInitializeEvent,
        parameter: 'hooks',
      }),
      // Start indexing from the last factory deployment
      startBlock: latestFactory.startBlock,
    },
  },
})
