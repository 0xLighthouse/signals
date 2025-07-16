import React from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'
import { AddSupportDrawer } from '@/components/drawers/add-support-drawer'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'
import { AvatarGroup } from '@/components/ui/avatar-group'

import type { Initiative } from 'indexers/src/api/types'

interface Props {
  initiative: Initiative
  index: number
  isFirst: boolean
  isLast: boolean
}

export const InitiativeCard: React.FC<Props> = ({ initiative, isFirst, isLast }) => {
  const proposerName = useAsyncProp(
    resolveName(initiative.proposer),
    shortAddress(initiative.proposer),
  )

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
          <CardTitle>{initiative.title}</CardTitle>
          <CardDescription className="flex items-center text-xs">
            <span className="hidden sm:block">Proposed by</span>
            <Avatar className="sm:ml-1 mr-1">
              <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
            </Avatar>
            {proposerName}, {timeAgoWords(initiative.createdAtTimestamp)}
          </CardDescription>
          <div>
            <p className="text-body line-clamp-4 break-words">{initiative.description}</p>
          </div>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-1 h-[80px]">
            <IncentiveDrawer initiative={initiative} />
            <AddSupportDrawer initiative={initiative} />
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6">
        <AvatarGroup
          avatars={
            initiative.supporters.length > 0
              ? initiative.supporters.map((address) => resolveAvatar(address) as string)
              : undefined
          }
        />
        <CardDescription className="text-xs">
          Last activity,&nbsp;{timeAgoWords(initiative.updatedAtTimestamp)}
        </CardDescription>
      </div>
    </Card>
  )
}
