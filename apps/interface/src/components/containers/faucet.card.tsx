'use client'

import { getContract } from 'viem'
import React, { useEffect, useState } from 'react'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useAccount } from 'wagmi'
import { createPublicClient, createWalletClient, custom, erc20Abi, http } from 'viem'
import { hardhat } from 'viem/chains'

const ERC20_ADDRESS = '0xD00B87df994b17a27aBA4f04c7A7D77bE3b95e10'

export const readClient = createPublicClient({
  chain: hardhat,
  transport: http('https://cb4081703720.ngrok.app'),
})

const signer = createWalletClient({
  chain: hardhat,
  transport: custom(window.ethereum!),
})

const ABI = [
  ...erc20Abi,
  {
    inputs: [
      {
        internalType: 'address',
        name: 'to',
        type: 'address',
      },
    ],
    name: 'faucet',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
]

export const FaucetCard = () => {
  const { address } = useAccount()

  const [balance, setBalance] = useState<string | null>(null)
  const [metadata, setTokenMetdata] = useState<[string, string, number, number] | undefined>(
    undefined,
  )

  // Get the balance of the gas using viem
  useEffect(() => {
    const fetchGasBalance = async () => {
      try {
        if (!address) return
        const gasBalance = await readClient.getBalance({
          address,
        })
        setBalance(String(gasBalance))
      } catch (error) {
        console.error('Error fetching gas balance:', error)
      }
    }

    fetchGasBalance()
  }, [address])
  // Fetch contract metadata
  useEffect(() => {
    const fetchContractMetadata = async () => {
      try {
        if (!address) return
        const contract = getContract({ address: ERC20_ADDRESS, abi: ABI, client: readClient })

        // The below will send a single request to the RPC Provider.
        const [name, symbol, totalSupply, balance] = await Promise.all([
          contract.read.name() as Promise<string>,
          contract.read.symbol() as Promise<string>,
          contract.read.totalSupply() as Promise<number>,
          contract.read.balanceOf([address]) as Promise<number>,
        ])

        setTokenMetdata([name, symbol, totalSupply, balance])
      } catch (error) {
        console.error('Error fetching gas balance:', error)
      }
    }

    fetchContractMetadata()
  }, [address])

  const handleClaimTokens = async () => {
    if (!address) {
      console.error('Signer or address not available.')
      return
    }

    try {
      // Use the viem client to send the transaction
      const transactionHash = await signer.writeContract({
        account: address,
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'faucet',
        args: [address],
      })

      console.log('Transaction Hash:', transactionHash)

      const receipt = await readClient.waitForTransactionReceipt({
        hash: transactionHash,
      })
      console.log('Transaction Receipt:', receipt)
    } catch (error) {
      console.error('Error claiming tokens:', error)
    }
  }

  return (
    <Card>
      <CardHeader>
        {metadata && (
          <CardTitle className="text-lg font-bold">
            {metadata[0]}
          </CardTitle>
        )}        
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="text-sm text-muted-foreground">Balance:</div>
        {metadata && (
          <CardTitle className="text-2xl font-bold">
            {metadata[3] ?? 0} ({metadata[1]})
          </CardTitle>
        )}
        <div className="text-sm text-muted-foreground">Gas: {Number(balance) / 1e18} ETH</div>
      </CardContent>
      <CardFooter className="flex justify-end">
        <Button onClick={handleClaimTokens}>Claim tokens</Button>
      </CardFooter>
    </Card>
  )
}
