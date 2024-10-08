'use client'

import { useState } from 'react'
import { PlusCircle, Search, ChevronUp, ChevronDown } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { useAccount } from 'wagmi'
import { ConnectCTAPanel } from '../web3/connect-cta-panel'

interface Idea {
  id: number
  title: string
  body: string
  network?: string
  token?: string
  amount?: number
  duration?: string
  votes: number
}

export function ProductPrioritizationComponent() {
  const { isConnected } = useAccount()

  const [ideas, setIdeas] = useState<Idea[]>([
    {
      id: 1,
      title: 'E2E Encrypted Chat',
      body: 'Enable end-to-end encryption for chat messages.',
      network: 'Ethereum',
      amount: 400000,
      votes: 10,
      // tokenPercentage: '3%',
      // rank: 1,
      // status: 'Proposed',
    },
    {
      id: 2,
      title: 'Space Audio Room',
      body: 'Implement an audio room for community discussions.',
      network: 'Polygon',
      amount: 400000,
      votes: 10,
      // tokenPercentage: '2%',
      // rank: 2,
      // status: 'Under Review',
    },
    {
      id: 3,
      title: 'On Chain Forums',
      body: 'Create a forum integrated directly with on-chain data.',
      network: 'Optimism',
      amount: 400000,
      votes: 10,
      // tokenPercentage: '4%',
      // rank: 3,
      // status: 'Proposed',
    },
  ])
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [network, setNetwork] = useState('')
  const [token, setToken] = useState('')
  const [amount, setAmount] = useState<number | undefined>()
  const [duration, setDuration] = useState('')
  const [sortBy, setSortBy] = useState("'trending'")
  const [searchTerm, setSearchTerm] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (title && body) {
      const newIdea: Idea = {
        id: Date.now(),
        title,
        body,
        network,
        token,
        amount,
        duration,
        votes: 0,
      }
      setIdeas([...ideas, newIdea])
      setTitle('')
      setBody('')
      setNetwork('')
      setToken('')
      setAmount(undefined)
      setDuration('')
    }
  }

  const handleVote = (id: number) => {
    setIdeas(ideas.map((idea) => (idea.id === id ? { ...idea, votes: idea.votes + 1 } : idea)))
  }

  // TODO: break out the ideas/feedbacks list into a separate component
  const filteredAndSortedIdeas = ideas
    .filter((idea) => idea.title.toLowerCase().includes(searchTerm.toLowerCase()))
    .sort((a, b) => (sortBy === "'trending'" ? b.votes - a.votes : b.id - a.id))

  return (
    <div className="">
      <div className="mb-8">
        {isConnected ? (
          <Card>
            <CardHeader>
              <CardTitle>Submit a new idea</CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-4">
                <Input
                  placeholder="Short, descriptive title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                />
                <Textarea
                  placeholder="Description"
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  required
                />
                <div className="grid grid-cols-2 gap-4">
                  <Input
                    placeholder="Network (optional)"
                    value={network}
                    onChange={(e) => setNetwork(e.target.value)}
                  />
                  <Input
                    placeholder="Token (optional)"
                    value={token}
                    onChange={(e) => setToken(e.target.value)}
                  />
                  <Input
                    type="number"
                    placeholder="Amount (optional)"
                    value={amount || ''}
                    onChange={(e) => setAmount(Number(e.target.value))}
                  />
                  <Input
                    placeholder="Duration (optional)"
                    value={duration}
                    onChange={(e) => setDuration(e.target.value)}
                  />
                </div>
              </form>
            </CardContent>
            <CardFooter className="flex justify-between">
              <Button variant="outline">Cancel</Button>
              <Button onClick={handleSubmit}>Create Post</Button>
            </CardFooter>
          </Card>
        ) : (
          <ConnectCTAPanel />
        )}
      </div>
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-2">
          <span>Showing</span>
          <Select value={sortBy} onValueChange={setSortBy}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="trending">Trending</SelectItem>
              <SelectItem value="newest">Newest</SelectItem>
            </SelectContent>
          </Select>
          <span>posts</span>
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
      </div>
      <ScrollArea className="w-full mb-24">
        <div className="space-y-4">
          {filteredAndSortedIdeas.map((idea) => (
            <Card key={idea.id}>
              <CardHeader>
                <CardTitle>{idea.title}</CardTitle>
                {idea.network && <CardDescription>{idea.network}</CardDescription>}
              </CardHeader>
              <CardContent>
                <p>{idea.body}</p>
                {(idea.token || idea.amount || idea.duration) && (
                  <div className="mt-2 text-sm text-gray-500">
                    {idea.token && <span className="mr-2">Token: {idea.token}</span>}
                    {idea.amount && <span className="mr-2">Amount: {idea.amount}</span>}
                    {idea.duration && <span>Duration: {idea.duration}</span>}
                  </div>
                )}
              </CardContent>
              <CardFooter className="flex justify-between">
                <span>{idea.votes} votes</span>
                <Button variant="outline" size="sm" onClick={() => handleVote(idea.id)}>
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
