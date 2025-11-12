import React from 'react'
import { useRouter } from 'next/navigation'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { getBoardUrl } from '@/lib/routing'
import { useNetworkStore } from '@/stores/useNetworkStore'

type BoardSummary = {
  contractAddress: `0x${string}`
  owner?: `0x${string}`
  title?: string
  body?: string
  proposalThreshold?: string
  acceptanceThreshold?: string
  underlyingToken?: `0x${string}`
  createdAtTimestamp?: number
  updatedAt?: number
}

interface Props {
  board: BoardSummary
}

export const BoardCard: React.FC<Props> = ({ board }) => {
  const router = useRouter()
  const { selected: network } = useNetworkStore()

  const handleCardClick = () => {
    const boardUrl = getBoardUrl(network, board.contractAddress)
    router.push(boardUrl)
  }

  const ownerAddr = (board.owner ??
    ('0x0000000000000000000000000000000000000000' as `0x${string}`)) as `0x${string}`

  return (
    <Card
      onClick={handleCardClick}
      className={cn(
        'flex flex-col cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-900 transition-colors',
      )}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <CardTitle>{board.title ? board.title : shortAddress(board.contractAddress)}</CardTitle>
          <CardDescription className="flex items-center text-xs">
            <span className="hidden sm:block">Created by</span>
            <Avatar className="sm:ml-1 mr-1">
              <AvatarImage src={resolveAvatar(ownerAddr)} alt={ownerAddr} />
            </Avatar>
            {ownerAddr},{' '}
            {timeAgoWords(board.createdAtTimestamp ?? 0)}
          </CardDescription>
          <div>
            <p className="text-body line-clamp-4 break-words">
              {board.body ? board.body : 'No description provided'}
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
