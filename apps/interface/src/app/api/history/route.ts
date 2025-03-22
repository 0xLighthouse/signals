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

const ns = `${process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL}-history-v1`

interface InitiativeSupported {
  initiativeId: number
  supporter: string
  tokenAmount: number
  lockDuration: number
  timestamp: number
}

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

  // TODO: Get list of initiatives this user has supported
  return NextResponse.json({
    supported: 0,
    locked: 0,
    byInitiative: {},
  })

  // // Retrieve the entire list of initiatives from the cache
  // const allHistory = await kv.get<InitiativeSupported[]>(historyKey)

  // // console.log('----- ALL HISTORY -----')
  // // console.log(allHistory)

  // if (allHistory?.length === 0) {
  //   return NextResponse.json({
  //     supported: 0,
  //     locked: 0,
  //     byInitiative: {},
  //   })
  // }

  // return NextResponse.json({
  //   // @ts-ignore
  //   supported: allHistory.length,
  //   // @ts-ignore
  //   locked: allHistory.reduce((acc, log) => acc + log.tokenAmount, 0),
  //   // @ts-ignore
  //   byInitiative: allHistory.reduce((acc, log) => {
  //     // @ts-ignore
  //     acc[log.initiativeId.toString()] = (acc[log.initiativeId.toString()] || 0) + log.tokenAmount
  //     return acc
  //   }, {}),
  // })
}
