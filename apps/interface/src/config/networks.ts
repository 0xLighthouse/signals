import type { NetworkConfig, SupportedNetworks } from './network-types'
import { NETWORK_CONFIG, ZERO_ADDRESS, ERC20WithFaucetABI } from './network-config'

export { ZERO_ADDRESS, ERC20WithFaucetABI }

export const NETWORKS: Record<SupportedNetworks, NetworkConfig> = NETWORK_CONFIG
