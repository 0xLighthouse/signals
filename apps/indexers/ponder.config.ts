import { createConfig } from 'ponder'
import { getAddress, hexToNumber, http } from 'viem'

import { bondHookAbi, poolManagerAbi, signalsAbi, signalsFactoryAbi } from '../sdk/src/abis'

// Note: This should hot-reload when the file is changed
import signalsDeployment from '../signals/broadcast/Development.s.sol/31337/run-latest.json'
import bondHookDeployment from '../bond-hook/broadcast/Development.sol/31337/run-latest.json'

const resolveDeployment = (name: string, metadata: any) => {
  const idx = metadata.transactions.findIndex((t: any) => t.contractName === name)
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
    anvil: {
      chainId: 31337,
      transport: http('http://127.0.0.1:8545'),
      disableCache: true,
    },
  },
  contracts: {
    SignalsFactory: {
      network: 'anvil',
      abi: signalsFactoryAbi,
      ...resolveDeployment('SignalsFactory', signalsDeployment),
    },
    Signals: {
      network: 'anvil',
      abi: signalsAbi,
      ...resolveDeployment('Signals', signalsDeployment),
    },
    PoolManager: {
      network: 'anvil',
      abi: poolManagerAbi,
      ...resolveDeployment('PoolManager', bondHookDeployment),
    },
    BondHook: {
      network: 'anvil',
      abi: bondHookAbi,
      ...resolveDeployment('BondHook', bondHookDeployment),
    },
  },
})
