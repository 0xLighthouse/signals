import type { Pool, GetPoolsResponse } from '../../../indexers/src/api/types'
import { context } from '@/config/web3'
import { create } from 'zustand'

interface PoolsState {
  pools: Pool[]
  isFetching: boolean
  isInitialized: boolean
  fetchPools: () => Promise<void>
}

// const API_ENDPOINT = 'https://signals-production-6591.up.railway.app'
const API_ENDPOINT = 'http://localhost:42069'

// TODO: These values can be dynamic now..
const CHAIN_ID = 421614
const CURRENCY = context.contracts.BoardUnderlyingToken.address

export const usePoolsStore = create<PoolsState>((set) => ({
  pools: [],
  isFetching: false,
  isInitialized: false,
  fetchPools: async () => {
    try {
      set({ isFetching: true })

      const resp = await fetch(`${API_ENDPOINT}/pools/${CHAIN_ID}/${CURRENCY}`)
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
}))
