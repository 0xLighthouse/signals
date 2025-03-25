'use client'

import React, { useState } from 'react'
import { Button } from '@/components/ui/button'
import { toast } from 'sonner'
import { readClient, ERC20WithFaucetABI, context } from '@/config/web3'
import { WalletClient } from 'viem'
import { Separator } from '@/components/ui/separator'
import { useAccount } from '@/hooks/useAccount'
import { cn } from '@/lib/utils'
import { useWeb3 } from '@/contexts/Web3Provider'

const handleFaucetClaim = async (
  { token, address, symbol }: { token: `0x${string}`; address: `0x${string}`; symbol: string },
  signer: WalletClient,
) => {
  if (!address) throw new Error('Address not available.')
  try {
    const transactionHash = await signer.writeContract({
      chain: signer.chain,
      account: address,
      address: token,
      abi: ERC20WithFaucetABI,
      functionName: 'faucet',
      args: [address],
      gas: 100_000n,
    })

    const receipt = await readClient.waitForTransactionReceipt({
      hash: transactionHash,
      confirmations: 2,
      pollingInterval: 2000,
    })

    toast(`Claimed ${symbol} tokens`)
  } catch (err) {
    if (err instanceof Error && err.message.includes('User rejected the request')) {
      toast('User cancelled the request')
    } else {
      toast('Error claiming tokens :(')
    }
    console.error('Error claiming tokens:', err)
  }
}

export const FaucetActions = ({ vertical = false }: { vertical?: boolean }) => {
  const { address } = useAccount()
  const [isLoadingUSDC, setIsLoadingUSDC] = useState(false)
  const [isLoadingTokens, setIsLoadingTokens] = useState(false)
  const { walletClient } = useWeb3()

  const handleClaim = async ({
    token,
    address,
    symbol,
    isLoadingHandler,
  }: {
    token: `0x${string}`
    address: `0x${string}`
    symbol: string
    isLoadingHandler: (isLoading: boolean) => void
  }) => {
    isLoadingHandler(true)
    if (!walletClient) {
      toast('No wallet client found')
      isLoadingHandler(false)
      return
    }
    try {
      await handleFaucetClaim(
        {
          token,
          address,
          symbol,
        },
        walletClient,
      )
    } finally {
      isLoadingHandler(false)
    }
  }

  if (!address) return null

  return (
    <div className="mt-10 md:mt-20">
      <div className="space-y-2">
        <h5 className="text-md font-bold leading-none">Faucet</h5>
        <p className="text-sm text-muted-foreground">Claim test tokens</p>
      </div>
      <Separator className="my-4" />
      <div className={cn('flex gap-2', vertical && 'flex-col')}>
        <Button
          variant="outline"
          onClick={() =>
            handleClaim({
              token: context.contracts.USDC.address,
              address: address as `0x${string}`,
              symbol: context.contracts.USDC.label,
              isLoadingHandler: setIsLoadingUSDC,
            })
          }
          isLoading={isLoadingUSDC}
        >
          Get USDC
        </Button>
        {/* <Separator orientation="vertical" /> */}
        <Button
          variant="outline"
          onClick={() =>
            handleClaim({
              token: context.contracts.BoardUnderlyingToken.address,
              address: address as `0x${string}`,
              symbol: context.contracts.BoardUnderlyingToken.label,
              isLoadingHandler: setIsLoadingTokens,
            })
          }
          isLoading={isLoadingTokens}
        >
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
