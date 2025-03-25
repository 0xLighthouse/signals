'use client'

import React from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { SellBondDrawer } from '@/components/drawers/sell-bond-drawer'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'
import { formatDistanceToNow } from 'date-fns'
import { Ellipsis, Tag } from 'lucide-react'

import type { Initiative } from 'indexers/src/api/types'
import type { IBoard } from '@/contexts/SignalsContext'
import { Button } from '@/components/ui/button'

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

  // Calculate remaining time to maturity
  const maturityDate = new Date() * 1000 // Assuming unlockTime is in seconds
  const remainingTime = formatDistanceToNow(maturityDate, { addSuffix: true })

  // Mock yield and price for demonstration
  const bondYield = '5.2%'
  const bondPrice = '980.50'

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
          <CardDescription className="flex items-center text-xs gap-2">
            <span>Bond #{bond.tokenId}</span>
            <span>•</span>
            <span>Maturity: {remainingTime}</span>
          </CardDescription>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-2 h-[80px] items-center">
            <SellBondDrawer tokenId={bond.tokenId} />
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6 pt-2">
        <div className="flex flex-col">
          <div className="text-sm font-medium">Price: {bondPrice} USDC</div>
          <div className="text-sm font-medium">Yield: {bondYield}</div>
          <CardDescription className="text-xs mt-1">
            Supported {timeAgoWords(bond.blockTimestamp)}
          </CardDescription>
        </div>
        <div className="flex gap-2 items-center">
          <Button variant="ghost" size="icon" className="rounded-full">
            <Ellipsis className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </Card>
  )
}
