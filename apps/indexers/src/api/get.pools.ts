import { db, publicClients } from 'ponder:api'
import { and, eq, or } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'

import { transform } from '../utils/transform'

/**
 * @route GET /pools/:chainId/:currency
 */
export const getPools = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const currency = c.req.param('currency').toLowerCase() as `0x${string}`

  const pools = await db.query.Pool.findMany({
    where: and(
      eq(schema.Pool.chainId, Number(chainId)),
      or(eq(schema.Pool.currency0, currency), eq(schema.Pool.currency1, currency)),
    ),
  })

  return c.json({
    data: transform(pools),
  })
}
