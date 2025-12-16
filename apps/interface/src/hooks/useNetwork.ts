'use client'

import { useNetworkConfig } from './useNetworkConfig'

/**
 * Hook to get the current network configuration
 * @deprecated Use useNetworkConfig directly instead
 */
export const useNetwork = () => {
  const { network: selected, config } = useNetworkConfig()

  return {
    selected,
    config,
  }
}
