'use client'

import { useEffect } from 'react'
import { useParams } from 'next/navigation'
import { useRouteStore } from '@/stores/useRouteStore'
import { getNetworkFromSlug } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'

/**
 * Client component that syncs URL params to the route store
 * This must be a Client Component because Zustand stores are client-side only
 */
export function RouteSync() {
  const params = useParams()
  const setBoardAddress = useRouteStore((state) => state.setBoardAddress)
  const setNetwork = useRouteStore((state) => state.setNetwork)

  useEffect(() => {
    const networkSlug = Array.isArray(params?.network)
      ? params.network[0]
      : (params?.network as string | undefined)
    const boardAddressParam = Array.isArray(params?.boardAddress)
      ? params.boardAddress[0]
      : (params?.boardAddress as string | undefined)

    if (networkSlug) {
      const network = getNetworkFromSlug(networkSlug)
      if (network) {
        setNetwork(network)
      }
    }

    if (boardAddressParam) {
      setBoardAddress(boardAddressParam.toLowerCase() as `0x${string}`)
    }
  }, [params, setBoardAddress, setNetwork])

  return null
}
