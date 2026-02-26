import { create } from 'zustand'
import type { Initiative } from '@/indexers/api/types'

interface SupportDrawerState {
  selectedInitiative: Initiative | null
  isOpen: boolean
  openDrawer: (initiative: Initiative) => void
  closeDrawer: () => void
  reset: () => void
}

export const useSupportDrawerStore = create<SupportDrawerState>((set) => ({
  selectedInitiative: null,
  isOpen: false,
  openDrawer: (initiative) => set({ selectedInitiative: initiative, isOpen: true }),
  closeDrawer: () => set({ isOpen: false }),
  reset: () => set({ selectedInitiative: null, isOpen: false }),
}))