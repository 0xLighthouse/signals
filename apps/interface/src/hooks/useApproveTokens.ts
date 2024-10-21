import { useState } from 'react'
import { createWalletClient, custom } from 'viem'
import { hardhat } from 'viem/chains'
import { toast } from 'sonner'
import { readClient } from '@/config/web3'
import { ABI } from '@/config/web3'

interface Props {
  actor?: `0x${string}`
  decimals?: number
  spenderAddress?: string
  tokenAddress?: `0x${string}`
}

export function useApproveTokens({
  actor,
  decimals,
  spenderAddress,
  tokenAddress,
}: Props) {
  const [isApproving, setIsApproving] = useState(false)

  const handleApprove = async (amount: number) => {
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
        chain: hardhat,
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
      // const receipt = await readClient.waitForTransactionReceipt({
      //   hash: hash,
      //   confirmations: 2,
      //   pollingInterval: 2000,
      // })

      // console.log('Transaction Receipt:', receipt)
      toast('Tokens approved!')
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

  return { isApproving, handleApprove }
}
