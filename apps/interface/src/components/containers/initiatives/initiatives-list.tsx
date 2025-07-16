'use client'

import { useEffect, useState } from 'react'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { InitiativeCard } from './initiative-card'
import { PageSection } from '@/components/page-section'

export const InitiativesList = () => {
  const initiatives = useInitiativesStore((state) => state.initiatives)
  const isFetchingInitiatives = useInitiativesStore((state) => state.isFetching)
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)
  const isInitialized = useInitiativesStore((state) => state.isInitialized)

  useEffect(() => {
    if (!isInitialized) fetchInitiatives()
  }, [isInitialized, fetchInitiatives])

  const [sortBy, setSortBy] = useState('support')

  // Ensure initiatives is always an array before filtering
  const _initiativesSorted = initiatives.sort((a, b) =>
    sortBy === 'support' ? b.support - a.support : b.createdAtTimestamp - a.createdAtTimestamp,
  )

  if (isFetchingInitiatives) {
    return <LoadingSpinner />
  }

  // If we have no initiatives, show empty state
  if (initiatives.length === 0) {
    return (
      <ListContainer title="Initiatives">
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No initiatives found</h3>
            <p className="text-neutral-500 dark:text-neutral-400">
              There are currently no active initiatives.
            </p>
          </div>
        </PageSection>
        <InformationSection />
      </ListContainer>
    )
  }

  return (
    <ListContainer title="Initiatives">
      {_initiativesSorted.map((item, index) => (
        <InitiativeCard
          key={item.initiativeId}
          initiative={item}
          index={index}
          isFirst={index === 0}
          isLast={index === _initiativesSorted.length - 1}
        />
      ))}
      <InformationSection />
    </ListContainer>
  )
}

// Extract the information section into its own component for reuse
const InformationSection = () => (
  <PageSection className="bg-neutral-50 dark:bg-neutral-900 mt-5">
    <h3 className="text-lg font-medium mb-4">About Initiatives</h3>
    <ul className="list-disc pl-5 space-y-2">
      <li>Initiatives are community proposals that need support</li>
      <li>Support initiatives to help them progress to development</li>
      <li>Higher support increases an initiative's chance of implementation</li>
      <li>Create your own initiative to propose new features or improvements</li>
    </ul>
  </PageSection>
)
