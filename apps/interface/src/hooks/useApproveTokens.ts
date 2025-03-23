import { useCallback, useEffect, useState } from 'react'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { toast } from 'sonner'
import { readClient } from '@/config/web3'
import { useWeb3 } from '@/contexts/Web3Provider'
import { ERC20WithFaucetABI } from '@/config/web3'

interface Props {
  actor?: `0x${string}`
  amount?: number | null
  decimals?: number
  spenderAddress?: `0x${string}`
  tokenAddress?: `0x${string}`
}

export function useApproveTokens({ amount, actor, decimals, spenderAddress, tokenAddress }: Props) {
  const [isApproving, setIsApproving] = useState(false)
  const [hasAllowance, setHasAllowance] = useState(false)
  const { walletClient, publicClient } = useWeb3()

  const handleApprove = useCallback(
    async (amount: number) => {
      if (!actor || !amount || !spenderAddress || !tokenAddress) {
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
          args: [spenderAddress, BigInt(amount * 10 ** (decimals || 18))],
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
    },
    [amount, actor, spenderAddress, tokenAddress, decimals, publicClient],
  )

  const checkAllowance = useCallback(async () => {
    if (!amount || !actor || !spenderAddress || !tokenAddress) return

    const allowance = await publicClient.readContract({
      address: tokenAddress,
      abi: ERC20WithFaucetABI,
      functionName: 'allowance',
      args: [actor, spenderAddress],
    })

    const _hasAllowance = Number(allowance) >= amount * 10 ** (decimals || 18)
    console.log('hasAllowance', _hasAllowance)
    setHasAllowance(_hasAllowance)
  }, [amount, actor, spenderAddress, tokenAddress, decimals, publicClient])

  useEffect(() => {
    if (actor && amount && spenderAddress && tokenAddress && decimals) {
      checkAllowance()
    }
  }, [actor, amount, spenderAddress, tokenAddress, decimals, checkAllowance])

  return { isApproving, hasAllowance, handleApprove }
}
