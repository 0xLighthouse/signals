import type { Lock, LockResponse } from '../../../indexers/src/api/types'
import { context } from '@/config/web3'
import { create } from 'zustand'

interface LocksState {
  count: number
  locks: Lock[]
  isFetching: boolean
  isInitialized: boolean
  fetchLocks: (signerAddress: string) => Promise<void>
}

const API_ENDPOINT = 'http://localhost:42069'

// TODO: These values can be dynamic now..
const CHAIN_ID = 421614
const ADDRESS = context.contracts.SignalsProtocol.address

export const useLocksStore = create<LocksState>((set) => ({
  count: 0,
  locks: [],
  isFetching: false,
  isInitialized: false,
  fetchLocks: async (signerAddress: string) => {
    try {
      set({ isFetching: true })

      const resp = await fetch(`${API_ENDPOINT}/locks/${CHAIN_ID}/${ADDRESS}/${signerAddress}`)

      console.log('endpoint', `${API_ENDPOINT}/locks/${CHAIN_ID}/${ADDRESS}/${signerAddress}`)
      const { data }: LockResponse = await resp.json()
      if (Array.isArray(data)) {
        set({ locks: data, count: data.length })
      } else {
        console.error('Fetched data is not an array:', data)
      }
    } catch (error) {
      console.error('Error fetching locks:', error)
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
}))
