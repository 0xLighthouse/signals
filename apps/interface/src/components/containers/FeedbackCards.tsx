'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/ButtonOld'
import clsx from 'clsx'

export const FeedbackCards: React.FC = () => {
  const addSupport = (id: number) => {
    // Add logic for adding support to the idea
    console.log(`Support added to card with id: ${id}`)
  }

  const removeSupport = (id: number) => {
    // Add logic for removing support from the idea
    console.log(`Support removed from card with id: ${id}`)
  }
  const [cards, setCards] = useState([
    {
      id: 1,
      title: 'E2E Encrypted Chat',
      body: 'Enable end-to-end encryption for chat messages.',
      network: 'Ethereum',
      tokenAmount: '400k',
      tokenPercentage: '3%',
      rank: 1,
      status: 'Proposed',
    },
    {
      id: 2,
      title: 'Space Audio Room',
      body: 'Implement an audio room for community discussions.',
      network: 'Polygon',
      tokenAmount: '300k',
      tokenPercentage: '2%',
      rank: 2,
      status: 'Under Review',
    },
    {
      id: 3,
      title: 'On Chain Forums',
      body: 'Create a forum integrated directly with on-chain data.',
      network: 'Optimism',
      tokenAmount: '500k',
      tokenPercentage: '4%',
      rank: 3,
      status: 'Proposed',
    },
  ])

  return (
    <div className="flex flex-col">
      {cards.map((card, idx) => (
        <div
          key={card.id}
          className={clsx(
            'p-4 flex flex-col gap-4 border border-t-0 border-neutral-200 dark:bg-neutral-900',
            idx === cards.length - 1 ? 'rounded-b-md' : undefined,
          )}
        >
          <div className="flex flex-col">
            <span className="font-bold text-xl">{card.title}</span>
            <span>{card.status}</span>
          </div>
          <p>{card.body.length > 100 ? `${card.body.substring(0, 100)}...` : card.body}</p>
          <div className="flex justify-between">
            <div className="flex items-center gap-4">
              <Button onClick={() => addSupport(card.id)}>Add Support</Button>
              <Button onClick={() => removeSupport(card.id)}>Remove Support</Button>
            </div>
            <div className="flex flex-col items-end">
              <span>#{card.rank}</span>
              <span>{card.tokenAmount}</span>
              <span>{card.tokenPercentage} of supply</span>
            </div>
          </div>
        </div>
      ))}{' '}
    </div>
  )
}
