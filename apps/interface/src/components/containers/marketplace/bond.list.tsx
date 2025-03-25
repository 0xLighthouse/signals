'use client'

import { useEffect, useState } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

import { useLocksStore } from '@/stores/useLocksStore'
import { PuffLoader } from 'react-spinners'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'
import { BondCard } from './bond.card'
import { useAccount } from '@/hooks/useAccount'
import { useSignals } from '@/contexts/SignalsContext'

export const BondsList = () => {
  const { theme } = useTheme()
  const { address } = useAccount()
  const locks = useLocksStore((state) => state.locks)
  const isFetchingLocks = useLocksStore((state) => state.isFetching)
  const fetchLocks = useLocksStore((state) => state.fetchLocks)
  const isInitialized = useLocksStore((state) => state.isInitialized)
  const count = useLocksStore((state) => state.count)
  
  useEffect(() => {
    if (!isInitialized && address) fetchLocks(address)
  }, [isInitialized, fetchLocks, address])
  
  const { board } = useSignals()

  if (isFetchingLocks) {
    return (
      <div className="flex justify-center items-center">
        <PuffLoader
          color={theme === UITheme.DARK ? '#fff' : '#000'}
          size={38}
          speedMultiplier={2.6}
        />
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">My Bond Positions ({count})</h1>
      <ScrollArea className="w-full mb-24">
        <div>
          {locks.map((item, index) => (
            <BondCard
              key={item.initiativeId}
              bond={item}
              board={board}
              index={index}
              isFirst={index === 0}
              isLast={index === locks.length - 1}
            />
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}