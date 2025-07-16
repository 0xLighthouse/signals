import { db, publicClients } from 'ponder:api'
import { and, eq, or } from 'drizzle-orm'
import schema from 'ponder:schema'
import { Context } from 'hono'
// import { tickToPrice } from '@uniswap/v4-sdk'

import { transform } from '../utils/transform'
import { BondHookABI, Erc20ABI, StateViewABI } from '../../../../packages/abis'

/**
 * @route GET /pool-state/:chainId/:poolId
 */
export const getPoolState = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const poolId = c.req.param('poolId').toLowerCase() as `0x${string}`

  const getPoolInfo = async (poolId: `0x${string}`) => {
    const stateViewContractArbSepolia = '0x9d467fa9062b6e9b1a46e26007ad82db116c67cb'

    // {
    //   type: 'function',
    //   inputs: [{ name: 'poolId', internalType: 'PoolId', type: 'bytes32' }],
    //   name: 'getSlot0',
    //   outputs: [
    //     { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
    //     { name: 'tick', internalType: 'int24', type: 'int24' },
    //     { name: 'protocolFee', internalType: 'uint24', type: 'uint24' },
    //     { name: 'lpFee', internalType: 'uint24', type: 'uint24' },
    //   ],
    //   stateMutability: 'view',
    // },
    const [slot0, liquidity] = await Promise.all([
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
    ])

    return {
      sqrtRatioX96: slot0[0], // Same as sqrtPriceX96
      tickCurrent: slot0[1],
      liquidity,
    }
  }

  const poolState = await getPoolInfo(poolId)

  return c.json({
    data: transform(poolState),
  })
}
