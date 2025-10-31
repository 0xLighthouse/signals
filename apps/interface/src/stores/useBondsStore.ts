import type { InitiativeLock, Lock, LockResponse } from 'indexers/src/api/types'
import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

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
  reset: () => void
}

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
    const state = get()
    if (state.isFetchingInitiativeLocks || state.isInitiativeLocksInitialized || state.isFetchingInitiativeLocks) return

    try {
      set({ isFetchingInitiativeLocks: true })

      const { chain, indexerEndpoint, contracts } = useNetworkStore.getState().config
      const boardAddress = contracts.SignalsProtocol?.address
      if (!boardAddress) {
        console.warn('No Signals board configured for current network.')
        set({
          initiativeLocks: [],
          isFetchingInitiativeLocks: false,
          isInitiativeLocksInitialized: true,
        })
        return
      }

      const resp = await fetch(`${indexerEndpoint}/locks/${chain.id}/${boardAddress}/${initiativeId}`)
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

      const { chain, indexerEndpoint, contracts } = useNetworkStore.getState().config
      const boardAddress = contracts.SignalsProtocol?.address
      if (!boardAddress) {
        console.warn('No Signals board configured for current network.')
        set({
          bondsOwned: [],
          isFetchingBondsOwned: false,
          isBondsOwnedInitialized: true,
        })
        return
      }

      const resp = await fetch(`${indexerEndpoint}/bonds/${chain.id}/${boardAddress}/${userAddress}`)
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

      const { chain, indexerEndpoint, contracts } = useNetworkStore.getState().config
      const boardAddress = contracts.SignalsProtocol?.address
      if (!boardAddress) {
        console.warn('No Signals board configured for current network.')
        set({
          bondsAvailable: [],
          isBondsAvailableFetching: false,
          isBondsAvailableInitalized: true,
        })
        return
      }

      const resp = await fetch(`${indexerEndpoint}/bonds/${chain.id}/${boardAddress}/${hookAddress}`)
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
  reset: () =>
    set({
      initiativeLocks: [],
      isInitiativeLocksInitialized: false,
      isFetchingInitiativeLocks: false,
      bondsOwned: [],
      isFetchingBondsOwned: false,
      isBondsOwnedInitialized: false,
      bondsAvailable: [],
      isBondsAvailableFetching: false,
      isBondsAvailableInitalized: false,
    }),
}))
