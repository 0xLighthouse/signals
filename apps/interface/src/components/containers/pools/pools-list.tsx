'use client'

import { useEffect } from 'react'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { PageSection } from '@/components/page-section'
import { PoolCard } from './pool.card'

export const PoolsList = () => {
  const pools = usePoolsStore((state) => state.pools)
  const isFetchingPools = usePoolsStore((state) => state.isFetching)
  const fetchPools = usePoolsStore((state) => state.fetchPools)
  const isInitialized = usePoolsStore((state) => state.isInitialized)

  console.log(pools)

  useEffect(() => {
    if (!isInitialized) fetchPools()
  }, [isInitialized, fetchPools])

  if (isFetchingPools) {
    return <LoadingSpinner />
  }

  // If we have no pools, show empty state
  if (pools.length === 0) {
    return (
      <ListContainer title="Liquidity Pools">
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No liquidity pools found</h3>
            <p className="text-neutral-500 dark:text-neutral-400">
              There are currently no active liquidity pools.
            </p>
          </div>
        </PageSection>
        <InformationSection />
      </ListContainer>
    )
  }

  return (
    <ListContainer title="Liquidity Pools">
      {pools.map((pool, index) => (
        <PoolCard
          key={pool.poolId}
          pool={pool}
          index={index}
          isFirst={index === 0}
          isLast={index === pools.length - 1}
        />
      ))}

      <InformationSection />
    </ListContainer>
  )
}

// Extract the information section into its own component for reuse
const InformationSection = () => (
  <PageSection className="bg-neutral-50 dark:bg-neutral-900">
    <h3 className="text-lg font-medium mb-4">About Providing Liquidity</h3>
    <ul className="list-disc pl-5 space-y-2">
      <li>Provide liquidity to earn fees from trades and bond transactions</li>
      <li>Receive LP tokens representing your share of the pool</li>
      <li>Withdraw your liquidity at any time</li>
      <li>APR varies based on pool activity and total liquidity</li>
    </ul>
  </PageSection>
)
