import { kv } from '@vercel/kv'
import { flatten } from '@/lib/utils'
import { SIGNALS_PROTOCOL } from '@/config/web3'
import { NextRequest, NextResponse } from 'next/server'
import { createPublicClient, getAddress, http } from 'viem'
import { hardhat, arbitrumSepolia } from 'viem/chains'

export interface NormalisedBond {
  initiativeId: number
}

const publicClient = createPublicClient({
  chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
})

const ns = `${process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL}-history`

/**
 * GET /api/history?supporter=0xd8da6bf26964af9d7eed9e03e53415d37aa96045
 * - TODO: Rethink this endpoint
 */
export const GET = async (request: NextRequest) => {
  const supporter = request.nextUrl.searchParams.get('supporter')
  if (!supporter) {
    return NextResponse.json({ error: 'Supporter address is required' }, { status: 400 })
  }

  const lastIndexedBlockKey = `${ns}-${supporter}-last-indexed-block`
  const historyKey = `${ns}-${supporter}-history`
  const BATCH_SIZE = 10_000

  // Get the latest block number
  const blockNumber = await publicClient.getBlockNumber()

  // Get the last indexed block from kv, if not present, use the deployed block
  let lastIndexedBlock = await kv.get<number>(lastIndexedBlockKey)
  if (!lastIndexedBlock) {
    lastIndexedBlock = Number(process.env.NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK)
    // Initialize empty history array in kv
    await kv.set(historyKey, [])
  }

  const fromBlock = lastIndexedBlock + 1

  // Fetch logs in batches of 10000
  const blockRanges = []
  for (let start = fromBlock; start <= Number(blockNumber); start += BATCH_SIZE) {
    const end = Math.min(start + BATCH_SIZE - 1, Number(blockNumber))
    blockRanges.push({ fromBlock: start, toBlock: end })
  }

  console.log('---- ranges')
  console.log(blockRanges)

  for await (const { fromBlock, toBlock } of blockRanges) {
    const logs = await publicClient.getLogs({
      address: SIGNALS_PROTOCOL,
      event: {
        type: 'event',
        name: 'InitiativeSupported',
        inputs: [
          { name: 'initiativeId', type: 'uint256', indexed: true, internalType: 'uint256' },
          { name: 'supporter', type: 'address', indexed: true, internalType: 'address' },
          { name: 'tokenAmount', type: 'uint256', indexed: false, internalType: 'uint256' },
          { name: 'lockDuration', type: 'uint256', indexed: false, internalType: 'uint256' },
          { name: 'timestamp', type: 'uint256', indexed: false, internalType: 'uint256' },
        ],
      },
      args: {
        supporter: getAddress(supporter) as `0x${string}`,
      },
      fromBlock: BigInt(fromBlock),
      toBlock: BigInt(toBlock),
    })

    // Append initiatives to the cache
    let cachedHistory = await kv.get(historyKey)
    if (!cachedHistory) {
      cachedHistory = []
    }
    cachedHistory.push(logs)

    // Store updated initiatives back to cache
    await kv.set(historyKey, cachedHistory)

    // Update last indexed block
    lastIndexedBlock = toBlock
    await kv.set(lastIndexedBlockKey, lastIndexedBlock)
  }

  // Retrieve the entire list of initiatives from the cache
  const allHistory = await kv.get<History>(historyKey)
  const flattenedHistory = flatten(allHistory)

  if (flattenedHistory.length === 0) {
    return NextResponse.json([])
  }

  return NextResponse.json({
    supported: allHistory.length,
    locked: allHistory.reduce((acc, log) => acc + Number(log.args.tokenAmount) / 1e18, 0),
    byInitiative: allHistory.reduce(
      (acc, log) => {
        acc[log.args.initiativeId?.toString() || ''] =
          (acc[log.args.initiativeId?.toString() || ''] || 0) + Number(log.args.tokenAmount) / 1e18
        return acc
      },
      {} as Record<string, number>,
    ),
  })
}
