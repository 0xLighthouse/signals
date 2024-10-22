import { kv } from '@vercel/kv'
import { readClient, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { NextResponse } from 'next/server'
import { createPublicClient, getContract, http } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { range } from '@/lib/utils'

export interface NormalisedInitiative {
  initiativeId: number
  title: string
  description: string
  weight: number
  progress: number
  proposer: string
  /**
   * Percentage of the acceptance threshold express as a float
   */
  support: number
  supporters: string[]
  createdAtTimestamp: number
  updatedAtTimestamp: number
  status: 'active' | 'accepted' | 'archived'
}

export interface InitiativeState {
  title: string
  body: string
  state: bigint
  proposer: `0x${string}`
  timestamp: bigint
  lastActivity: bigint
}

const publicClient = createPublicClient({
  chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
})

const ns = `${process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL}-v1`

const mapInitiativeState = (state: number): string => {
  return state === 0 ? 'active' : state === 1 ? 'accepted' : 'archived'
}

const protocol = getContract({
  address: SIGNALS_PROTOCOL,
  abi: SIGNALS_ABI,
  client: readClient,
})

/**
 * GET /api/initiatives
 */
export const GET = async () => {
  const initiativesKey = `${ns}-initiatives`

  const acceptanceThreshold = await protocol.read.acceptanceThreshold()

  const initiativesCount = await readClient.readContract({
    address: SIGNALS_PROTOCOL,
    abi: SIGNALS_ABI,
    functionName: 'count',
    args: [],
  })

  const ids = range(0, Number(initiativesCount) - 1)

  const initiatives: NormalisedInitiative[] = []
  for await (const id of ids) {
    const _initiative = (await readClient.readContract({
      address: SIGNALS_PROTOCOL,
      abi: SIGNALS_ABI,
      functionName: 'getInitiative',
      args: [id],
    })) as InitiativeState

    const weight = await readClient.readContract({
      address: SIGNALS_PROTOCOL,
      abi: SIGNALS_ABI,
      functionName: 'getWeight',
      args: [id],
    })

    const supporters = await protocol.read.getSupporters([id])

    const data = {
      initiativeId: id,
      title: _initiative.title,
      description: _initiative.body,
      weight: Number(weight) / 1e18,
      support: Number(weight) / Number(acceptanceThreshold),
      proposer: _initiative.proposer,
      supporters,
      createdAtTimestamp: Number(_initiative.timestamp),
      updatedAtTimestamp: Number(_initiative.lastActivity),
      status: mapInitiativeState(Number(_initiative.state)),
    } as unknown as NormalisedInitiative
    initiatives.push(data)
  }

  // TODO: Add caching
  // let cachedInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)
  // // Retrieve the entire list of initiatives from the cache
  // const allInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)

  // console.log('allInitattractiveiatives', allInitiatives?.length)

  console.log(JSON.stringify(initiatives, null, 2))

  return NextResponse.json(initiatives)
}
