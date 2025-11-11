'use client'

import { useEffect, useMemo } from 'react'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { PageSection } from '@/components/page-section'
import { useBoardsStore } from '@/stores/useBoardsStore'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { BoardCard } from './board-card'

export const BoardsList = () => {
  const boards = useBoardsStore((state) => state.boards)
  const isFetching = useBoardsStore((state) => state.isFetching)
  const fetchBoards = useBoardsStore((state) => state.fetchBoards)
  const resetBoards = useBoardsStore((state) => state.reset)
  const selectedNetwork = useNetworkStore((state) => state.selected)

  useEffect(() => {
    // On network change, reset cached results and refetch
    resetBoards()
    fetchBoards().catch((err) => {
      console.error('Failed to fetch boards:', err)
    })
  }, [selectedNetwork, fetchBoards, resetBoards])

  const sortedBoards = useMemo(() => {
    return [...boards].sort((a, b) => {
      const aTs = a.createdAtTimestamp ?? 0
      const bTs = b.createdAtTimestamp ?? 0
      if (bTs !== aTs) return bTs - aTs
      return b.contractAddress.localeCompare(a.contractAddress)
    })
  }, [boards])

  if (isFetching) {
    return <LoadingSpinner />
  }

  if (sortedBoards.length === 0) {
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
    <ListContainer title="Boards">
      {sortedBoards.map((board) => (
        <BoardCard key={board.contractAddress} board={board} />
      ))}
    </ListContainer>
  )
}
