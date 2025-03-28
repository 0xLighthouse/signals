import { publicClients } from 'ponder:api'
import { Context } from 'hono'

import { transform } from '../utils/transform'
import { BondHookABI } from '../../../../packages/abis'

/**
 * @route GET /quote/:chainId/:address/:tokenId?type=user-sell|user-buy
 */
export const getQuote = async (c: Context) => {
  const chainId = c.req.param('chainId')
  const address = c.req.param('address').toLowerCase() as `0x${string}`
  const tokenId = c.req.param('tokenId')
  const type = c.req.query('type')

  const quote = await publicClients['421614'].readContract({
    address,
    abi: BondHookABI,
    functionName: type === 'user-sell' ? 'getPoolBuyPrice' : 'getPoolSellPrice',
    args: [BigInt(tokenId)],
  })

  return c.json({
    data: {
      quoteInUnderlying: transform(quote),
    },
  })
}
