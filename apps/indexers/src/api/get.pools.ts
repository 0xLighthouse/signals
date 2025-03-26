import { db, publicClients } from 'ponder:api'
import { and, eq, or } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'
// import { tickToPrice } from '@uniswap/v4-sdk'

import { transform } from '../utils/transform'
import { BondHookABI, Erc20ABI, StateViewABI } from '../../../../packages/abis'

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

  const getPoolInfo = async (poolId: `0x${string}`) => {
    const stateViewContractArbSepolia = '0x9d467fa9062b6e9b1a46e26007ad82db116c67cb'
    const bondHookContractArbSepolia = '0xA429a75F874B899Ee6b0ea080d7281544506b8c0'

    const [bondPoolState] = await Promise.all([
      publicClients['421614'].readContract({
        address: bondHookContractArbSepolia,
        abi: BondHookABI,
        functionName: 'getPoolState',
        args: [poolId],
      }),
    ])

    bondPoolState.normalSwapFee

    const [slot0, poolLiquidity, positionLiquidity] = await Promise.all([
      publicClients['421614'].readContract({
        address: stateViewContractArbSepolia,
        abi: StateViewABI,
        functionName: 'getSlot0',
        args: [poolId],
      }),
      publicClients['421614'].readContract({
        address: stateViewContractArbSepolia,
        abi: StateViewABI,
        functionName: 'getLiquidity',
        args: [poolId],
      }),
      publicClients['421614'].readContract({
        address: stateViewContractArbSepolia,
        abi: StateViewABI,
        functionName: 'getPositionLiquidity',
        args: [poolId, bondPoolState.positionId],
      }),
    ])

    const [underlyingAmountForPoolLiquidity, underlyingAmountForPositionLiquidity] =
      await Promise.all([
        publicClients['421614'].readContract({
          address: bondHookContractArbSepolia,
          abi: BondHookABI,
          functionName: 'getUnderlyingAmountForLiquidity',
          args: [poolId, poolLiquidity],
        }),
        publicClients['421614'].readContract({
          address: bondHookContractArbSepolia,
          abi: BondHookABI,
          functionName: 'getUnderlyingAmountForLiquidity',
          args: [poolId, positionLiquidity],
        }),
      ])

    const price = Number(slot0[0]) ** 2 / 2 ** 192

    let totalTVL0: number
    let totalTVL1: number
    let positionTVL0: number
    let positionTVL1: number

    if (bondPoolState.underlyingIsCurrency0) {
      totalTVL0 = Number(underlyingAmountForPoolLiquidity)
      totalTVL1 = totalTVL0 * price
      positionTVL0 = Number(underlyingAmountForPositionLiquidity)
      positionTVL1 = positionTVL0 * price
    } else {
      totalTVL1 = Number(underlyingAmountForPoolLiquidity)
      totalTVL0 = totalTVL1 / price
      positionTVL1 = Number(underlyingAmountForPositionLiquidity)
      positionTVL0 = positionTVL1 / price
    }

    return {
      price,
      totalTVL0,
      totalTVL1,
      positionTVL0,
      positionTVL1,
      swapFee: bondPoolState.normalSwapFee, // TODO: We should use the swap fee from the pool
      formattedSwapFee: bondPoolState.normalSwapFee / 100_0000,
    }
  }

  // Hydrate the pools with currency info
  const poolsWithCurrencyInfo = await Promise.all(
    pools.map(async (pool) => {
      const [currency0Info, currency1Info] = await Promise.all([
        getCurrencyInfo(pool.currency0),
        getCurrencyInfo(pool.currency1),
      ])

      const { price, totalTVL0, totalTVL1, positionTVL0, positionTVL1, swapFee, formattedSwapFee } =
        await getPoolInfo(pool.poolId)

      return {
        ...pool,
        poolId: pool.poolId.toString(),
        version: 'v4',
        swapPrice: price,
        swapFee,
        formattedSwapFee,
        currency0: {
          ...currency0Info,
          totalTVL: totalTVL0,
          bondHookTVL: positionTVL0,
        },
        currency1: {
          ...currency1Info,
          totalTVL: totalTVL1,
          bondHookTVL: positionTVL1,
        },
      }
    }),
  )

  return c.json({
    data: transform(poolsWithCurrencyInfo),
  })
}
