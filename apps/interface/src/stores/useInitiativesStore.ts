import type { Initiative, InitiativeResponse } from '../../../indexers/src/api/types'
import { client, schema } from '@/config/ponder'
import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

interface InitiativesState {
  initiatives: Initiative[]
  isFetching: boolean
  isInitialized: boolean
  fetchInitiatives: () => Promise<void>
  reset: () => void
}

export const useInitiativesStore = create<InitiativesState>((set) => ({
  initiatives: [],
  isFetching: false,
  isInitialized: false,
  fetchInitiatives: async () => {
    try {
      set({ isFetching: true })

      const { chain, indexerEndpoint, contracts } = useNetworkStore.getState().config
      const boardAddress = contracts.SignalsProtocol?.address
      if (!boardAddress) {
        console.warn('No Signals board configured for current network.')
        set({ initiatives: [] })
        return
      }

      const resp = await fetch(`${indexerEndpoint}/initiatives/${chain.id}/${boardAddress}`)
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
  reset: () => set({ initiatives: [], isFetching: false, isInitialized: false }),
}))
