import { SIGNALS_PROTOCOL } from '@/config/web3'
import { NextRequest, NextResponse } from 'next/server'
import { createPublicClient, getAddress, http } from 'viem'
import { hardhat } from 'viem/chains'

export interface NormalisedBond {
  initiativeId: number
}

const publicClient = createPublicClient({
  chain: hardhat,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
})

/**
 * GET /api/history?supporter=0xd8da6bf26964af9d7eed9e03e53415d37aa96045
 * - TODO: Rethink this endpoint
 */
export const GET = async (request: NextRequest) => {
  const supporter = request.nextUrl.searchParams.get('supporter')

  if (!supporter) {
    return NextResponse.json({ error: 'Supporter address is required' }, { status: 400 })
  }

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
      name: 'InitiativeSupported',
      inputs: [
        { name: 'initiativeId', type: 'uint256', indexed: true, internalType: 'uint256' },
        { name: 'supporter', type: 'address', indexed: true, internalType: 'address' },
        { name: 'tokenAmount', type: 'uint256', indexed: false, internalType: 'uint256' },
        { name: 'lockDuration', type: 'uint256', indexed: false, internalType: 'uint256' },
        { name: 'timestamp', type: 'uint256', indexed: false, internalType: 'uint256' },
      ],
    },
    // Only get events which I have support for
    args: {
      supporter: getAddress(supporter) as `0x${string}`,
    },
    fromBlock:
      process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev'
        ? 'earliest'
        : BigInt(process.env.NEXT_PUBLIC_PROTOCOL_DEPLOYED_BLOCK!),
    // toBlock: 'latest',
  })

  return NextResponse.json({
    supported: logs.length,
    locked: logs.reduce((acc, log) => acc + Number(log.args.tokenAmount) / 1e18, 0),
    byInitiative: logs.reduce(
      (acc, log) => {
        acc[log.args.initiativeId?.toString() || ''] =
          (acc[log.args.initiativeId?.toString() || ''] || 0) + Number(log.args.tokenAmount) / 1e18
        return acc
      },
      {} as Record<string, number>,
    ),
  })
}
