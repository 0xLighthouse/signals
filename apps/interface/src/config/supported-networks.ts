import type { SupportedNetworks } from './network-types'

export interface SupportedNetworkEntry {
  key: SupportedNetworks
  label: string
  /** Icon variant key for @web3icons/react NetworkIcon */
  iconVariant: string
}

export const SUPPORTED_NETWORKS: SupportedNetworkEntry[] = [
  {
    key: 'baseSepolia',
    label: 'Base Sepolia',
    iconVariant: 'base',
  },
  {
    key: 'arbitrumSepolia',
    label: 'Arbitrum Sepolia',
    iconVariant: 'arbitrum',
  },
]
