import { useCallback, useEffect, useState } from 'react'
import { useWeb3 } from '@/contexts/Web3Provider'
import { toast } from 'sonner'
import { Erc721ABI } from '../../../../packages/abis'

interface Props {
  actor?: `0x${string}`
  tokenId?: bigint
  spender?: `0x${string}`
  tokenAddress?: `0x${string}`
}

export function useApproveNFT({ actor, tokenId, spender, tokenAddress }: Props) {
  const [isApproving, setIsApproving] = useState(false)
  const [isApproved, setIsApproved] = useState(false)
  const { walletClient, publicClient } = useWeb3()

  const handleRevokeAllowance = async () => {
    toast('TOOD: Revoking allowance...')
  }

  /**
   * Handle the approval process for the tokens
   * @param amount - The amount of tokens to approve
   * @returns void
   */
  const handleApprove = async (tokenId: bigint) => {
    if (!actor || !tokenId || !spender || !tokenAddress) {
      toast('Missing required parameters.')
      return
    }

    try {
      if (!walletClient) {
        toast('Wallet not connected')
        return
      }

      setIsApproving(true)

      // Signer get nonce
      const nonce = await publicClient.getTransactionCount({
        address: actor,
      })

      const { request } = await publicClient.simulateContract({
        nonce,
        account: actor,
        address: tokenAddress,
        abi: Erc721ABI,
        functionName: 'approve',
        args: [spender, BigInt(tokenId)],
      })

      const hash = await walletClient.writeContract(request)

      console.log('Transaction Hash:', hash)
      console.log('Waiting for txn to be mined...')
      const receipt = await publicClient.waitForTransactionReceipt({
        hash: hash,
        confirmations: 2,
        pollingInterval: 2000,
      })

      setIsApproved(true)

      console.log('Transaction Receipt:', receipt)
      toast('Tokens approved!')

      // Refetch allowance
      memoizedFetchApproval()
    } catch (error) {
      console.error('Error during approval process:', error)
      // @ts-ignore
      if (error?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error during approval process')
      }
    } finally {
      setIsApproving(false)
    }
  }

  const fetchApproval = async (
    tokenId: bigint,
    spender: `0x${string}`,
    tokenAddress: `0x${string}`,
  ) => {
    if (!tokenId || !spender || !tokenAddress) {
      return
    }

    const currentApproved = await publicClient.readContract({
      address: tokenAddress,
      abi: Erc721ABI,
      functionName: 'getApproved',
      args: [BigInt(tokenId)],
    })

    setIsApproved(spender === currentApproved)
  }

  // Calculate hasAllowance each time amount changes
  useEffect(() => {
    if (tokenId && spender && tokenAddress) {
      fetchApproval(tokenId, spender, tokenAddress)
    }
  }, [tokenId, spender, tokenAddress])

  // Re-fetch approval when actor, tokenId, spender, or tokenAddress changes
  const memoizedFetchApproval = useCallback(async () => {
    if (actor && tokenId && spender && tokenAddress) {
      await fetchApproval(tokenId, spender, tokenAddress)
    }
  }, [actor, tokenId, spender, tokenAddress])

  useEffect(() => {
    memoizedFetchApproval()
  }, [memoizedFetchApproval])

  if (!actor || !tokenId || !spender || !tokenAddress) {
    return {
      isApproving: false,
      isApproved: false,
      handleApprove: () => {},
    }
  }

  return {
    isApproving,
    handleApprove,
    isApproved,
    handleRevokeAllowance,
  }
}
