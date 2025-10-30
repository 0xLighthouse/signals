import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { getAddress, hexToNumber } from 'viem'

export const resolveDeployment = (name: string, metadataOrPath: any) => {
  // Load JSON file if a string path is provided
  const metadata = typeof metadataOrPath === 'string'
    ? JSON.parse(readFileSync(join(process.cwd(), '../../', metadataOrPath), 'utf-8'))
    : metadataOrPath

  const idx = metadata.transactions.findIndex(
    (t: any) => t.contractName === name && t.transactionType === 'CREATE',
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
