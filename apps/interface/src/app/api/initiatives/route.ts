import { kv } from '@vercel/kv'
import { readClient, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'

export interface NormalisedInitiative {
  initiativeId: number
  title: string
  description: string
  weight: number
  progress: number
  proposer: string
  supporters: string[]
  createdAtTimestamp: number
  updatedAtTimestamp: number
  status: 'active' | 'accepted' | 'archived'
}

const publicClient = createPublicClient({
  chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
})

const ns = process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL

/**
 * GET /api/initiatives
 */
export const GET = async () => {
  const lastIndexedBlockKey = `${ns}-last-indexed-block`
  const initiativesKey = `${ns}-initiatives`
  const BATCH_SIZE = 10_000

  // Get the latest block number
  const blockNumber = await publicClient.getBlockNumber()

  console.log('blockNumber', blockNumber)

  // Get the last indexed block from kv, if not present, use the deployed block
  let lastIndexedBlock = await kv.get<number>(lastIndexedBlockKey)
  if (!lastIndexedBlock) {
    lastIndexedBlock = Number(process.env.NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK)
    // Initialize empty initiatives array in kv
    await kv.set(initiativesKey, [])
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
    console.log('From: ', fromBlock, 'To: ', toBlock)

    if (toBlock - fromBlock > 10_000) {
      throw new Error('Batch size too large')
    }

    const logs = await publicClient.getLogs({
      address: SIGNALS_PROTOCOL,
      event: {
        type: 'event',
        name: 'InitiativeProposed',
        inputs: [
          { name: 'initiativeId', type: 'uint256', indexed: true, internalType: 'uint256' },
          { name: 'proposer', type: 'address', indexed: true, internalType: 'address' },
          { name: 'title', type: 'string', indexed: false, internalType: 'string' },
          { name: 'body', type: 'string', indexed: false, internalType: 'string' },
        ],
      },
      fromBlock: BigInt(fromBlock),
      toBlock: BigInt(toBlock),
    })

    console.log('---- logs')
    console.log(logs.length)

    // Process logs into initiatives
    const initiatives = await Promise.all(
      logs.map(async (log) => {
        const weight = await readClient.readContract({
          address: SIGNALS_PROTOCOL,
          abi: SIGNALS_ABI,
          functionName: 'getWeight',
          args: [log.args.initiativeId],
        })
        const _initiative = await readClient.readContract({
          address: SIGNALS_PROTOCOL,
          abi: SIGNALS_ABI,
          functionName: 'getInitiative',
          args: [log.args.initiativeId],
        })

        return {
          initiativeId: log.args.initiativeId?.toString(),
          title: log.args.title,
          description: log.args.body,
          weight: Number(weight) / 1e18,
          progress: 0,
          proposer: log.args.proposer,
          supporters: [],
          // @ts-ignore
          createdAtTimestamp: Number(_initiative.timestamp),
          // @ts-ignore
          updatedAtTimestamp: Number(_initiative.lastActivity),
          // @ts-ignore
          status: _initiative.state,
        } as unknown as NormalisedInitiative
      }),
    )

    // Append initiatives to the cache
    let cachedInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)
    if (!cachedInitiatives) {
      cachedInitiatives = []
    }
    cachedInitiatives.push(...initiatives)

    // Store updated initiatives back to cache
    await kv.set(initiativesKey, cachedInitiatives)

    // Update last indexed block
    lastIndexedBlock = toBlock
    await kv.set(lastIndexedBlockKey, lastIndexedBlock)
  }

  // Retrieve the entire list of initiatives from the cache
  const allInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)

  return NextResponse.json(
    allInitiatives?.map((initiative) => ({
      ...initiative,
      id: initiative.initiativeId,
      supporters: [
        '0xAbC1234567890dEf1234567890AbC1234567890A',
        '0xBcD234567890eFg1234567890BcD234567890B1',
        '0xCdE345678901fGh1234567890CdE345678901C2',
        '0xDeF456789012gHi1234567890DeF456789012D3',
        '0xEfG567890123hIj1234567890EfG567890123E4',
        '0xFfG678901234iJk1234567890FfG678901234F5',
        '0x1234567890AbC1234567890dEf1234567890A6',
        '0x234567890BcD234567890eFg1234567890B1A7',
        '0x345678901CdE345678901fGh1234567890C2B8',
        '0x456789012DeF456789012gHi1234567890D3C9',
      ],
      status: 'active',
    })),
  )
}
