'use client'

import { useMemo } from 'react'

import { useNetworkStore } from '@/stores/useNetworkStore'

export const useNetwork = () => {
  const selected = useNetworkStore((state) => state.selected)
  const config = useNetworkStore((state) => state.config)
  const setNetwork = useNetworkStore((state) => state.setNetwork)

  return useMemo(
    () => ({
      selected,
      config,
      setNetwork,
    }),
    [selected, config, setNetwork]
  )
}
