import { db, publicClients } from 'ponder:api'
import { and, eq } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'

import { transform } from '../utils/transform'

/**
 * @route GET /locks/:chainId/:address/:supporter
 */
export const getLocks = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`
  const supporter = c.req.param('supporter').toLowerCase() as `0x${string}`

  const locks = await db.query.InitiativeWeight.findMany({
    where: and(
      eq(schema.InitiativeWeight.chainId, Number(chainId)),
      eq(schema.InitiativeWeight.contractAddress, address),
      eq(schema.InitiativeWeight.supporter, supporter),
    ),
    with: {
      initiative: true,
    },
  })

  return c.json({
    data: transform(locks),
  })
}
