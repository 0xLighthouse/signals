import { db, publicClients } from 'ponder:api'
import { Context } from 'hono'
import { SignalsABI } from '../../../../packages/abis'
import { transform } from '../utils/transform'
import { getClientByChainId } from '../utils/get-client-by-chain-id'
import { erc20Abi } from 'viem'

export const getInitiatives = async (c: Context) => {
  const chainId = Number(c.req.param('chainId'))
  const address = c.req.param('address').toLowerCase() as `0x${string}`

  const board = await db.query.Board.findFirst({
    where: (board, { eq, and }) => and(
      eq(board.chainId, chainId),
      eq(board.contractAddress, address),
    ),
  })

  if (!board) {
    return c.json(
      {
        error: 'Board not found',
      },
      404,
    )
  }

  const client = getClientByChainId(publicClients, chainId)
  if (!client) {
    return c.json({ error: `Unsupported chainId: ${chainId}` }, 400)
  }

  const records = await db.query.Initiative.findMany({
    where: (initiative, { eq, and }) => and(
      eq(initiative.chainId, Number(chainId)),
      eq(initiative.contractAddress, address),
    ),
  })

  // Fetch total supply of underlying token
  const totalSupply = await client.readContract({
    address: board.underlyingToken,
    abi: erc20Abi,
    functionName: 'totalSupply',
  }) as bigint

  const initiatives = await Promise.all(
    records.map(async (initiative) => {
      const initiativeState = (await client.readContract({
        address: initiative.contractAddress,
        abi: SignalsABI,
        functionName: 'getInitiative',
        args: [BigInt(initiative.initiativeId)],
      })) as {
        state: number
        proposer: `0x${string}`
        timestamp: bigint
        lastActivity: bigint
        acceptanceTimestamp: bigint
      }

      const status = (() => {
        switch (initiativeState.state) {
          case 1:
            return 'accepted' as const
          case 0:
            return 'active' as const
          default:
            return 'archived' as const
        }
      })()

      const weight = await client.readContract({
        address: initiative.contractAddress,
        abi: SignalsABI,
        functionName: 'getWeight',
        args: [BigInt(initiative.initiativeId)],
      }) as bigint

      const locks = await db.query.Lock.findMany({
        where: (lock, { and, eq }) =>
          and(
            eq(lock.chainId, chainId),
            eq(lock.contractAddress, address),
            eq(lock.initiativeId, BigInt(initiative.initiativeId)),
            eq(lock.isActive, true),
          ),
      })

      const _incentives = await db.query.Incentive.findMany({
        where: (incentiveRow, { eq }) => eq(incentiveRow.initiativeId, BigInt(initiative.initiativeId)),
      })

      let rewards = 0n
      for (const incentive of _incentives) {
        rewards += incentive.amount
      }

      return {
        initiativeId: initiative.initiativeId,
        title: initiative.title,
        description: initiative.body,
        weight: Number(weight) / 1e18,
        support: calculateSupport(weight, totalSupply, board.acceptanceCriteria.thresholdPercentTotalSupplyWAD, board.acceptanceCriteria.minThreshold),
        proposer: initiativeState.proposer ?? initiative.proposer,
        rewards: Number(rewards) / 1e6,
        supporters: Array.from(new Set(locks.map((lock) => lock.owner))),
        createdAtTimestamp: Number(initiativeState.timestamp ?? initiative.blockTimestamp),
        updatedAtTimestamp: Number(initiativeState.lastActivity ?? initiative.blockTimestamp),
        attachments: initiative.attachments as { uri: string; mimeType: string; description: string }[],
        status,
      }
    }),
  )

  return c.json({
    version: '0.1.0',
    initiatives: transform(initiatives),
  })
}

/**
 * Current support for an initiative, expressed as a percentage
 */
const calculateSupport = (weight: bigint, totalSupply: bigint, thresholdPercentTotalSupplyWAD: string, minThreshold: string) => {
  const percentThreshold = Number(totalSupply) * (Number(thresholdPercentTotalSupplyWAD) / 1e18)
  return Number(weight) / Math.max(percentThreshold, Number(minThreshold))
}
