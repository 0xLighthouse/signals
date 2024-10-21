'use client'

import { useEffect, useState } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'
import { CassetteTape, ChevronUp, TrendingUp } from 'lucide-react'

import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Chart } from './chart'
import { NormalisedInitiative } from '@/app/api/initiatives/route'
import { useSignals } from '@/contexts/SignalsContext'
import { timeAgoWords } from '@/lib/utils'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { PuffLoader } from 'react-spinners'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'
import { AddSupportDrawer } from '@/components/drawers/add-support-drawer'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'

// import data from '@/config/proposals.json'
// import { Money } from '@phosphor-icons/react'
// const cleanedData = data.map((idea) => ({
//   ...idea,
//   createdAtTimestamp: new Date(idea.created_at).getTime(),
// })) satisfies NormalisedInitiative[]

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
      {/* <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-2">
          <span>Showing</span>
          <Select value={sortBy} onValueChange={setSortBy}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="popular">Popular</SelectItem>
              <SelectItem value="latest">Latest</SelectItem>
            </SelectContent>
          </Select>
          <span>initiatives</span>
        </div>
        <div className="relative">
          <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 text-gray-400" />
          <Input
            className="pl-8"
            placeholder="Search..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div> */}
      <ScrollArea className="w-full mb-24">
        <div className="space-y-4">
          {_initiativesSorted.map((item) => (
            <Card key={item.initiativeId}>
              <CardHeader>
                <CardTitle>
                  #{item.initiativeId} — {item.title}
                </CardTitle>
                <CardDescription>Proposed {timeAgoWords(item.createdAtTimestamp)}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex">
                  <div className="w-3/5">{item.description}</div>
                  <div className="w-2/5">
                    <Chart />
                  </div>
                </div>
              </CardContent>
              <CardFooter className="flex justify-between">
                <div className="flex gap-2 text-xs leading-none">
                  {item.weight > 0 && <div>Updated {timeAgoWords(item.updatedAtTimestamp)}</div>}
                </div>
                <div className="flex gap-2 font-medium leading-none">
                  {item.weight}% reached <TrendingUp className="h-4 w-4" />
                </div>
                <IncentiveDrawer initiative={item} />
                <AddSupportDrawer initiative={item} />
              </CardFooter>
            </Card>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
