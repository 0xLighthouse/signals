import { useCallback, useEffect, useRef, useState } from 'react'
import { useWeb3 } from '@/contexts/Web3Provider'
import { ERC20WithFaucetABI } from '@/config/web3'
import { toast } from 'sonner'

interface Props {
  actor?: `0x${string}`
  amount?: number
  spender?: `0x${string}`
  tokenAddress?: `0x${string}`
  tokenDecimals: number
}

export function useApproveTokens({ amount, actor, tokenDecimals, spender, tokenAddress }: Props) {
  const [isApproving, setIsApproving] = useState(false)
  const [allowance, setAllowance] = useState(0n)
  const [formattedAllowance, setFormattedAllowance] = useState(0)
  const [hasAllowance, setHasAllowance] = useState(false)
  const { walletClient, publicClient } = useWeb3()

  const handleRevokeAllowance = async () => {
    toast('TOOD: Revoking allowance...')
  }

  /**
   * Handle the approval process for the tokens
   * @param amount - The amount of tokens to approve
   * @returns void
   */
  const handleApprove = async (amount: number) => {
    if (!actor || !amount || !spender || !tokenAddress) {
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
        abi: ERC20WithFaucetABI,
        functionName: 'approve',
        args: [spender, BigInt(amount * 10 ** (tokenDecimals || 18))],
      })

      const hash = await walletClient.writeContract(request)
      console.log('Transaction Hash:', hash)
      console.log('Waiting for txn to be mined...')
      const receipt = await publicClient.waitForTransactionReceipt({
        hash: hash,
        confirmations: 2,
        pollingInterval: 2000,
      })

      console.log('Transaction Receipt:', receipt)
      toast('Tokens approved!')
      setHasAllowance(true)
      // Refetch allowance
      memoizedFetchAllowance()
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

  const fetchAllowance = async (
    actor: `0x${string}`,
    spender: `0x${string}`,
    tokenAddress: `0x${string}`,
  ) => {
    const allowance = await publicClient.readContract({
      address: tokenAddress,
      abi: ERC20WithFaucetABI,
      functionName: 'allowance',
      args: [actor, spender],
    })

    setAllowance(allowance)
    setFormattedAllowance(Number(allowance) / 10 ** (tokenDecimals || 18))
  }

  const calculateHasAllowance = (allowance: bigint, amount: number, tokenDecimals: number) => {
    const _hasAllowance = Number(allowance) >= Number(amount) * 10 ** tokenDecimals
    setHasAllowance(_hasAllowance)
  }

  // Calculate hasAllowance each time amount changes
  useEffect(() => {
    if (allowance && amount && tokenDecimals) {
      calculateHasAllowance(allowance, amount, tokenDecimals)
    }
  }, [amount, allowance, tokenDecimals])

  // Re-fetch allowance when actor, spender, or tokenAddress changes
  const memoizedFetchAllowance = useCallback(async () => {
    if (actor && spender && tokenAddress) {
      await fetchAllowance(actor, spender, tokenAddress)
    }
  }, [actor, spender, tokenAddress])

  useEffect(() => {
    memoizedFetchAllowance()
  }, [memoizedFetchAllowance])

  return {
    isApproving,
    hasAllowance,
    handleApprove,
    allowance,
    formattedAllowance,
    handleRevokeAllowance,
  }
}
