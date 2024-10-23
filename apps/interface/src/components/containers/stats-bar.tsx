'use client'

import React, { useEffect } from 'react'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useRewardsStore } from '@/stores/useRewardsStore'
import { useAccount } from '@/hooks/useAccount'
import { Separator } from '../ui/separator'
import { normaliseNumber } from '@/lib/utils'

export const StatsBar = () => {
  const { address } = useAccount()
  const {
    balance: usdcBalance,
    fetch: fetchUSDC,
    symbol: usdcSymbol,
    formatter: formatUSDC,
  } = useRewardsStore()
  const { symbol: underlyingSymbol, totalSupply, balance: underlyingBalance } = useUnderlying()
  const { formatter, proposalThreshold, acceptanceThreshold } = useSignals()

  useEffect(() => {
    if (address) {
      fetchUSDC(address)
    }
  }, [address, fetchUSDC])

  if (!address) return null

  return (
    <div className="flex items-center justify-between p-4 bg-white dark:border-neutral-700 dark:bg-neutral-900 rounded-lg border">
      <div className="flex flex-1 justify-evenly text-center">
        <div>
          <span className="text-xl font-bold">{normaliseNumber(formatter(underlyingBalance))}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Balance ({underlyingSymbol})
          </p>
        </div>
        <div>
          {/* @ts-ignore */}
          <span className="text-xl font-bold">{normaliseNumber(formatUSDC(usdcBalance))}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">Balance ({usdcSymbol})</p>
        </div>
        <div>
          <Separator orientation="vertical" />
        </div>
        <div>
          <span className="text-xl font-bold">{normaliseNumber(formatter(proposalThreshold))}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Proposal threshold ({underlyingSymbol})
          </p>
        </div>
        <div>
          <span className="text-xl font-bold">
            {normaliseNumber(formatter(acceptanceThreshold))}
          </span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Acceptance threshold ({underlyingSymbol})
          </p>
        </div>
      </div>
    </div>
  )
}
