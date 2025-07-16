'use client'

import { Card, CardContent, CardDescription, CardFooter, CardHeader } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '../ui/textarea'
import { useUnderlying } from '@/contexts/ContractContext'
import { context } from '@/config/web3'
import { createWalletClient, custom } from 'viem'
import { readClient } from '@/config/web3'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { useAccount } from '@/hooks/useAccount'

export const Submission = () => {
  const { address } = useAccount()
  const { name, symbol, totalSupply, balance } = useUnderlying()

  const handleSubmission = async () => {
    if (!address) throw new Error('Address not available.')

    try {
      // Signer get nonce
      const nonce = await readClient.getTransactionCount({
        address,
      })

      const signer = createWalletClient({
        chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
        // Injected provider from MetaMask
        transport: custom(window.ethereum),
      })

      // Use the viem client to send the transaction
      const transactionHash = await signer.writeContract({
        account: address,
        nonce,
        address: context.contracts.SignalsProtocol.address,
        abi: context.contracts.SignalsProtocol.abi,
        functionName: 'proposeInitiative',
        args: ['Initiative 1', 'Description 1'],
        gas: 100_000n,
      })

      console.log('Transaction Hash:', transactionHash)
      console.log('Waiting for txn to be mined...')

      const receipt = await readClient.waitForTransactionReceipt({
        hash: transactionHash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Transaction Receipt:', receipt)
    } catch (error) {
      console.error('Error claiming tokens:', error)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardDescription>
          You will need {symbol} tokens to submit an idea. You have {balance} ({symbol}) tokens.
          Your tokens will not be locked.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="space-y-1">
          <Label htmlFor="name">Title</Label>
          <Input id="title" placeholder="On-chain forums." />
        </div>
        <div className="space-y-1">
          <Label htmlFor="username">Username</Label>
          <Textarea
            placeholder="Enter something novel. Remember to search for existing ideas first and a reminder this is public."
            required
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Input placeholder="Network (optional)" />
          <Input placeholder="Token (optional)" />
          <Input type="number" />
          <Input placeholder="Duration (optional)" />
        </div>
      </CardContent>
      <CardFooter>
        <Button onClick={handleSubmission}>Save changes</Button>
      </CardFooter>
    </Card>
  )
}
