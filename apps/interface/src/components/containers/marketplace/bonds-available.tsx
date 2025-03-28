'use client'

import { useEffect } from 'react'
import { useBondsStore } from '@/stores/useBondsStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { BondCard } from './bond.card'
import { useSignals } from '@/contexts/SignalsContext'
import { PageSection } from '@/components/page-section'
import { context } from '@/config/web3'

export const BondsAvailable = () => {
  const address = context.contracts.BondHook.address
  const bonds = useBondsStore((s) => s.bondsAvailable)
  const isFetching = useBondsStore((s) => s.isBondsAvailableFetching)
  const isInitialized = useBondsStore((s) => s.isBondsAvailableInitalized)
  const fetchBondsAvailable = useBondsStore((s) => s.fetchBondsAvailable)

  useEffect(() => {
    if (!isInitialized && !isFetching) {
      console.log('Fetching bonds owned by the BondHook contract:', address)
      // Prevent immediate re-render that can cause infinite loop
      setTimeout(() => {
        fetchBondsAvailable(address)
      }, 0)
    }
  }, [isInitialized, isFetching, fetchBondsAvailable, address])

  const { board } = useSignals()

  if (isFetching || !isInitialized) {
    return <LoadingSpinner />
  }

  // If we have no bonds, show empty state
  if (bonds.length === 0) {
    return (
      <ListContainer title={board.name} count={bonds.length}>
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No bonds available</h3>
            <p className="text-neutral-500 dark:text-neutral-400">
              Bonds held by the Hook contract that are available for purchase will appear here.
            </p>
          </div>
        </PageSection>
        <InformationSection />
      </ListContainer>
    )
  }

  return (
    <ListContainer title={'Available for purchase'} count={bonds.length}>
      {bonds.map((item, index) => (
        <BondCard
          action="purchase"
          key={item.initiativeId}
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
