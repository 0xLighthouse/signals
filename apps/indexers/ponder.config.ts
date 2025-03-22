import { createConfig, factory } from 'ponder'
import { http, parseAbiItem } from 'viem'

// Note: This should hot-reload when the file is changed
// import signalsDeployment from '../signals/broadcast/Development.s.sol/31337/run-latest.json'
import signals421614 from '../signals/broadcast/Testnet.s.sol/421614/run-latest.json'
import { resolveDeployment } from './src/utils/resolve-deployment'
import { BondHookABI, PoolManagerABI, SignalsABI, SignalsFactoryABI } from '../../packages/abis'

const latestFactory = resolveDeployment('SignalsFactory', signals421614)

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
      startBlock: latestFactory.startBlock,
    },
    SignalsFactory: {
      abi: SignalsFactoryABI,
      network: {
        arbitrumSepolia: {
          ...resolveDeployment('SignalsFactory', signals421614),
        },
      },
    },
    PoolManager: {
      abi: PoolManagerABI,
      network: {
        arbitrumSepolia: {
          address: '0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317',
          startBlock: 134471651,
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
      startBlock: 134471651,
    },
  },
})
