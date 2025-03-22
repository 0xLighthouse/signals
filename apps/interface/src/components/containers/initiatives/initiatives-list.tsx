'use client'

import { useEffect, useState } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

import { useSignals } from '@/contexts/SignalsContext'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { PuffLoader } from 'react-spinners'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'
import { InitiativeCard } from './initiative-card'

export const InitiativesList = () => {
  const { theme } = useTheme()
  const { initiativesCount } = useSignals()
  const initiatives = useInitiativesStore((state) => state.initiatives)
  const isFetchingInitiatives = useInitiativesStore((state) => state.isFetching)
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)
  const isInitialized = useInitiativesStore((state) => state.isInitialized)

  console.log('initiatives', initiatives)

  useEffect(() => {
    if (!isInitialized) fetchInitiatives()
  }, [isInitialized, fetchInitiatives])

  const [sortBy, setSortBy] = useState('support')

  console.log('initiative-count', initiativesCount)

  // Ensure initiatives is always an array before filtering
  const _initiativesSorted = initiatives.sort((a, b) =>
    sortBy === 'support' ? b.support - a.support : b.createdAtTimestamp - a.createdAtTimestamp,
  )

  if (isFetchingInitiatives) {
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
    <div className="">
      <ScrollArea className="w-full mb-24">
        <div>
          {_initiativesSorted.map((item, index) => (
            <InitiativeCard
              key={item.initiativeId}
              initiative={item}
              index={index}
              isFirst={index === 0}
              isLast={index === _initiativesSorted.length - 1}
            />
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
