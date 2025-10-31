import { create } from 'zustand'

import { NETWORKS } from '@/config/networks'
import type { NetworkConfig, SupportedNetworks } from '@/config/network-types'
import { DEFAULT_NETWORK } from '@/config/network-config'

interface NetworkState {
  selected: SupportedNetworks
  config: NetworkConfig
  setNetwork: (key: SupportedNetworks) => void
  hydrateFromEnv: () => void
}

const resolveInitialKey = (): SupportedNetworks =>
  (DEFAULT_NETWORK in NETWORKS ? DEFAULT_NETWORK : 'local') as SupportedNetworks

const initialKey = resolveInitialKey()
const initialConfig = NETWORKS[initialKey]

export const useNetworkStore = create<NetworkState>((set) => ({
  selected: initialKey,
  config: initialConfig,
  setNetwork: (key) => {
    const nextConfig = NETWORKS[key]
    if (!nextConfig) {
      console.warn(`Attempted to set unsupported network: ${key}`)
      return
    }

    set({
      selected: key,
      config: nextConfig,
    })
  },
  hydrateFromEnv: () => {
    set({
      selected: initialKey,
      config: initialConfig,
    })
  },
}))

export const getActiveNetwork = (): NetworkConfig => useNetworkStore.getState().config
