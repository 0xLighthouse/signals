'use client'

import React, { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { custom, useAccount } from 'wagmi'
import { readClient, ABI, ERC20_ADDRESS } from '@/config/web3'
import { useUnderlying } from '@/contexts/ContractContext'
import { hardhat } from 'viem/chains'
import { createWalletClient, formatEther } from 'viem'
import { toast } from 'sonner'
import { useSignals } from '@/contexts/SignalsContext'

export const FaucetBar = () => {
  const { address } = useAccount()
  const { name, symbol, totalSupply, balance } = useUnderlying()
  const { formatter } = useSignals()

  const [gas, setGas] = useState<number>(0)

  useEffect(() => {
    const fetchGasBalance = async () => {
      try {
        if (!address) return
        const gasBalance = await readClient.getBalance({
          address,
        })
        setGas(Number(gasBalance))
      } catch (error) {
        console.error('Error fetching gas balance:', error)
      }
    }
    fetchGasBalance()
  }, [address])

  const handleClaimTokens = async () => {
    if (!address) throw new Error('Address not available.')

    try {
      const nonce = await readClient.getTransactionCount({
        address,
      })

      const signer = createWalletClient({
        chain: hardhat,
        transport: custom(window.ethereum),
      })

      const transactionHash = await signer.writeContract({
        account: address,
        nonce,
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'faucet',
        args: [address],
        gas: 100_000n,
      })

      console.log('Transaction Hash:', transactionHash)

      const receipt = await readClient.waitForTransactionReceipt({
        hash: transactionHash,
      })

      toast(`Claimed ${symbol} tokens`)
      console.log('Transaction Receipt:', receipt)
    } catch (error) {
      console.error('Error claiming tokens:', error)
    }
  }

  return (
    <div className="flex items-center justify-between p-4 bg-white dark:bg-neutral-900 shadow-md rounded-lg">
      <div className="flex flex-1 justify-evenly text-center">
        <div>
          <span className="text-2xl font-bold">{formatter(balance)}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">Balance ({symbol})</p>
        </div>
        <div>
          <span className="text-2xl font-bold">{formatter(totalSupply)}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">Supply</p>
        </div>
        <div>
          <span className="text-2xl font-bold">{formatter(gas)}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">Gas (ETH)</p>
        </div>
      </div>
      <Button onClick={handleClaimTokens} className="ml-4">
        Claim tokens
      </Button>
    </div>
  )
}
