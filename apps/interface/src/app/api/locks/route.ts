import { kv } from '@vercel/kv'
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

const ns = `${process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL}-locks-v1`

export interface InitiativeSupportedEvent {
  initiativeId: number
  supporter: string
  tokenAmount: number
  lockDuration: number
  timestamp: number
  isWithdrawn: boolean
}

/**
 * GET /api/locks?initiativeId=1
 */
export const GET = async (request: NextRequest) => {
  const initiativeId = request.nextUrl.searchParams.get('initiativeId')
  if (!initiativeId) {
    return NextResponse.json({ error: 'Initiative ID is required' }, { status: 400 })
  }

  const lastIndexedBlockKey = `${ns}-${initiativeId}-last-indexed-block`
  const historyKey = `${ns}-${initiativeId}-locks`
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
        initiativeId: BigInt(initiativeId),
      },
      fromBlock: BigInt(fromBlock),
      toBlock: BigInt(toBlock),
    })

    // TODO: Check if the lock has been withdrawn
    // TODO: Check if the lock has been withdrawn
    const initiativesSupported = logs.map((log) => ({
      initiativeId: Number(log.args.initiativeId),
      supporter: log.args.supporter,
      tokenAmount: Number(log.args.tokenAmount) / 1e18, // TODO; Should be based on contract/underlying token decimals
      lockDuration: Number(log.args.lockDuration),
      timestamp: Number(log.args.timestamp),
      isWithdrawn: false,
    }))

    // Append initiatives to the cache
    let cachedHistory = await kv.get<InitiativeSupportedEvent[]>(historyKey)
    if (!cachedHistory) {
      cachedHistory = []
    }
    // Store updated initiatives back to cache
    await kv.set(historyKey, [...cachedHistory, ...initiativesSupported])

    // Update last indexed block
    lastIndexedBlock = toBlock
    await kv.set(lastIndexedBlockKey, lastIndexedBlock)
  }

  // Retrieve the entire list of initiatives from the cache
  const allLocks = await kv.get<InitiativeSupportedEvent[]>(historyKey)

  // console.log('----- ALL HISTORY -----')
  console.log(allLocks)

  if (allLocks?.length === 0) {
    return NextResponse.json([])
  }

  return NextResponse.json(allLocks)
}
