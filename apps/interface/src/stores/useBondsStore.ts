import type { InitiativeLock, Lock, LockResponse } from 'indexers/src/api/types'
import { context, INDEXER_ENDPOINT } from '@/config/web3'
import { create } from 'zustand'

interface BondsState {
  initiativeLocks: InitiativeLock[]
  bondsOwned: Lock[]
  bondsAvailable: Lock[]
  isFetchingInitiativeLocks: boolean
  isInitiativeLocksInitialized: boolean
  isFetchingBondsOwned: boolean
  isBondsOwnedInitialized: boolean
  isBondsAvailableFetching: boolean
  isBondsAvailableInitalized: boolean
  fetchInitiativeLocks: (initiativeId: string) => Promise<void>
  fetchBondsOwned: (userAddress: string) => Promise<void>
  fetchBondsAvailable: (hookAddress: string) => Promise<void>
}

// TODO: These values can be dynamic now..
const CHAIN_ID = 421614
const BOARD = context.contracts.SignalsProtocol.address

export const useBondsStore = create<BondsState>((set, get) => ({
  initiativeLocks: [],
  isFetchingInitiativeLocks: false,
  isInitiativeLocksInitialized: false,

  bondsOwned: [],
  isFetchingBondsOwned: false,
  isBondsOwnedInitialized: false,

  bondsAvailable: [],
  isBondsAvailableFetching: false,
  isBondsAvailableInitalized: false,

  fetchInitiativeLocks: async (initiativeId: string) => {
    // Prevent duplicate fetches
    if (get().isFetchingInitiativeLocks || get().isInitiativeLocksInitialized) return

    try {
      set({ isFetchingBondsOwned: true })

      const resp = await fetch(`${INDEXER_ENDPOINT}/locks/${CHAIN_ID}/${BOARD}/${initiativeId}`)
      const { data } = await resp.json()

      if (Array.isArray(data)) {
        set({
          initiativeLocks: data as InitiativeLock[],
          isFetchingInitiativeLocks: false,
          isInitiativeLocksInitialized: true,
        })
      } else {
        console.error('Fetched user data is not an array:', data)
        set({
          initiativeLocks: [],
          isFetchingInitiativeLocks: false,
          isInitiativeLocksInitialized: true,
        })
      }
    } catch (error) {
      console.error(`Error fetching initiative locks for ${initiativeId}:`, error)
      set({
        initiativeLocks: [],
        isFetchingInitiativeLocks: false,
        isInitiativeLocksInitialized: true,
      })
    }
  },

  fetchBondsOwned: async (userAddress: string) => {
    // Prevent duplicate fetches
    if (get().isFetchingBondsOwned || get().isBondsOwnedInitialized) return

    try {
      set({ isFetchingBondsOwned: true })

      const resp = await fetch(`${INDEXER_ENDPOINT}/bonds/${CHAIN_ID}/${BOARD}/${userAddress}`)
      const { data }: LockResponse = await resp.json()

      if (Array.isArray(data)) {
        set({
          bondsOwned: data,
          isFetchingBondsOwned: false,
          isBondsOwnedInitialized: true,
        })
      } else {
        console.error('Fetched user data is not an array:', data)
        set({
          bondsOwned: [],
          isFetchingBondsOwned: false,
          isBondsOwnedInitialized: true,
        })
      }
    } catch (error) {
      console.error(`Error fetching bonds for user ${userAddress}:`, error)
      set({
        bondsOwned: [],
        isFetchingBondsOwned: false,
        isBondsOwnedInitialized: true,
      })
    }
  },

  fetchBondsAvailable: async (hookAddress: string) => {
    // Prevent duplicate fetches
    if (get().isBondsAvailableFetching || get().isBondsAvailableInitalized) return

    try {
      set({ isBondsAvailableFetching: true })

      const resp = await fetch(`${INDEXER_ENDPOINT}/bonds/${CHAIN_ID}/${BOARD}/${hookAddress}`)
      const { data }: LockResponse = await resp.json()

      if (Array.isArray(data)) {
        set({
          bondsAvailable: data,
          isBondsAvailableFetching: false,
          isBondsAvailableInitalized: true,
        })
      } else {
        console.error('Fetched hook data is not an array:', data)
        set({
          bondsAvailable: [],
          isBondsAvailableFetching: false,
          isBondsAvailableInitalized: true,
        })
      }
    } catch (error) {
      console.error(`Error fetching bonds for hook ${hookAddress}:`, error)
      set({
        bondsAvailable: [],
        isBondsAvailableFetching: false,
        isBondsAvailableInitalized: true,
      })
    }
  },
}))
