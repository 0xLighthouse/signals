import type { NormalisedInitiative } from '@/app/api/initiatives/route';
import { create } from 'zustand';

interface InitiativesState {
  initiatives: NormalisedInitiative[];
  isFetching: boolean;
  fetchInitiatives: () => Promise<void>;
  // refreshInitiatives: () => Promise<void>;
}

export const useInitiativesStore = create<InitiativesState>((set) => ({
  initiatives: [],
  isFetching: false,
  fetchInitiatives: async () => {
    try {
      set({ isFetching: true })
      const response = await fetch('/api/initiatives');
      const data = await response.json();
      if (Array.isArray(data)) {
        set({ initiatives: data });
      } else {
        console.error('Fetched data is not an array:', data);
      }
    } catch (error) {
      console.error('Error fetching initiatives:', error)
    } finally {
      set({ isFetching: false })
    }
  },
}));
