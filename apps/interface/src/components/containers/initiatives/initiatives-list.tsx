'use client'

import { useEffect, useState } from 'react'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { LoadingSpinner } from '@/components/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { InitiativeCard } from './initiative-card'

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
    </ListContainer>
  )
}
