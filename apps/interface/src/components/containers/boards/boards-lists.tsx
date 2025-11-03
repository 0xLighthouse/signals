'use client'

import { useEffect, useState } from 'react'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { PageSection } from '@/components/page-section'
import { useBoardsStore } from '@/stores/useBoardsStore'

export const BoardsList = () => {
  const boards = useBoardsStore((state) => state.boards)
  const isFetchingBoards = useBoardsStore((state) => state.isFetching)

  // Ensure boards is always an array before filtering
  const _boardsSorted = boards.sort((a, b) => b.createdAt - a.createdAt)

  if (isFetchingBoards) {
    return <LoadingSpinner />
  }

  // If we have no boards, show empty state
  if (boards.length === 0) {
    return (
      <ListContainer title="Boards">
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No boards found</h3>
            <p className="text-neutral-500 dark:text-neutral-400">
              There are currently no active boards.
            </p>
          </div>
        </PageSection>
      </ListContainer>
    )
  }

  return (
    <ListContainer title="Initiatives">
      <p>Boards</p>
    </ListContainer>
  )
}
