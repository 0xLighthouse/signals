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

/**
 * GET /api/initiatives
 */
export const GET = async () => {
  // TODO: Optimise how we scan events
  if (
    process.env.NEXT_PUBLIC_SIGNALS_ENV !== 'dev' &&
    !process.env.NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK
  ) {
    return NextResponse.json(
      { error: '[NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK] not set' },
      { status: 500 },
    )
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
    fromBlock:
      process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev'
        ? 'earliest'
        : BigInt(process.env.NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK!),
    // toBlock: 'latest',
  })

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
      }
    }),
  )

  return NextResponse.json(initiatives)
}
