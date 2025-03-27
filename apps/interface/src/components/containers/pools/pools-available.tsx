import { Card } from '@/components/ui/card'
import { Pool } from '@/indexers/api/types'

export const PoolsAvailable = ({
  pools,
  selectedPoolId,
  handleOnClick,
}: {
  pools: Pool[]
  selectedPoolId?: string
  handleOnClick: (poolId: string) => void
}) => {
  return pools.map((pool) => (
    <Card
      key={pool.poolId}
      className={`p-4 cursor-pointer transition-colors ${
        selectedPoolId === pool.poolId ? 'border-blue-500' : 'hover:border-blue-500/50'
      }`}
      onClick={() => handleOnClick(pool.poolId)}
    >
      <div className="flex flex-col gap-2">
        <h3 className="font-bold">
          {pool.currency0.symbol}/{pool.currency1.symbol} Pool {pool.version}
        </h3>
        <div className="text-sm text-muted-foreground">
          <div>
            {pool.currency0.symbol}/{pool.currency1.symbol}
          </div>
        </div>
      </div>
    </Card>
  ))
}
