'use client'

import { useCallback, useEffect, useState } from 'react'
import { createPublicClient, getContract, http } from 'viem'
import { erc20Abi } from 'viem'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { normaliseNumber } from '@/lib/utils'

// Cache for total supply by token address
const cache = new Map<`0x${string}`, { value: string; timestamp: number }>()
const CACHE_DURATION = 5 * 60 * 1000 // 5 minutes

interface UseTotalSupplyResult {
  totalSupply: string | null
  isLoading: boolean
  error: Error | null
  refetch: () => Promise<void>
}

/**
 * Hook to fetch and cache ERC20 token total supply
 * @param tokenAddress - The ERC20 token address
 * @returns Total supply formatted as string, loading state, error, and refetch function
 */
export function useTotalSupply(tokenAddress: `0x${string}` | undefined | null): UseTotalSupplyResult {
  const [totalSupply, setTotalSupply] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchTotalSupply = useCallback(async () => {
    if (!tokenAddress) {
      setTotalSupply(null)
      setIsLoading(false)
      return
    }

    // Check cache first
    const cached = cache.get(tokenAddress)
    const now = Date.now()
    if (cached && now - cached.timestamp < CACHE_DURATION) {
      setTotalSupply(cached.value)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const { chain, rpcUrl } = useNetworkStore.getState().config

      const readClient = createPublicClient({
        chain,
        transport: http(rpcUrl),
      })

      const token = getContract({
        address: tokenAddress,
        abi: erc20Abi,
        client: readClient,
      })

      // Fetch decimals and totalSupply in parallel
      const [decimals, totalSupplyRaw] = await Promise.all([
        token.read.decimals(),
        token.read.totalSupply(),
      ])

      // Format the total supply
      const decimalsNum = Number(decimals)
      const totalSupplyNum = Number(totalSupplyRaw)
      const adjusted = totalSupplyNum / 10 ** decimalsNum

      // Format with appropriate precision
      let formatted: string
      if (adjusted >= 1000000) {
        formatted = `${normaliseNumber(adjusted)}`
      } else if (adjusted >= 1000) {
        formatted = adjusted.toLocaleString('en-US', { maximumFractionDigits: 2 })
      } else {
        formatted = adjusted.toLocaleString('en-US', { maximumFractionDigits: decimalsNum })
      }

      // Update cache
      cache.set(tokenAddress, { value: formatted, timestamp: now })
      setTotalSupply(formatted)
    } catch (err) {
      const error = err instanceof Error ? err : new Error('Failed to fetch total supply')
      setError(error)
      setTotalSupply(null)
      console.error('Error fetching total supply:', error)
    } finally {
      setIsLoading(false)
    }
  }, [tokenAddress])

  useEffect(() => {
    void fetchTotalSupply()
  }, [fetchTotalSupply])

  const refetch = useCallback(async () => {
    if (tokenAddress) {
      // Bust cache
      cache.delete(tokenAddress)
      await fetchTotalSupply()
    }
  }, [tokenAddress, fetchTotalSupply])

  return {
    totalSupply,
    isLoading,
    error,
    refetch,
  }
}
