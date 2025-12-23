import { db } from 'ponder:api'
import { and, eq } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'
import { transform } from '../utils/transform'
import { InitiativeLock } from './types'

// GET /locks/account/:chainId/:address/:accountAddress
export const getAccountLocks = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`
  const accountAddress = c.req.param('accountAddress').toLowerCase() as `0x${string}`

  const locks = await db.query.Lock.findMany({
    where: and(
      eq(schema.Lock.chainId, Number(chainId)),
      eq(schema.Lock.contractAddress, address),
      eq(schema.Lock.owner, accountAddress),
    ),
    with: {
      initiative: true,
    },
  })

  const data = locks.map((lock): InitiativeLock => {
    const initiativeState = lock.initiative?.state
    const isRedeemable =
      initiativeState === 'Accepted' || initiativeState === 'Cancelled'

    return {
      initiative: {
        ...lock.initiative,
      },
      initiativeId: lock.initiativeId,
      tokenId: lock.tokenId,
      nominalValue: lock.nominalValue,
      durationAsIntervals: lock.durationAsIntervals,
      createdAt: lock.blockTimestamp,
      isRedeemed: lock.burnedAt !== null,
      isRedeemable,
      redeemedTxnHash: lock.burnedTransactionHash ?? null,
    }
  })

  return c.json({
    data: transform(data),
  })
}
