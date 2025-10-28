import { db, publicClients } from 'ponder:api'
import { and, eq } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'
import { SignalsABI } from '../../../../packages/abis'
import { transform } from '../utils/transform'

export const getInitiatives = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`

  const board = await db.query.Board.findFirst({
    where: and(
      eq(schema.Board.chainId, Number(chainId)),
      eq(schema.Board.contractAddress, address),
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

  const records = await db.query.Initiative.findMany({
    where: and(
      eq(schema.Initiative.chainId, Number(chainId)),
      eq(schema.Initiative.contractAddress, address),
    ),
  })

  const initiatives = await Promise.all(
    records.map(async (initiative) => {
      // const supporters = await db.query.Weight.findMany({
      //   where: eq(schema.Weight.initiativeId, initiative.initiativeId),
      // })

      const initiativeState = await publicClients['421614'].readContract({
        address: initiative.contractAddress,
        abi: SignalsABI,
        functionName: 'getInitiative',
        args: [BigInt(initiative.initiativeId)],
      }) as {
        state: number
        attachments: { uri: string; mimeType: string; description: string }[]
      }

      const onchainAttachments = initiativeState.attachments ?? []
      const attachments = onchainAttachments.length
        ? onchainAttachments
        : (initiative.attachments as { uri: string; mimeType: string; description: string }[])

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

      const weight = await publicClients['421614'].readContract({
        address: initiative.contractAddress,
        abi: SignalsABI,
        functionName: 'getWeight',
        args: [BigInt(initiative.initiativeId)],
      })

      const supporters = await publicClients['421614'].readContract({
        address: initiative.contractAddress,
        abi: SignalsABI,
        functionName: 'getSupporters',
        args: [BigInt(initiative.initiativeId)],
      })

      const _incentives = await db.query.Incentive.findMany({
        where: eq(schema.Incentive.initiativeId, BigInt(initiative.initiativeId)),
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
        support: Number(weight) / Number(board.acceptanceThreshold),
        proposer: initiative.proposer,
        rewards: Number(rewards) / 1e6,
        supporters,
        createdAtTimestamp: Number(initiative.blockTimestamp),
        updatedAtTimestamp: Number(initiative.blockTimestamp),
        attachments,
        status,
      }
    }),
  )

  return c.json({
    version: '0.1.0',
    initiatives: transform(initiatives),
  })
}
