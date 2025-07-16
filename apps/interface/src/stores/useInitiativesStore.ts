import type { Initiative, InitiativeResponse } from '../../../indexers/src/api/types'
import { client, schema } from '@/config/ponder'
import { context, INDEXER_ENDPOINT } from '@/config/web3'
import { create } from 'zustand'

interface InitiativesState {
  initiatives: Initiative[]
  isFetching: boolean
  isInitialized: boolean
  fetchInitiatives: () => Promise<void>
}

// TODO: These values can be dynamic now..
const CHAIN_ID = 421614
const ADDRESS = context.contracts.SignalsProtocol.address

export const useInitiativesStore = create<InitiativesState>((set) => ({
  initiatives: [],
  isFetching: false,
  isInitialized: false,
  fetchInitiatives: async () => {
    try {
      set({ isFetching: true })

      const resp = await fetch(`${INDEXER_ENDPOINT}/initiatives/${CHAIN_ID}/${ADDRESS}`)
      const { initiatives }: InitiativeResponse = await resp.json()
      if (Array.isArray(initiatives)) {
        set({ initiatives })
      } else {
        console.error('Fetched data is not an array:', initiatives)
      }
    } catch (error) {
      console.error('Error fetching initiatives:', error)
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
}))
