import { create } from 'zustand'

import { NETWORKS } from '@/config/networks'
import type { NetworkConfig, SupportedNetworks } from '@/config/network-types'
import { DEFAULT_NETWORK } from '@/config/network-config'

type IndexerStatus = 'ready' | 'indexing' | 'unknown'

interface NetworkState {
  selected: SupportedNetworks
  config: NetworkConfig
  indexerStatus: IndexerStatus
  setNetwork: (key: SupportedNetworks) => void
  hydrateFromEnv: () => void
  checkIndexerStatus: () => Promise<IndexerStatus>
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

export const useNetworkStore = create<NetworkState>((set, get) => ({
  selected: initialKey,
  config: initialConfig,
  indexerStatus: 'unknown',
  setNetwork: (key) => {
    const nextConfig = NETWORKS[key]
    if (!nextConfig) {
      console.warn(`Attempted to set unsupported network: ${key}`)
      return
    }

    set({
      selected: key,
      config: nextConfig,
      indexerStatus: 'unknown',
    })
  },
  hydrateFromEnv: () => {
    set({
      selected: initialKey,
      config: initialConfig,
    })
  },
  checkIndexerStatus: async () => {
    const { indexerEndpoint } = get().config
    try {
      const res = await fetch(`${indexerEndpoint}/ready`)
      const status: IndexerStatus = res.status === 503 ? 'indexing' : 'ready'
      set({ indexerStatus: status })
      return status
    } catch {
      set({ indexerStatus: 'unknown' })
      return 'unknown'
    }
  },
}))

export const getActiveNetwork = (): NetworkConfig => useNetworkStore.getState().config
