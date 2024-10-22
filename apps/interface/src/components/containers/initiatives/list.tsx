'use client'

import { useEffect, useState } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

import { useSignals } from '@/contexts/SignalsContext'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { PuffLoader } from 'react-spinners'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'
import InitiativeCard from './initiative-card'
import { Card } from '@/components/ui/card'
import { InitiativeDrawer } from '@/components/drawers/initiative-drawer'

export const InitiativesList = () => {
  const { theme } = useTheme()
  const { initiativesCount } = useSignals()
  const initiatives = useInitiativesStore((state) => state.initiatives)
  const isFetchingInitiatives = useInitiativesStore((state) => state.isFetching)
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  console.log('count initiatives', initiativesCount)

  useEffect(() => {
    if (fetchInitiatives) fetchInitiatives()
  }, [fetchInitiatives])

  const [sortBy, setSortBy] = useState("'trending'")
  const [searchTerm, setSearchTerm] = useState('')

  // TODO: break out the ideas/feedbacks list into a separate component
  // Ensure initiatives is always an array before filtering
  const _initiativesSorted = initiatives
    .filter((o) => o.title.toLowerCase().includes(searchTerm.toLowerCase()))
    .sort((a, b) =>
      sortBy === "'trending'"
        ? b.createdAtTimestamp - a.createdAtTimestamp
        : b.initiativeId - a.initiativeId,
    )

  const handleSupportInitiative = (id: number) => {
    console.log('support initiative', id)
  }

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
      {/* <Card className="rounded-b-none border-b-0 py-4 px-6 bg-neutral-50">
        <h2 className="text-2xl font-semibold">Initiatives</h2>
      </Card> */}
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
