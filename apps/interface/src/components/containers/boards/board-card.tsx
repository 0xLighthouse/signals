import React from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'
import { AddSupportDrawer } from '@/components/drawers/add-support-drawer'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'
import { AvatarGroup } from '@/components/ui/avatar-group'
import { ExternalLink, Paperclip } from 'lucide-react'

import type { Initiative } from 'indexers/src/api/types'

interface Props {
  initiative: Initiative
  index: number
  isFirst: boolean
  isLast: boolean
}

export const BoardCard: React.FC<Props> = ({ board, isFirst, isLast }) => {
  return (
    <Card
      className={cn(
        'flex flex-col',
        isFirst
          ? 'rounded-t-lg rounded-b-none border-b-0 '
          : isLast
            ? 'rounded-b-lg rounded-t-none'
            : 'rounded-none border-b-0',
      )}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <CardTitle>Some Board name</CardTitle>
          <CardDescription className="flex items-center text-xs">
            <span className="hidden sm:block">Created by</span>
            <Avatar className="sm:ml-1 mr-1">
              <AvatarImage src={resolveAvatar(board.owner)} alt={board.owner} />
            </Avatar>
            {board.owner}, {timeAgoWords(board.createdAtTimestamp)}
          </CardDescription>
          <div>
            <p className="text-body line-clamp-4 break-words">Some board description</p>
          </div>
        </CardHeader>
      </div>
      <div className="flex justify-between p-6">
        <CardDescription className="text-xs">
          Last activity,&nbsp;{timeAgoWords(board.updatedAt)}
        </CardDescription>
      </div>
    </Card>
  )
}
