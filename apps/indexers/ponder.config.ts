import { createConfig } from 'ponder'
import { getAddress, hexToNumber, http } from 'viem'

import { bondHookAbi, signalsAbi, signalsFactoryAbi } from '../sdk/src/abis'
import { poolManagerAbi } from './abis/pool-manager'

// Note: This should hot-reload when the file is changed
// import signalsDeployment from '../signals/broadcast/Development.s.sol/31337/run-latest.json'
import signals421614 from '../signals/broadcast/Testnet.s.sol/421614/run-latest.json'
import bondHookDeployment from '../bond-hook/broadcast/Development.sol/31337/run-latest.json'

const resolveDeployment = (name: string, metadata: any) => {
  const idx = metadata.transactions.findIndex(
    (t: any) => t.contractName === name && t.transactionType !== 'CREATE',
  )

  if (idx === -1) {
    throw new Error(`Deployment not found for ${name}`)
  }

  const deployment = {
    address: getAddress(metadata.transactions[idx]!.contractAddress),
    startBlock: hexToNumber(metadata.receipts[idx]!.blockNumber as `0x${string}`),
  }
  console.log('----- [', name, '] -----')
  console.log(deployment)

  return deployment
}

// https://ponder.sh/docs/advanced/foundry
export default createConfig({
  networks: {
    // anvil: {
    //   chainId: 31337,
    //   transport: http('http://127.0.0.1:8545'),
    //   disableCache: true,
    // },
    arbitrumSepolia: {
      chainId: 421614,
      transport: http(process.env.ARBITRUM_SEPOLIA_RPC_URL!),
    },
  },
  contracts: {
    SignalsFactory: {
      abi: signalsFactoryAbi,
      network: {
        arbitrumSepolia: {
          ...resolveDeployment('SignalsFactory', signals421614),
        },
      },
    },
    Signals: {
      abi: signalsAbi,
      network: {
        arbitrumSepolia: {
          address: '0x844C0DD2995cD430AaB7Ddd1DCa3FB15836674bc',
          startBlock: 134471651,
        },
      },
    },
    PoolManager: {
      abi: poolManagerAbi,
      network: {
        arbitrumSepolia: {
          address: '0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317',
          startBlock: 134471651,
        },
      },
    },
    // BondHook: {
    //   network: 'anvil',
    //   abi: bondHookAbi,
    //   ...resolveDeployment('BondHook', bondHookDeployment),
    // },
  },
})
