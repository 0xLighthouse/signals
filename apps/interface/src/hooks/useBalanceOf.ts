import { useEffect, useState } from 'react'

import { usePublicClient } from '@/contexts/ChainProvider'
import { useWeb3 } from '@/contexts/WalletProvider'

const BALANCE_OF_ABI = [
  {
    inputs: [{ internalType: 'address', name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export const useBalanceOf = (
  walletAddress?: `0x${string}`,
  contractAddress?: `0x${string}`,
  enabled = true,
) => {
  const { isInitialized } = useWeb3()
  const publicClient = usePublicClient()

  const [balance, setBalance] = useState<bigint | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  const fetchBalance = async () => {
    if (!enabled || !walletAddress || !contractAddress || !isInitialized || !publicClient) {
      setBalance(null)
      return null
    }
    setIsLoading(true)
    try {
      const result = await publicClient.readContract({
        address: contractAddress,
        abi: BALANCE_OF_ABI,
        functionName: 'balanceOf',
        args: [walletAddress],
      })
      setBalance(result as bigint)
      return result
    } catch (error) {
      console.error('Failed to read balanceOf', error)
      setBalance(null)
      return null
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void fetchBalance()
    // We intentionally include walletAddress/contractAddress/isInitialized/enabled to refetch on change
  }, [walletAddress, contractAddress, isInitialized, enabled])

  return {
    balance,
    isLoading,
    refetch: fetchBalance,
  }
}
