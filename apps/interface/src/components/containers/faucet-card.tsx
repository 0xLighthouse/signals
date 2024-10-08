'use client'

import React, { useEffect, useState } from 'react'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useAccount } from 'wagmi'
import { createPublicClient, erc20Abi, http } from 'viem'
import { hardhat } from 'viem/chains'

const TOKEN_CONTRACT_ADDRESS = '0x34A1D3fff3958843C43aD80F30b94c510645C316' // Replace with your token contract address
// const TOKEN_ABI = [
//   // Replace with your token's ABI
//   'function balanceOf(address owner) view returns (uint256)',
// ]

export const FaucetCard = () => {
  const { address, connector } = useAccount()
  const [balance, setBalance] = useState<string | null>(null)

  useEffect(() => {
    if (!address) return

    const fetchBalance = async () => {
      try {
        if (!connector) return

        const client = createPublicClient({
          chain: hardhat,
          transport: http('https://6391-157-211-27-89.ngrok-free.app'), // Use your provider URL
        })

        const balance = await client.readContract({
          address: TOKEN_CONTRACT_ADDRESS,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [address],
        })

        console.log('Balance:', balance)
      } catch (error) {
        console.error('Error fetching balance:', error)
      }
    }

    fetchBalance()
  }, [address, connector])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-2xl font-bold">Tokens</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="text-4xl font-bold">O SYMBOL</div>
        <div className="text-sm text-muted-foreground">Balance</div>
      </CardContent>
      <CardFooter className="flex justify-end">
        <Button>Faucet</Button>
      </CardFooter>
    </Card>
  )
}
