import { db, publicClients } from 'ponder:api'
import { and, eq } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'

import { transform } from '../utils/transform'
import { SignalsABI } from '../../../../packages/abis'

/**
 * @route GET /bonds/:chainId/:address/:supporter
 */
export const getLocks = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`
  const supporter = c.req.param('supporter').toLowerCase() as `0x${string}`

  const locks = await db.query.Bond.findMany({
    where: and(
      eq(schema.Bond.chainId, Number(chainId)),
      eq(schema.Bond.contractAddress, address),
      eq(schema.Bond.owner, supporter),
    ),
    with: {
      initiative: true,
    },
  })

  // Hydrate the pools with currency info
  const locksWithMetadata = await Promise.all(
    locks.map(async (lock) => {
      const metadata = await publicClients['421614'].readContract({
        address,
        abi: SignalsABI,
        functionName: 'getBondInfo',
        args: [lock.tokenId],
      })

      return {
        ...lock,
        metadata: {
          ...metadata,
        },
      }
    }),
  )

  return c.json({
    data: transform(locksWithMetadata),
  })
}
