'use client'

import { useCallback, useEffect, useState } from 'react'
import { client } from '@/config/ponder'
import { context } from '@/config/web3'
import { useWeb3 } from '@/contexts/Web3Provider'

export interface Board {
  id: string
  contractAddress: string
  chainId: number
}

export function useBoardAutocomplete() {
  const { publicClient, isInitialized } = useWeb3()
  const [boards, setBoards] = useState<Board[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchBoards = useCallback(async () => {
    // Don't fetch if web3 isn't initialized yet
    if (!isInitialized) {
      return
    }

    // Get chain ID from the public client
    const chainId = publicClient.chain?.id || context.network.arbitrumSepolia.chainId

    setIsLoading(true)
    setError(null)

    try {
      // const result = await client.select({
      //   $q: (c) =>
      //     c
      //       .from('boards')
      //       .where({ chainId })
      //       .select({
      //         id: true,
      //         contractAddress: true,
      //         chainId: true,
      //       }),
      // })
      // TODO: Remove this once the query is working
      setBoards([])
    } catch (err) {
      console.error('Error fetching boards:', err)
      setError(err instanceof Error ? err : new Error('Failed to fetch boards'))
      setBoards([])
    } finally {
      setIsLoading(false)
    }
  }, [publicClient.chain?.id, isInitialized])

  useEffect(() => {
    fetchBoards()
  }, [fetchBoards])

  return { boards, isLoading, error, refetch: fetchBoards }
}
