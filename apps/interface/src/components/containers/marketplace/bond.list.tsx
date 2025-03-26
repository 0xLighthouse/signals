'use client'

import { useEffect } from 'react'
import { useLocksStore } from '@/stores/useLocksStore'
import { LoadingSpinner } from '@/components/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { BondCard } from './bond.card'
import { useAccount } from '@/hooks/useAccount'
import { useSignals } from '@/contexts/SignalsContext'

export const BondsList = () => {
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
    return <LoadingSpinner />
  }

  return (
    <ListContainer title="My Bond Positions" count={count}>
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
    </ListContainer>
  )
}
