import type { NormalisedInitiative } from '@/app/api/initiatives/route'
import { create } from 'zustand'

interface InitiativesState {
  initiatives: NormalisedInitiative[]
  isFetching: boolean
  isInitialized: boolean
  fetchInitiatives: () => Promise<void>
}

export const useInitiativesStore = create<InitiativesState>((set) => ({
  initiatives: [],
  isFetching: false,
  isInitialized: false,
  fetchInitiatives: async () => {
    try {
      set({ isFetching: true })
      const response = await fetch(`/api/initiatives?ts=${Date.now()}`)
      const data = await response.json()
      if (Array.isArray(data)) {
        set({ initiatives: data })
      } else {
        console.error('Fetched data is not an array:', data)
      }
    } catch (error) {
      console.error('Error fetching initiatives:', error)
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
}))
