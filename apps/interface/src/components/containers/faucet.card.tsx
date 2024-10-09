'use client'

import React, { useEffect, useState } from 'react'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useAccount } from 'wagmi'
import { readClient, ABI, signer, ERC20_ADDRESS } from '@/config/web3'
import { useUnderlying } from '@/hooks'

export const FaucetCard = () => {
  const { address } = useAccount()
  const { name, symbol, totalSupply, balance } = useUnderlying()

  const [gas, setGas] = useState<string | null>(null)
  

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
              Supply: {Number(totalSupply) / 1e18}
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
