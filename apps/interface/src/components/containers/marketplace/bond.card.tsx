'use client'

import React from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, timeAgoWords } from '@/lib/utils'
import { SellBondDrawer } from '@/components/drawers/sell-bond-drawer'

import type { Lock } from 'indexers/src/api/types'
import { type IBoard } from '@/contexts/SignalsContext'
import { DateTime } from 'luxon'
import { useUnderlying } from '@/contexts/ContractContext'
import { context } from '@/config/web3'
import { MaturityTimeline } from './maturity-timeline'
import { BuyBondDrawer } from '@/components/drawers/buy-bond-drawer'

interface Props {
  action: 'sell' | 'purchase'
  bond: Lock
  index: number
  isFirst: boolean
  isLast: boolean
  board: IBoard
}

export const BondCard: React.FC<Props> = ({ action, bond, board, isFirst, isLast }) => {
  const initiative = bond.initiative
  const { symbol: underlyingTokenSymbol, formatter: underlyingTokenFormatter } = useUnderlying()

  return (
    <Card
      className={cn(
        'flex flex-col',
        isFirst && isLast
          ? 'rounded-lg'
          : isFirst
            ? 'rounded-t-lg rounded-b-none'
            : isLast
              ? 'rounded-b-lg rounded-t-none'
              : 'rounded-none border-b-0',
      )}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <CardTitle>{initiative.title}</CardTitle>
          <CardDescription className="flex items-center text-xs gap-1">
            <span>
              {board.symbol}#{bond.tokenId}
            </span>
            <span>•</span>
            <span className="underline">
              <a
                href={`${context.network.explorerUri}/tx/${bond.transactionHash}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                Supported {timeAgoWords(Number(bond.blockTimestamp))}
              </a>
            </span>
          </CardDescription>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-2 h-[80px] items-center">
            {action === 'sell' && <SellBondDrawer tokenId={bond.tokenId} />}
            {action === 'purchase' && <BuyBondDrawer tokenId={bond.tokenId} />}
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6 pt-0">
        <div className="text-2xl">
          {underlyingTokenFormatter(Number(bond.metadata.nominalValue))} {underlyingTokenSymbol}
        </div>
      </div>
      <div className="p-6 pt-0">
        <MaturityTimeline
          issueDate={DateTime.fromSeconds(Number(bond.metadata.created))}
          maturityDate={DateTime.fromSeconds(Number(bond.metadata.expires))}
        />
      </div>
    </Card>
  )
}
