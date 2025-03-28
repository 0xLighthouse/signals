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
        selectedPoolId === pool.poolId ? 'border-neutral-500' : 'hover:border-neutral-500/50'
      }`}
      onClick={() => handleOnClick(pool.poolId)}
    >
      <div className="flex flex-col gap-2">
        <h3 className="font-bold">
          {pool.currency0.symbol}/{pool.currency1.symbol} Pool{' '}
          <span className="text-xs bg-blue-500/10 px-1.5 py-0.5 rounded-md text-blue-500">
            {pool.version}
          </span>
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
