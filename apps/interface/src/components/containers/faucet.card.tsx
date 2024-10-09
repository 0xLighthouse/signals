'use client'

import { getContract } from 'viem'
import React, { useEffect, useState } from 'react'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useAccount } from 'wagmi'
import { readClient, ABI, signer, ERC20_ADDRESS } from '@/config/web3'

export const FaucetCard = () => {
  const { address } = useAccount()

  const [gas, setGas] = useState<string | null>(null)
  const [name, setContractName] = useState<string | null>(null)
  const [symbol, setSymbol] = useState<string | null>(null)
  const [supply, setSupply] = useState<number | null>(null)
  const [balance, setBalance] = useState<number | null>(null)

  // Get the balance of the gas using viem
  useEffect(() => {
    const fetchGasBalance = async () => {
      try {
        if (!address) return
        const gasBalance = await readClient.getBalance({
          address,
        })
        setGas(String(gasBalance))
      } catch (error) {
        console.error('Error fetching gas balance:', error)
      }
    }
    fetchGasBalance()
  }, [address])
  
  // Fetch contract metadata
  useEffect(() => {
    const fetchContractMetadata = async () => {
      if (!address) return

      try {
        const contract = getContract({ address: ERC20_ADDRESS, abi: ABI, client: readClient })

        // The below will send a single request to the RPC Provider.
        const [name, symbol, totalSupply, balance] = await Promise.all([
          contract.read.name() as Promise<string>,
          contract.read.symbol() as Promise<string>,
          contract.read.totalSupply() as Promise<number>,
          contract.read.balanceOf([address]) as Promise<number>,
        ])

        console.log('Contract Metadata:', name, symbol, totalSupply, balance)

        setContractName(name)
        setSymbol(symbol)
        setSupply(Number(totalSupply))
        setBalance(Number(balance))

        
      } catch (error) {
        console.error('Error fetching gas balance:', error)
      }
    }

    fetchContractMetadata()
  }, [address])

  const handleClaimTokens = async () => {
    if (!address) throw new Error('Address not available.')

    try {

      // Signer get nonce
      const nonce = await readClient.getTransactionCount({  
        address,
      })

      // Use the viem client to send the transaction
      const transactionHash = await signer.writeContract({
        account: address,
        nonce,
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'faucet',
        args: [address],
        gas: 10000n,
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
        {name && (
          <CardTitle className="text-lg font-bold">
            {name}
          </CardTitle>
        )}        
      </CardHeader>
      <CardContent className="space-y-2">        
            <CardDescription>
              Tokens: {balance} ({symbol})
            </CardDescription>
            <CardDescription>
              Supply: {Number(supply) / 1e18}
            </CardDescription>
            <CardDescription>
            Gas: {Number(gas) / 1e18} ETH
            </CardDescription>
      </CardContent>
      <CardFooter className="flex justify-end">
        <Button onClick={handleClaimTokens}>Claim tokens</Button>
      </CardFooter>
    </Card>
  )
}
