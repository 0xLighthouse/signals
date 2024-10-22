import { useCallback, useEffect, useState } from 'react'
import { createWalletClient, custom } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { toast } from 'sonner'
import { readClient } from '@/config/web3'
import { ABI } from '@/config/web3'

interface Props {
  actor?: `0x${string}`
  amount?: number | null
  decimals?: number
  spenderAddress?: string
  tokenAddress?: `0x${string}`
}

export function useApproveTokens({ amount, actor, decimals, spenderAddress, tokenAddress }: Props) {
  const [isApproving, setIsApproving] = useState(false)
  const [hasAllowance, setHasAllowance] = useState(false)

  const handleApprove = useCallback(async (amount: number) => {
    if (!actor || !amount || !spenderAddress || !tokenAddress) {
      toast('Missing required parameters.')
      return
    }

    try {
      setIsApproving(true)
      // Signer get nonce
      const nonce = await readClient.getTransactionCount({
        address: actor,
      })

      const signer = createWalletClient({
        chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
        transport: custom(window.ethereum),
      })
      const { request } = await readClient.simulateContract({
        nonce,
        account: actor,
        address: tokenAddress,
        abi: ABI,
        functionName: 'approve',
        args: [spenderAddress, amount * 10 ** (decimals || 18)],
      })

      const hash = await signer.writeContract(request)
      console.log('Transaction Hash:', hash)
      console.log('Waiting for txn to be mined...')
      const receipt = await readClient.waitForTransactionReceipt({
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
  }, [actor, spenderAddress, tokenAddress, decimals])

  const checkAllowance = useCallback(async () => {
    if (!amount || !actor || !spenderAddress || !tokenAddress) return

    const allowance = await readClient.readContract({
      address: tokenAddress,
      abi: ABI,
      functionName: 'allowance',
      args: [actor, spenderAddress],
    })

    const _hasAllowance = Number(allowance) >= amount * 10 ** (decimals || 18)
    console.log('hasAllowance', _hasAllowance)
    setHasAllowance(_hasAllowance)
  }, [amount, actor, spenderAddress, tokenAddress, decimals])

  useEffect(() => {
    if (actor && amount && spenderAddress && tokenAddress && decimals) {
      checkAllowance()
    }
  }, [actor, amount, spenderAddress, tokenAddress, decimals, checkAllowance])

  return { isApproving, hasAllowance, handleApprove }
}
