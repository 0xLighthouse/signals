import type { InitiativeLock } from 'indexers/src/api/types'
import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { useRouteStore } from './useRouteStore'

interface LocksState {
  locksByInitiative: Map<string, InitiativeLock[]>
  loadingStates: Map<string, boolean>
  initializedStates: Map<string, boolean>
  fetchInitiativeLocks: (initiativeId: string) => Promise<void>
  reset: () => void
}

export const useLocksStore = create<LocksState>((set, get) => ({
  locksByInitiative: new Map(),
  loadingStates: new Map(),
  initializedStates: new Map(),

  fetchInitiativeLocks: async (initiativeId: string) => {
    const { loadingStates, initializedStates, locksByInitiative } = get()

    // Prevent duplicate fetches for already loading or initialized initiatives
    if (loadingStates.get(initiativeId) || initializedStates.get(initiativeId)) {
      return
    }

    // Set loading state
    set({
      loadingStates: new Map(loadingStates).set(initiativeId, true),
    })

    try {
      const { chain, indexerEndpoint } = useNetworkStore.getState().config
      const boardAddress = useRouteStore.getState().boardAddress

      if (!boardAddress) {
        console.warn('No Signals board configured for current network.')
        set({
          locksByInitiative: new Map(locksByInitiative).set(initiativeId, []),
          loadingStates: new Map(loadingStates).set(initiativeId, false),
          initializedStates: new Map(initializedStates).set(initiativeId, true),
        })
        return
      }

      const resp = await fetch(
        `${indexerEndpoint}/locks/${chain.id}/${boardAddress}/${initiativeId}`,
      )
      const { data } = await resp.json()

      const locks = Array.isArray(data) ? (data as InitiativeLock[]) : []

      set({
        locksByInitiative: new Map(get().locksByInitiative).set(initiativeId, locks),
        loadingStates: new Map(get().loadingStates).set(initiativeId, false),
        initializedStates: new Map(get().initializedStates).set(initiativeId, true),
      })
    } catch (error) {
      console.error(`Error fetching initiative locks for ${initiativeId}:`, error)
      set({
        locksByInitiative: new Map(get().locksByInitiative).set(initiativeId, []),
        loadingStates: new Map(get().loadingStates).set(initiativeId, false),
        initializedStates: new Map(get().initializedStates).set(initiativeId, true),
      })
    }
  },

  reset: () =>
    set({
      locksByInitiative: new Map(),
      loadingStates: new Map(),
      initializedStates: new Map(),
    }),
}))
