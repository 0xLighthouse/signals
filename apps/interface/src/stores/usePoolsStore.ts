import type { Pool, GetPoolsResponse } from '@/indexers/api/types'
import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

interface PoolsState {
  pools: Pool[]
  isFetching: boolean
  isInitialized: boolean
  fetchPools: () => Promise<void>
  reset: () => void
}

export const usePoolsStore = create<PoolsState>((set) => ({
  pools: [],
  isFetching: false,
  isInitialized: false,
  fetchPools: async () => {
    try {
      set({ isFetching: true })

      const { chain, indexerEndpoint, contracts } = useNetworkStore.getState().config
      const underlyingAddress = contracts.BoardUnderlyingToken?.address
      if (!underlyingAddress) {
        console.warn('No underlying token configured for current network.')
        set({ pools: [] })
        return
      }

      const resp = await fetch(`${indexerEndpoint}/pools/${chain.id}/${underlyingAddress}`)

      const { data }: GetPoolsResponse = await resp.json()
      if (Array.isArray(data)) {
        set({ pools: data })
      } else {
        console.error('Fetched data is not an array:', data)
      }
    } catch (error) {
      console.error('Error fetching pools:', error)
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
  reset: () => set({ pools: [], isFetching: false, isInitialized: false }),
}))
