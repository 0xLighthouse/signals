import React from 'react'
import { useRouter } from 'next/navigation'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { getBoardUrl } from '@/lib/routing'
import { useNetworkStore } from '@/stores/useNetworkStore'
import type { BoardSummary } from '@/stores/useBoardsStore'

interface Props {
  board: BoardSummary
  isFirst?: boolean
  isLast?: boolean
}

export const BoardCard: React.FC<Props> = ({ board, isFirst = false, isLast = false }) => {
  const router = useRouter()
  const { selected: network } = useNetworkStore()

  const handleCardClick = () => {
    const boardUrl = getBoardUrl(network, board.contractAddress)
    router.push(boardUrl)
  }

  const ownerAddr = (board.owner ??
    ('0x0000000000000000000000000000000000000000' as `0x${string}`)) as `0x${string}`

  const now = Math.floor(Date.now() / 1000) // Convert to seconds to match opensAt/closesAt format
  const hasOpened = board.opensAt ? board.opensAt <= now : true
  const hasClosed = board.closesAt ? board.closesAt <= now : false
  const isOpen = hasOpened && !hasClosed

  return (
    <Card
      onClick={handleCardClick}
      className={cn(
        'flex flex-col cursor-pointer hover:bg-stone-50 dark:hover:bg-stone-900 transition-colors',
        isFirst && isLast
          ? 'rounded-lg'
          : isFirst
            ? 'rounded-t-lg rounded-b-none border-b-0'
            : isLast
              ? 'rounded-b-lg rounded-t-none'
              : 'rounded-none border-b-0',
      )}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <div className="flex items-center gap-2 flex-wrap">
            <CardTitle>{board.boardMetadata?.title ? board.boardMetadata.title : shortAddress(board.contractAddress)}</CardTitle>
            {board.opensAt !== null || board.closesAt !== null ? (
              <Badge variant={isOpen ? 'success' : hasClosed ? 'secondary' : 'info'}>
                {isOpen ? 'Open' : hasClosed ? 'Closed' : 'Upcoming'}
              </Badge>
            ) : null}
          </div>
          <CardDescription className="flex items-center text-xs">
            <span className="hidden sm:block">Created by</span>
            <Avatar className="sm:ml-1 mr-1">
              <AvatarImage src={resolveAvatar(ownerAddr)} alt={ownerAddr} />
            </Avatar>
            {ownerAddr}, {timeAgoWords(board.createdAtTimestamp ?? 0)}
          </CardDescription>
          <div>
            <p className="text-body line-clamp-4 break-words">
              {board.boardMetadata?.body ? board.boardMetadata.body : 'No description provided'}
            </p>
          </div>
        </CardHeader>
      </div>
      <div className="flex justify-between p-6">
        <CardDescription className="text-xs">
          Last activity, {timeAgoWords(board.updatedAt ?? board.createdAtTimestamp ?? 0)}
        </CardDescription>
      </div>
    </Card>
  )
}
