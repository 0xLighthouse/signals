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

const resolveInitialKey = (): SupportedNetworks => {
  if (DEFAULT_NETWORK in NETWORKS) {
    return DEFAULT_NETWORK as SupportedNetworks
  }
  // Fallback to baseSepolia instead of 'local' which no longer exists
  console.warn('DEFAULT_NETWORK not found in NETWORKS, falling back to baseSepolia')
  return 'baseSepolia'
}

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
