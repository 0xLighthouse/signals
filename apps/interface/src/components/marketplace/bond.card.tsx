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
import type { IBoard } from '@/contexts/SignalsContext'
interface Props {
  bond: Bond
  index: number
  isFirst: boolean
  isLast: boolean
  board: IBoard
}

export const BondCard: React.FC<Props> = ({ bond, isFirst, isLast }) => {
  const initiative = bond.initiative
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
            {/* <span className="hidden sm:block">Locked support,</span> */}
            Bond#{bond.tokenId}
            Unlocks: XXXXX
          </CardDescription>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-1 h-[80px]">
            <div className="w-1/5 bg-red-500">SELL</div>
            <div className="w-1/2 bg-blue-500">asd</div>
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6">
        <CardDescription className="text-xs">
          Supported,&nbsp;{timeAgoWords(bond.blockTimestamp)}
        </CardDescription>
      </div>
    </Card>
  )
}
