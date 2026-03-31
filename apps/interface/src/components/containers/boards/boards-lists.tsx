'use client'

import { useEffect, useMemo } from 'react'
import { PlusIcon } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { PageSection } from '@/components/page-section'
import { Button } from '@/components/ui/button'
import { useBoardsStore } from '@/stores/useBoardsStore'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { toast } from 'sonner'
import { getSlugFromNetwork } from '@/lib/routing'
import { BoardCard } from './board-card'

export const BoardsList = () => {
  const boards = useBoardsStore((state) => state.boards)
  const isFetching = useBoardsStore((state) => state.isFetching)
  const fetchBoards = useBoardsStore((state) => state.fetchBoards)
  const resetBoards = useBoardsStore((state) => state.reset)
  const selectedNetwork = useNetworkStore((state) => state.selected)
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const router = useRouter()

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

  const handleCreate = () => {
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    const slug = getSlugFromNetwork(selectedNetwork)
    router.push(`/${slug}/create-board`)
  }

  const createButton = (
    <Button variant="default" onClick={handleCreate}>
      <PlusIcon size={16} className="mr-2" />
      Create Board
    </Button>
  )

  if (isFetching) {
    return <LoadingSpinner />
  }

  if (sortedBoards.length === 0) {
    return (
      <ListContainer title="Boards" rightAction={createButton}>
        <PageSection>
          <div className="text-center py-8">
            <h3 className="text-lg font-medium mb-2">No boards found</h3>
            <p className="text-stone-500 dark:text-stone-400">
              There are currently no active boards.
            </p>
          </div>
        </PageSection>
      </ListContainer>
    )
  }

  return (
    <ListContainer title="Boards" rightAction={createButton}>
      {sortedBoards.map((board, index) => (
        <BoardCard
          key={board.contractAddress}
          board={board}
          isFirst={index === 0}
          isLast={index === sortedBoards.length - 1}
        />
      ))}
    </ListContainer>
  )
}
