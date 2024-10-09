'use client'

import { useState } from 'react'
import { Button } from '../ui/button'
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '../ui/card'
import { Input } from '../ui/input'
import { Textarea } from '../ui/textarea'

export const Submission = () => {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [network, setNetwork] = useState('')
  const [token, setToken] = useState('')
  const [amount, setAmount] = useState<number | undefined>()
  const [duration, setDuration] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log({ title, body, network, token, amount, duration })
  }
  return (
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
        <Button onClick={handleSubmit}>Propose</Button>
      </CardFooter>
    </Card>
  )
}
