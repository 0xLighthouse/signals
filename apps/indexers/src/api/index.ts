import { db, publicClients } from 'ponder:api'
import schema from 'ponder:schema'
import { Hono } from 'hono'
import { client, graphql } from 'ponder'
import { and, eq } from 'drizzle-orm'
import { transform } from '../utils/transform'
import { SignalsABI } from '../../../../packages/abis'

const app = new Hono()

app.use('/sql/*', client({ db, schema }))

app.use('/', graphql({ db, schema }))
app.use('/graphql', graphql({ db, schema }))

/**
 * @returns List initiatives for a given chainId and address
 * @example http://localhost:42069/initiatives/421614/0x844c0dd2995cd430aab7ddd1dca3fb15836674bc
 */
app.get('/initiatives/:chainId/:address', async (c) => {
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
      })

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

      // const _incentives = await publicClients['421614'].readContract({
      //   address: initiative.contractAddress,
      //   abi: IncentivesABI,
      //   functionName: 'getIncentives',
      //   args: [BigInt(initiative.initiativeId)],
      // })
      // const rewards = _incentives[1].reduce((acc: bigint, amount: bigint) => acc + amount, 0n)

      return {
        initiativeId: initiative.initiativeId,
        title: initiative.title,
        description: initiative.body,
        weight: Number(weight) / 1e18,
        support: Number(weight) / Number(board.acceptanceThreshold),
        proposer: initiative.proposer,
        rewards: 0,
        // rewards: Number(rewards) / 1e6,
        supporters,
        createdAtTimestamp: Number(initiative.blockTimestamp),
        updatedAtTimestamp: Number(initiative.blockTimestamp),
        status: initiativeState,
      }
    }),
  )

  return c.json({
    version: '0.1.0',
    initiatives: transform(initiatives),
  })
})

export default app
