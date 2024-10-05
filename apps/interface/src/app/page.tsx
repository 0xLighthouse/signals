'use client'

import styles from './page.module.css'
import { useState } from 'react'
import { TamaguiProvider, Stack, Text, createTamagui } from '@tamagui/core'
import { config } from '@tamagui/config/v3'

// you usually export this from a tamagui.config.ts file
const tamaguiConfig = createTamagui(config)

// TypeScript types across all Tamagui APIs
type Conf = typeof tamaguiConfig
declare module '@tamagui/core' {
  interface TamaguiCustomConfig extends Conf {}
}

export default function Home() {
  const addSupport = (id) => {
    // Add logic for adding support to the idea
    console.log(`Support added to card with id: ${id}`)
  }

  const removeSupport = (id) => {
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
    <div className={styles.page}>
      <main className={styles.main}>
        <TamaguiProvider config={tamaguiConfig}>
          <Stack gap>
            {cards.map((card) => (
              <Stack key={card.id} backgroundColor="lightgray" padding="$4" borderRadius="$4" gap>
                <Stack>
                  <Text fontWeight="bold" fontSize="$4">
                    {card.title}
                  </Text>
                  <Text>{card.status}</Text>
                </Stack>
                <Text>
                  {card.body.length > 100 ? `${card.body.substring(0, 100)}...` : card.body}
                </Text>
                <Stack direction="row" justifyContent="space-between">
                  <Stack direction="row" gap>
                    <button type={'button'} onClick={() => addSupport(card.id)}>Add Support</button>
                    <button type={'button'} onClick={() => removeSupport(card.id)}>Remove Support</button>
                  </Stack>
                  <Stack alignItems="flex-end">
                    <Text>#{card.rank}</Text>
                    <Text>{card.tokenAmount}</Text>
                    <Text>{card.tokenPercentage} of supply</Text>
                  </Stack>
                </Stack>
              </Stack>
            ))}
          </Stack>
        </TamaguiProvider>
      </main>
    </div>
  )
}
