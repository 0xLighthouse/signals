import { createConfig } from 'ponder'
import { getAddress, hexToNumber, http } from 'viem'

import { signalsFactoryAbi } from '../sdk/src/abis/signals-factory'

// Note: This will hot-reload when the file is changed
import signalsDeployment from '../signals/broadcast/Development.s.sol/31337/run-latest.json'

const resolveDeployment = (name: string) => {
  const idx = signalsDeployment.transactions.findIndex((t) => t.contractName === name)
  return {
    address: getAddress(signalsDeployment.transactions[idx]!.contractAddress),
    startBlock: hexToNumber(signalsDeployment.receipts[idx]!.blockNumber as `0x${string}`),
  }
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
      ...resolveDeployment('SignalsFactory'),
    },
  },
})
