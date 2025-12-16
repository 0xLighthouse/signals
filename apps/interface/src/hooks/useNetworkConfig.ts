'use client'

import { useParams } from 'next/navigation'
import { useMemo } from 'react'
import { NETWORKS } from '@/config/networks'
import { getNetworkFromSlug } from '@/lib/routing'
import type { SupportedNetworks, NetworkConfig } from '@/config/network-types'
import { DEFAULT_NETWORK } from '@/config/network-config'

// Ensure we always fall back to a supported network, even if env misconfigured
const FALLBACK_NETWORK: SupportedNetworks =
  (DEFAULT_NETWORK in NETWORKS ? DEFAULT_NETWORK : 'baseSepolia') as SupportedNetworks

export function resolveNetworkConfig(
  networkParam?: string | string[],
): { network: SupportedNetworks; config: NetworkConfig } {
  const networkSlug = Array.isArray(networkParam) ? networkParam[0] : networkParam
  const networkKey = networkSlug ? getNetworkFromSlug(networkSlug) : null

  const resolvedKey =
    (networkKey && NETWORKS[networkKey] ? networkKey : FALLBACK_NETWORK) as SupportedNetworks

  return {
    network: resolvedKey,
    config: NETWORKS[resolvedKey],
  }
}

/**
 * Hook to get the current network configuration from the URL
 * This is the single source of truth for network configuration
 */
export function useNetworkConfig(): {
  network: SupportedNetworks
  config: NetworkConfig
} {
  const params = useParams()

  return useMemo(() => resolveNetworkConfig(params?.network), [params?.network])
}
