'use client'

import { useState } from 'react'

export default function Home() {
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
    <div className="flex flex-col gap-4">
      {cards.map((card) => (
        <div key={card.id} className="bg-gray-200 p-4 rounded-md flex flex-col gap-4">
          <div className="flex flex-col">
            <span className="font-bold text-xl">{card.title}</span>
            <span>{card.status}</span>
          </div>
          <p>{card.body.length > 100 ? `${card.body.substring(0, 100)}...` : card.body}</p>
          <div className="flex justify-between">
            <div className="flex gap-4">
              <button type={'button'} onClick={() => addSupport(card.id)}>
                Add Support
              </button>
              <button type={'button'} onClick={() => removeSupport(card.id)}>
                Remove Support
              </button>
            </div>
            <div className="flex flex-col items-end">
              <span>#{card.rank}</span>
              <span>{card.tokenAmount}</span>
              <span>{card.tokenPercentage} of supply</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
