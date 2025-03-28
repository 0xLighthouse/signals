import { db } from 'ponder:api'
import { and, eq } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'
import { transform } from '../utils/transform'
import { InitiativeLock } from './types'

// GET /locks/:chainId/:address/:initiativeId
export const getInitiativeLocks = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`
  const initiativeId = c.req.param('initiativeId')

  const locks = await db.query.Bond.findMany({
    where: and(
      eq(schema.Bond.chainId, Number(chainId)),
      eq(schema.Bond.contractAddress, address),
      eq(schema.Bond.initiativeId, BigInt(initiativeId)),
    ),
  })

  const data = await Promise.all(
    locks.map((lock): InitiativeLock => {
      return {
        initiativeId: lock.initiativeId,
        tokenId: lock.tokenId,
        nominalValue: lock.nominalValue,
        durationAsIntervals: lock.durationAsIntervals,
        createdAt: lock.blockTimestamp,
        isRedeemed: lock.burnedAt !== null,
      }
    }),
  )

  return c.json({
    data: transform(data),
  })
}
