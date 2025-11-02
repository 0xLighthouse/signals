'use client'

import React, { useState } from 'react'
import { Button } from '@/components/ui/button'
import { toast } from 'sonner'
import { ERC20WithFaucetABI } from '@/config/web3'
import { PublicClient, WalletClient } from 'viem'
import { Separator } from '@/components/ui/separator'
import { useAccount } from '@/hooks/useAccount'
import { cn } from '@/lib/utils'
import { useWeb3 } from '@/contexts/Web3Provider'
import { useRewardsStore } from '@/stores/useRewardsStore'
import { useUnderlying } from '@/contexts/NetworkContext'
import { useNetwork } from '@/hooks/useNetwork'

const handleFaucetClaim = async (
  { token, address, symbol }: { token: `0x${string}`; address: `0x${string}`; symbol: string },
  signer: WalletClient,
  publicClient: PublicClient,
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

    await publicClient.waitForTransactionReceipt({
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
  const { walletClient, publicClient } = useWeb3()
  const { fetch: fetchUSDC } = useRewardsStore()
  const { fetchContractMetadata, symbol: underlyingSymbol } = useUnderlying()
  const { config } = useNetwork()
  const usdcConfig = config.contracts.USDC
  const underlyingContract = config.contracts.BoardUnderlyingToken

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
    if (!walletClient || !publicClient) {
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
        publicClient,
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
          disabled={!usdcConfig}
          onClick={async () => {
            if (!usdcConfig) {
              toast('USDC faucet is not configured for this network.')
              return
            }
            await handleClaim({
              token: usdcConfig.address,
              address: address as `0x${string}`,
              symbol: usdcConfig.label ?? 'USDC',
              isLoadingHandler: setIsLoadingUSDC,
            })
            await fetchUSDC(address)
          }}
          isLoading={isLoadingUSDC}
        >
          Get USDC
        </Button>
        {/* <Separator orientation="vertical" /> */}
        <Button
          variant="outline"
          disabled={!underlyingContract}
          onClick={async () => {
            if (!underlyingContract) {
              toast('Underlying token faucet is not configured for this network.')
              return
            }
            await handleClaim({
              token: underlyingContract.address,
              address: address as `0x${string}`,
              symbol: underlyingContract.label ?? 'Token',
              isLoadingHandler: setIsLoadingTokens,
            })
            await fetchContractMetadata()
          }}
          isLoading={isLoadingTokens}
        >
          Get {underlyingSymbol}
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
