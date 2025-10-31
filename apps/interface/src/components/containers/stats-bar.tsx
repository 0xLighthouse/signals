'use client'

import React from 'react'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useAccount } from '@/hooks/useAccount'
import { Separator } from '../ui/separator'
import { normaliseNumber } from '@/lib/utils'

export const StatsBar = () => {
  const { address } = useAccount()
  const { symbol: underlyingSymbol, totalSupply, balance: underlyingBalance } = useUnderlying()
  const { formatter, board } = useSignals()

  if (!address) return null

  return (
    <div className="flex items-center justify-between p-4 bg-white rounded-lg border border-neutral-200 dark:border-neutral-700 dark:bg-neutral-900">
      <div className="flex flex-1 justify-evenly text-center">
        <div>
          <span className="text-xl font-bold">
            {normaliseNumber(formatter(underlyingBalance)) || '-'}
          </span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Balance {underlyingSymbol ? `(${underlyingSymbol})` : ''}
          </p>
        </div>
        <div>
          <span className="text-xl font-bold">
            {normaliseNumber(formatter(totalSupply)) || '-'}
          </span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Tokens claimed {underlyingSymbol ? `(${underlyingSymbol})` : ''}
          </p>
        </div>
        <div>
          <Separator orientation="vertical" />
        </div>
        <div>
          <span className="text-xl font-bold">
            {normaliseNumber(formatter(board.proposalThreshold)) || '-'}
          </span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Proposal threshold {underlyingSymbol ? `(${underlyingSymbol})` : ''}
          </p>
        </div>
        <div>
          <span className="text-xl font-bold">
            {normaliseNumber(formatter(board.acceptanceThreshold)) || '-'}
          </span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Acceptance threshold {underlyingSymbol ? `(${underlyingSymbol})` : ''}
          </p>
        </div>
      </div>
    </div>
  )
}
