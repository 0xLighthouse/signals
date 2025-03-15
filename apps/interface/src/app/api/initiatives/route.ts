import {
  INCENTIVES,
  INCENTIVES_ABI,
  readClient,
  SIGNALS_ABI,
  SIGNALS_PROTOCOL,
} from '@/config/web3'
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
  rewards: number
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
  client: publicClient,
})

const incentives = getContract({
  address: INCENTIVES,
  abi: INCENTIVES_ABI,
  client: publicClient,
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

  console.log('initiativesCount', ids)
  console.log('SIGNALS_PROTOCOL_ADDRESS', SIGNALS_PROTOCOL)

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

    const _incentives = await incentives.read.getIncentives([Number(id)])
    // @ts-ignore
    const rewards = _incentives[1].reduce((acc: bigint, amount: bigint) => acc + amount, 0n)

    console.log(_incentives)

    const data = {
      initiativeId: id,
      title: _initiative.title,
      description: _initiative.body,
      weight: Number(weight) / 1e18,
      support: Number(weight) / Number(acceptanceThreshold),
      proposer: _initiative.proposer,
      rewards: Number(rewards) / 1e6,
      supporters,
      createdAtTimestamp: Number(_initiative.timestamp),
      updatedAtTimestamp: Number(_initiative.lastActivity),
      status: mapInitiativeState(Number(_initiative.state)),
    } as unknown as NormalisedInitiative
    initiatives.push(data)
  }

  return NextResponse.json(initiatives)
}
