import type { NetworkConfig } from '@/config/network-types'
import { useNetworkStore } from '@/stores/useNetworkStore'

import { SignalsABI } from '../../../../packages/abis'

export { ERC20WithFaucetABI, NETWORKS, ZERO_ADDRESS } from './networks'

export const SIGNALS_ABI = SignalsABI

export const getNetworkConfig = (): NetworkConfig => useNetworkStore.getState().config
