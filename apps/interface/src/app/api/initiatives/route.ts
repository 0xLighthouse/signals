import { kv } from '@vercel/kv'
import { readClient, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { range } from '@/lib/utils'

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

/**
 * GET /api/initiatives
 */
export const GET = async () => {
  const initiativesKey = `${ns}-initiatives`

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

    const data = {
      initiativeId: id,
      title: _initiative.title,
      description: _initiative.body,
      weight: Number(weight) / 1e18,
      progress: 0,
      proposer: _initiative.proposer,
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
      createdAtTimestamp: Number(_initiative.timestamp),
      updatedAtTimestamp: Number(_initiative.lastActivity),
      status: _initiative.state,
    } as unknown as NormalisedInitiative
    initiatives.push(data)
  }

  // TODO: Add caching
  // let cachedInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)
  // // Retrieve the entire list of initiatives from the cache
  // const allInitiatives = await kv.get<NormalisedInitiative[]>(initiativesKey)

  // console.log('allInitiatives', allInitiatives?.length)

  return NextResponse.json(initiatives)
}
