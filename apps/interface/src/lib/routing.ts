import { NETWORKS } from '@/config/networks'
import type { SupportedNetworks } from '@/config/network-types'

/**
 * Maps network names to URL-friendly slugs
 */
export const NETWORK_SLUGS: Record<SupportedNetworks, string> = {
  local: 'local',
  arbitrumSepolia: 'arbitrum-sepolia',
  base: 'base',
}

/**
 * Reverse mapping of slugs to network names
 */
export const SLUG_TO_NETWORK = Object.entries(NETWORK_SLUGS).reduce(
  (acc, [network, slug]) => {
    acc[slug] = network as SupportedNetworks
    return acc
  },
  {} as Record<string, SupportedNetworks>,
)

/**
 * Get network config from URL slug
 */
export function getNetworkFromSlug(slug: string): SupportedNetworks | null {
  return SLUG_TO_NETWORK[slug] || null
}

/**
 * Get URL slug from network name
 */
export function getSlugFromNetwork(network: SupportedNetworks): string {
  return NETWORK_SLUGS[network]
}

/**
 * Get default network (from env or fallback to base)
 */
export function getDefaultNetwork(): SupportedNetworks {
  const envNetwork = process.env.NEXT_PUBLIC_DEFAULT_NETWORK as SupportedNetworks
  return envNetwork && envNetwork in NETWORKS ? envNetwork : 'base'
}

/**
 * Build board URL
 */
export function getBoardUrl(network: SupportedNetworks, boardAddress: string): string {
  return `/${getSlugFromNetwork(network)}/${boardAddress.toLowerCase()}`
}

/**
 * Build network URL
 */
export function getNetworkUrl(network: SupportedNetworks): string {
  return `/${getSlugFromNetwork(network)}`
}
