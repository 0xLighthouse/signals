import { useState } from 'react'
import { createWalletClient, custom } from 'viem'
import { hardhat } from 'viem/chains'
import { toast } from 'sonner'
import { readClient } from '@/config/web3'
import { ABI, ERC20_ADDRESS, SIGNALS_PROTOCOL } from '@/config/web3'

export function useApproveTokens(address?: `0x${string}`) {
  const [isApproving, setIsApproving] = useState(false)

  const handleApprove = async (amount: number) => {
    if (!address) {
      toast('Address is not available.')
      return
    }

    try {
      setIsApproving(true)
      // Signer get nonce
      const nonce = await readClient.getTransactionCount({
        address: address,
      })

      const signer = createWalletClient({
        chain: hardhat,
        transport: custom(window.ethereum),
      })
      const { request } = await readClient.simulateContract({
        nonce,
        account: address,
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'approve',
        args: [SIGNALS_PROTOCOL, amount * 1e18],
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
