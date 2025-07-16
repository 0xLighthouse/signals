import { Position, Pool } from '@uniswap/v4-sdk'
import { Token } from '@uniswap/sdk-core'
import { Pool as IndexedPool } from '@/indexers/api/types'
import { INDEXER_ENDPOINT } from '@/config/web3'
import { arbitrumSepolia } from 'viem/chains'
import { hexToNumber } from 'viem'

export type CurrencyType = 'Currency0' | 'Currency1'

interface PoolState {
  sqrtRatioX96: number
  tickCurrent: number
  liquidity: number
}

const fetchPoolState = async (poolId: string): Promise<PoolState> => {
  const response = await fetch(`${INDEXER_ENDPOINT}/pool-state/${arbitrumSepolia.id}/${poolId}`)
  const { data } = await response.json()
  return data
}

export const toUniswapPool = async (indexedPool: IndexedPool) => {
  const currencyA = new Token(
    indexedPool.chainId,
    indexedPool.currency0.address,
    indexedPool.currency0.decimals,
    indexedPool.currency0.symbol,
    indexedPool.currency0.name,
  )
  const currencyB = new Token(
    indexedPool.chainId,
    indexedPool.currency1.address,
    indexedPool.currency1.decimals,
    indexedPool.currency1.symbol,
    indexedPool.currency1.name,
  )

  const fee = hexToNumber('0x800000') // Dynamic fee flag
  const tickSpacing = 60

  const poolState = await fetchPoolState(indexedPool.poolId)

  const hooks = indexedPool.hookAddress as `0x${string}`
  const sqrtRatioX96 = poolState.sqrtRatioX96
  const tickCurrent = poolState.tickCurrent
  const liquidity = poolState.liquidity

  console.log('sqrtRatioX96', sqrtRatioX96)
  console.log('tickCurrent', tickCurrent)
  console.log('liquidity', liquidity)

  const pool = new Pool(
    currencyA,
    currencyB,
    fee,
    tickSpacing,
    hooks,
    sqrtRatioX96,
    liquidity,
    tickCurrent,
  )

  return {
    pool,
    currency0: pool.token0,
    currency1: pool.token1,
  }
}

interface ICalculateLiquidity {
  pool: Pool
  amount: number
  sourceCurrency: CurrencyType
  range: {
    tickLower: number
    tickUpper: number
  }
}

interface ICalculateLiquidityResult {
  amountA: number
  amountB: number
  liquidityDelta: number
}

export const calculateLiquidity = ({
  pool,
  amount,
  sourceCurrency,
  range,
}: ICalculateLiquidity): ICalculateLiquidityResult => {
  let position: Position
  if (sourceCurrency === 'Currency0') {
    position = Position.fromAmount0({
      amount0: amount * 10 ** pool.currency0.decimals,
      pool: pool,
      tickLower: range.tickLower,
      tickUpper: range.tickUpper,
      useFullPrecision: true,
    })
  } else {
    position = Position.fromAmount1({
      amount1: amount * 10 ** pool.currency1.decimals,
      pool: pool,
      tickLower: range.tickLower,
      tickUpper: range.tickUpper,
    })
  }

  return {
    amountA: Number(position.amount0.toFixed(6)),
    amountB: Number(position.amount1.toFixed(6)),
    liquidityDelta: Number(position.liquidity),
  }
}
