'use client'

import { useEffect } from 'react'
import { useLocksStore } from '@/stores/useLocksStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { BondCard } from './bond.card'
import { useAccount } from '@/hooks/useAccount'
import { useSignals } from '@/contexts/SignalsContext'
import { PageSection } from '@/components/page-section'

export const BondsList = () => {
  const { address } = useAccount()
  const locks = useLocksStore((state) => state.locks)
  const isFetchingLocks = useLocksStore((state) => state.isFetching)
  const fetchLocks = useLocksStore((state) => state.fetchLocks)
  const isInitialized = useLocksStore((state) => state.isInitialized)
  const count = useLocksStore((state) => state.count)

  useEffect(() => {
    if (!isInitialized && address) fetchLocks(address)
  }, [isInitialized, fetchLocks, address])

  const { board } = useSignals()

  if (isFetchingLocks) {
    return <LoadingSpinner />
  }

  // If we have no bonds, show empty state
  if (locks.length === 0) {
    return (
      <ListContainer title={board.name} count={count}>
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No locked tokens found</h3>
            <p className="text-neutral-500 dark:text-neutral-400">
              When you lock tokens against an initiative, they will appear here.
            </p>
          </div>
        </PageSection>
        <InformationSection />
      </ListContainer>
    )
  }

  return (
    <ListContainer title={board.name} count={count}>
      {locks.map((item, index) => (
        <BondCard
          key={item.initiativeId}
          bond={item}
          board={board}
          index={index}
          isFirst={index === 0}
          isLast={index === locks.length - 1}
        />
      ))}
    </ListContainer>
  )
}

// Extract the information section into its own component for reuse
const InformationSection = () => (
  <PageSection className="bg-neutral-50 dark:bg-neutral-900">
    <h3 className="text-lg font-medium mb-4">About Bonds</h3>
    <ul className="list-disc pl-5 space-y-2">
      <li>Bonds represent financial claims on initiative outcomes</li>
      <li>Buy bonds to support initiatives and potentially earn returns</li>
      <li>Sell bonds back to the market if you change your position</li>
      <li>Bond prices reflect community support for initiatives</li>
    </ul>
  </PageSection>
)
