'use client'

import { useEffect } from 'react'
import { useBondsStore } from '@/stores/useBondsStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { BondCard } from './bond.card'
import { useAccount } from '@/hooks/useAccount'
import { useSignals } from '@/contexts/SignalsContext'
import { PageSection } from '@/components/page-section'

export const BondsOwned = () => {
  const { address } = useAccount()
  const bonds = useBondsStore((s) => s.bondsOwned)
  const isFetching = useBondsStore((s) => s.isFetchingBondsOwned)
  const isInitialized = useBondsStore((s) => s.isBondsOwnedInitialized)
  const fetchBondsOwned = useBondsStore((s) => s.fetchBondsOwned)

  useEffect(() => {
    if (address && !isInitialized && !isFetching) {
      console.log('Fetching bonds owned by user:', address)
      // Prevent immediate re-render that can cause infinite loop
      setTimeout(() => {
        fetchBondsOwned(address)
      }, 0)
    }
  }, [address, isInitialized, isFetching, fetchBondsOwned])

  const { board } = useSignals()

  if (isFetching) {
    return <LoadingSpinner />
  }

  // If we have no bonds, show empty state
  if (bonds.length === 0) {
    return (
      <ListContainer title={board.name} count={bonds.length}>
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
    <ListContainer title={board.name} count={bonds.length}>
      {bonds.map((item, index) => (
        <BondCard
          key={item.initiativeId}
          action="sell"
          bond={item}
          board={board}
          index={index}
          isFirst={index === 0}
          isLast={index === bonds.length - 1}
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
