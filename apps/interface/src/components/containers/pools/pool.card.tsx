import React from 'react'
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { cn, formatNumber, shortAddress } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Droplets, Info, Tag, TrendingUp, Webhook } from 'lucide-react'
import { ProvideLiquidityDrawer } from '@/components/drawers/provide-liquidity-drawer'
import { useUnderlying } from '@/contexts/ContractContext'
import { Pool } from '@/indexers/api/types'

interface Props {
  pool: Pool
  index: number
  isFirst: boolean
  isLast: boolean
  userLiquidity?: number
}

export const PoolCard: React.FC<Props> = ({ pool, isFirst, isLast, userLiquidity = 0 }) => {
  // Mock data for APR and total value locked
  const apr = 42069 // pool.apr || 5.2
  const poolTVL = pool.currency0.totalTVL + pool.currency1.totalTVL
  const { address: underlyingAddress, symbol: underlyingSymbol } = useUnderlying()
  
  // Calculate user's share of the pool
  const userShare = userLiquidity > 0 ? (userLiquidity / poolTVL) * 100 : 0
  
  const pairTitle = pool.currency0.address === underlyingAddress ? `${pool.currency0.symbol}/${pool.currency1.symbol}` : `${pool.currency1.symbol}/${pool.currency0.symbol}`
  
  const nonUnderlying = pool.currency0.address === underlyingAddress ? pool.currency1 : pool.currency0
  const percentManaged = (nonUnderlying.bondHookTVL / nonUnderlying.totalTVL) * 100
  
  return (
    <Card
      className={cn(
        'flex flex-col',
        isFirst
          ? 'rounded-t-lg rounded-b-none border-b-0'
          : isLast
            ? 'rounded-b-lg rounded-t-none'
            : 'rounded-none border-b-0',
      )}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <CardTitle className="flex items-center gap-2">
            <div className="bg-blue-100 dark:bg-blue-900 p-2 rounded-lg">
              <Droplets className="h-5 w-5 text-blue-600 dark:text-blue-400" />
            </div>
            {pairTitle} Pool
          </CardTitle>
          <CardDescription className="flex items-center text-xs gap-2">
            <span>{pool.version}</span>
            <span>•</span>
            <span>Fee rate: {pool.formattedSwapFee}%</span>
          </CardDescription>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-2 h-[80px] items-center">
            <ProvideLiquidityDrawer />
          </div>
        </div>
      </div>

      <div className="flex justify-between p-6 pt-2">
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <Tag className="h-4 w-4 text-green-600" />
            <span className="text-sm font-medium">
              TVL: {formatNumber(nonUnderlying.totalTVL, { currency: true, abbreviate: true, decimals: 2, symbol: nonUnderlying.symbol, wad: nonUnderlying.decimals })}
            </span>
            <span className="text-sm font-medium">
            </span>
          </div>

          <div className="flex items-center gap-2">
            <Webhook className="h-4 w-4 text-pink-600" />
            <span className="text-sm font-medium">
              Managed: {formatNumber(nonUnderlying.bondHookTVL, { currency: true, abbreviate: true, decimals: 2, symbol: nonUnderlying.symbol, wad: nonUnderlying.decimals })}
            </span>
            { percentManaged < 100 && (
              <span className="text-sm font-medium">({percentManaged}%)</span>
            )}
          </div>

          <CardDescription className="text-xs mt-1 flex items-center gap-1">
            <Info className="h-3 w-3" />
            {userLiquidity > 0 ? (
              <>
                Your share: {userShare.toFixed(2)}% (
                {formatNumber(userLiquidity, { currency: true })})
              </>
            ) : (
              <>You have no liquidity in this pool</>
            )}
          </CardDescription>
        </div>

        {userLiquidity > 0 && (
          <div className="flex gap-2 items-center">
            <Button variant="outline" size="sm">
              Withdraw
            </Button>
          </div>
        )}
      </div>
    </Card>
  )
}
