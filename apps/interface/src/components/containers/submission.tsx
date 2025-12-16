'use client'

import { useState } from 'react'
import { Card, CardContent, CardDescription, CardFooter, CardHeader } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '../ui/textarea'
import { useSignals } from '@/hooks/use-signals'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from '@/contexts/WalletProvider'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'

export const Submission = () => {
  const { address } = useAccount()
  const {
    underlyingName: name,
    underlyingSymbol: symbol,
    underlyingTotalSupply: totalSupply,
    underlyingBalance: balance,
  } = useSignals()
  const { walletClient, publicClient } = useWeb3()
  const { config } = useNetworkConfig()

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')

  const handleSubmission = async () => {
    if (!address) throw new Error('Address not available.')
    if (!walletClient || !publicClient) {
      throw new Error('Wallet not connected')
    }
    const signalsContract = config.contracts.SignalsProtocol
    if (!signalsContract) {
      console.warn('No Signals board configured for current network.')
      return
    }

    try {
      // Signer get nonce
      const nonce = await publicClient.getTransactionCount({
        address,
      })

      // Use the viem client to send the transaction
      const metadata = {
        title,
        body: description,
        attachments: [],
      }
      const { request } = await publicClient.simulateContract({
        account: address,
        address: signalsContract.address,
        abi: signalsContract.abi,
        functionName: 'proposeInitiative',
        args: [metadata],
        nonce,
      })

      const transactionHash = await walletClient.writeContract(request)

      console.log('Transaction Hash:', transactionHash)
      console.log('Waiting for txn to be mined...')

      const receipt = await publicClient.waitForTransactionReceipt({
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
          <Label htmlFor="title">Title</Label>
          <Input
            id="title"
            placeholder="On-chain forums."
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label htmlFor="description">Description</Label>
          <Textarea
            id="description"
            placeholder="Enter something novel. Remember to search for existing ideas first and a reminder this is public."
            required
            value={description}
            onChange={(e) => setDescription(e.target.value)}
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
