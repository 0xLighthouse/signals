import { useCallback, useEffect, useState } from 'react'
import { useWeb3 } from '@/contexts/WalletProvider'
import { ERC20WithFaucetABI } from '@/config/web3'
import { toast } from 'sonner'
import { useWalletClient } from './use-wallet-client'
import { usePublicClient } from '@/contexts/ChainProvider'

interface Props {
  actor?: `0x${string}`
  amount?: number
  spender?: `0x${string}`
  tokenAddress?: `0x${string}`
  tokenDecimals: number
  enabled?: boolean
}

export function useApproveTokens({
  amount,
  actor,
  tokenDecimals,
  spender,
  tokenAddress,
  enabled = true,
}: Props) {
  const [isApproving, setIsApproving] = useState(false)
  const [allowance, setAllowance] = useState(0n)
  const [formattedAllowance, setFormattedAllowance] = useState(0)
  const [hasAllowance, setHasAllowance] = useState(false)
  // const { walletClient, publicClient } = useWeb3()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
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
      const receipt = await publicClient.waitForTransactionReceipt({
        hash: hash,
        confirmations: 2,
        pollingInterval: 2000,
      })

      console.log('Transaction Receipt:', receipt)
      toast('Tokens approved!')
      setHasAllowance(true)
      // Refetch allowance
      void memoizedFetchAllowance()
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
    try {
      const value = await publicClient.readContract({
        address: tokenAddress,
        abi: ERC20WithFaucetABI,
        functionName: 'allowance',
        args: [actor, spender],
      })
      const next = BigInt(value as bigint)
      setAllowance(next)
      setFormattedAllowance(Number(next) / 10 ** (tokenDecimals || 18))
    } catch (e) {
      console.error('Failed to read allowance', e)
      setAllowance(0n)
      setFormattedAllowance(0)
      setHasAllowance(false)
    }
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

  // Re-fetch allowance when actor, spender, or tokenAddress changes (only when enabled)
  const memoizedFetchAllowance = useCallback(async () => {
    if (!enabled) return
    if (actor && spender && tokenAddress) {
      await fetchAllowance(actor, spender, tokenAddress)
    }
  }, [actor, spender, tokenAddress, enabled])

  useEffect(() => {
    void memoizedFetchAllowance()
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
