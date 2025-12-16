import type { Chain } from 'viem'
import { arbitrumSepolia, base, baseSepolia } from 'viem/chains'

import { NETWORK_CONFIG } from '@/config/network-config'

export const CHAINS = {
  base,
  baseSepolia,
  arbitrumSepolia,
} as const satisfies Record<string, Chain>

export type ChainKey = keyof typeof CHAINS

export const RPCS: Record<ChainKey, string> = {
  base: NETWORK_CONFIG.base.rpcUrl,
  baseSepolia: NETWORK_CONFIG.baseSepolia.rpcUrl,
  arbitrumSepolia: NETWORK_CONFIG.arbitrumSepolia.rpcUrl,
}
