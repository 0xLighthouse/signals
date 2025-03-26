import { db, publicClients } from 'ponder:api'
import { and, eq, or } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'

import { transform } from '../utils/transform'
import { Erc20ABI } from '../../../../packages/abis'

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

  const getCurrencyInfo = async (address: `0x${string}`) => {
    const [symbol, name, decimals] = await Promise.all([
      publicClients['421614'].readContract({
        address,
        abi: Erc20ABI,
        functionName: 'symbol',
      }),
      publicClients['421614'].readContract({
        address,
        abi: Erc20ABI,
        functionName: 'name',
      }),
      publicClients['421614'].readContract({
        address,
        abi: Erc20ABI,
        functionName: 'decimals',
      }),
    ])

    return {
      address,
      symbol,
      name,
      decimals,
    }
  }

  // Hydrate the pools with currency info
  const poolsWithCurrencyInfo = await Promise.all(
    pools.map(async (pool) => {
      const [currency0Info, currency1Info] = await Promise.all([
        getCurrencyInfo(pool.currency0),
        getCurrencyInfo(pool.currency1),
      ])

      return {
        ...pool,
        currency0: {
          ...currency0Info,
        },
        currency1: {
          ...currency1Info,
        },
      }
    }),
  )

  return c.json({
    data: transform(poolsWithCurrencyInfo),
  })
}
