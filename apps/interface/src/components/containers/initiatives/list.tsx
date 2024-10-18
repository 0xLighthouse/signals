'use client'

import { useState } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'
import { CassetteTape, ChevronUp, Monitor, Search, TrendingUp } from 'lucide-react'

import data from '@/config/proposals.json'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Chart } from './chart'
import { Money } from '@phosphor-icons/react'
const cleanedData = data.map((idea) => ({
  ...idea,
  created_at: new Date(idea.created_at).getTime(),
}))

interface Idea {
  id: number
  title: string
  views: number
  like_count: number
  created_at: number
}

export const InitiativesList = ({ type }: { type: 'active' | 'accepted' | 'archived' }) => {
  const [initiatives, setInitiatives] = useState<Idea[]>(cleanedData)

  const [sortBy, setSortBy] = useState("'trending'")
  const [searchTerm, setSearchTerm] = useState('')

  // TODO: break out the ideas/feedbacks list into a separate component
  const filteredAndSortedIdeas = initiatives
    .filter((idea) => idea.title.toLowerCase().includes(searchTerm.toLowerCase()))
    .sort((a, b) => (sortBy === "'trending'" ? b.created_at - a.created_at : b.id - a.id))

  const handleSupportInitiative = (id: number) => {
    console.log('support initiative', id)
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
          {filteredAndSortedIdeas.map((idea) => (
            <Card key={idea.id}>
              <CardHeader>
                <CardTitle>{idea.title}</CardTitle>
                {/* {idea.network && <CardDescription>{idea.network}</CardDescription>} */}
              </CardHeader>
              <CardContent>
                <div className="flex">
                  <div className="w-3/5">asdasd</div>
                  <div className="w-2/5">
                    <Chart />
                  </div>
                </div>
              </CardContent>
              <CardFooter className="flex justify-between">
                <div className="flex gap-2 font-medium leading-none">
                  Trending up by 5.2% this month <TrendingUp className="h-4 w-4" />
                </div>
                <div className="flex gap-2 font-medium leading-none">
                  $5.2% this month <CassetteTape className="h-4 w-4" />
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleSupportInitiative(idea.id)}
                >
                  <ChevronUp className="mr-1 h-4 w-4" />
                  Upvote
                </Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
