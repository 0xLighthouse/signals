import { create } from 'zustand'
import type { SupportedNetworks } from '@/config/network-types'

type RouteState = {
  boardAddress: `0x${string}` | null
  network: SupportedNetworks | null
  setBoardAddress: (address: `0x${string}` | null) => void
  setNetwork: (network: SupportedNetworks | null) => void
  reset: () => void
}

const initialState: Pick<RouteState, 'boardAddress' | 'network'> = {
  boardAddress: null,
  network: null,
}

export const useRouteStore = create<RouteState>((set) => ({
  ...initialState,
  setBoardAddress: (address) => set({ boardAddress: address }),
  setNetwork: (network) => set({ network }),
  reset: () => set(initialState),
}))
