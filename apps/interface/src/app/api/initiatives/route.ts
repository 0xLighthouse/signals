import { readClient, SIGNALS_PROTOCOL } from '@/config/web3'
import { NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'
import { hardhat } from 'viem/chains'

export interface NormalisedInitiative {
  initiativeId: number
  title: string
  description: string
  weight: number
  proposer: string
  supporters: string[]
  createdAtTimestamp: number
  status: 'active' | 'accepted' | 'archived'
}

export const publicClient = createPublicClient({
  chain: hardhat,
  transport: http(process.env.RPC_URL!),
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
    toBlock: 'latest',
  })

  const initiatives = await Promise.all(
    logs.map(async (log) => {
      const block = await readClient.getBlock({ blockNumber: log.blockNumber })
      return {
        initiativeId: log.args.initiativeId?.toString(),
        title: log.args.title,
        description: log.args.body,
        weight: 0,
        proposer: log.args.proposer,
        supporters: [],
        createdAtTimestamp: Number(block.timestamp),
        status: 'TODO',
      }
    }),
  )

  console.log(initiatives)

  return NextResponse.json(initiatives)
}
