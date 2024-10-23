'use client'

import React, { useState } from 'react'
import { Button } from '@/components/ui/button'
import { toast } from 'sonner'
import { readClient, ERC20_ADDRESS, USDC_ADDRESS, ABI } from '@/config/web3'
import { createWalletClient, custom } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { Separator } from '@/components/ui/separator'
import { useAccount } from '@/hooks/useAccount'
import { cn } from '@/lib/utils'

const claimTokens = async (token: `0x${string}`, address: `0x${string}`, symbol: string) => {
  if (!address) throw new Error('Address not available.')
  try {
    const nonce = await readClient.getTransactionCount({ address })
    const signer = createWalletClient({
      chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
      transport: custom(window.ethereum),
    })

    const transactionHash = await signer.writeContract({
      account: address,
      nonce,
      address: token,
      abi: ABI,
      functionName: 'faucet',
      args: [address],
      gas: 100_000n,
    })

    console.log('Transaction Hash:', transactionHash)
    console.log('Waiting for txn to be mined...')

    const receipt = await readClient.waitForTransactionReceipt({
      hash: transactionHash,
      confirmations: 2,
      pollingInterval: 2000,
    })

    toast(`Claimed ${symbol} tokens`)
    console.log('Transaction Receipt:', receipt)
  } catch (error) {
    // @ts-ignore
    if (error?.message?.includes('User rejected the request')) {
      toast('User rejected the request')
    } else {
      toast('Error claiming tokens :(')
    }
    console.error('Error claiming tokens:', error)
  }
}

export const FaucetActions = ({ vertical = false }: { vertical?: boolean }) => {
  const { address } = useAccount()
  const [isLoadingUSDC, setIsLoadingUSDC] = useState(false)
  const [isLoadingTokens, setIsLoadingTokens] = useState(false)

  const handleClaimUSDC = async () => {
    setIsLoadingUSDC(true)
    try {
      await claimTokens(USDC_ADDRESS, address as `0x${string}`, 'mUSDC')
    } finally {
      setIsLoadingUSDC(false)
    }
  }

  const handleClaimTokens = async () => {
    setIsLoadingTokens(true)
    try {
      await claimTokens(ERC20_ADDRESS, address as `0x${string}`, 'SGNL')
    } finally {
      setIsLoadingTokens(false)
    }
  }

  if (!address) return null

  return (
    <div className="mt-10 md:mt-20">
      <div className="space-y-2">
        <h4 className="text-md font-bold leading-none">Faucet</h4>
        <p className="text-sm text-muted-foreground">Claim your test tokens</p>
      </div>
      <Separator className="my-4" />
      <div className={cn('flex gap-2', vertical && 'flex-col')}>
        <Button variant="outline" onClick={handleClaimUSDC} isLoading={isLoadingUSDC}>
          Get USDC
        </Button>
        {/* <Separator orientation="vertical" /> */}
        <Button variant="outline" onClick={handleClaimTokens} isLoading={isLoadingTokens}>
          Get SGNL
        </Button>
        <Button
          variant="outline"
          onClick={() => {
            window.open(
              'https://docs.arbitrum.io/for-devs/dev-tools-and-resources/chain-info#faucets',
              '_blank',
            )
          }}
        >
          Get ETH
        </Button>
      </div>
    </div>
  )
}
