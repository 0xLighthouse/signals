'use client'

import * as React from 'react'
import { PlusIcon } from 'lucide-react'
import { createWalletClient, custom } from 'viem'
import { hardhat } from 'viem/chains'
import { toast } from 'sonner'

import { SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { readClient } from '@/config/web3'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Slider } from '@/components/ui/slider'
import { useAccount } from 'wagmi'

const threshold = 30_000

export function InitiativeDrawer() {
  const { address } = useAccount()
  const [duration, setDuration] = React.useState(1)
  const [amount, setAmount] = React.useState<number | undefined>(0)
  const [lockTokens, setLockTokens] = React.useState(false)
  const [title, setTitle] = React.useState('')
  const [description, setDescription] = React.useState('')
  const [isDrawerOpen, setIsDrawerOpen] = React.useState(false) // Add state for drawer open

  const weight = amount ? amount * duration : 0

  const handleSubmit = async () => {
    console.log('Submit', {
      title,
      description,
      amount,
      duration,
      lockTokens,
    })
    if (!address) throw new Error('Address not available.')
    if (lockTokens && !amount) {
      return toast('Please enter an amount to lock')
    }

    try {
      // Signer get nonce
      const nonce = await readClient.getTransactionCount({
        address,
      })

      const signer = createWalletClient({
        chain: hardhat,
        transport: custom(window.ethereum),
      })

      const functionName = amount ? 'proposeInitiativeWithLock' : 'proposeInitiative'
      const args = amount ? [title, description, amount * 1e18, duration] : [title, description]

      const transactionHash = await signer.writeContract({
        account: address,
        nonce,
        address: SIGNALS_PROTOCOL,
        abi: SIGNALS_ABI,
        functionName,
        args,
        gas: 100_000n,
      })

      console.log('Transaction Hash:', transactionHash)

      const receipt = await readClient.waitForTransactionReceipt({
        hash: transactionHash,
      })
      console.log('Transaction Receipt:', receipt)

      setIsDrawerOpen(false)
      toast('Initiative submitted!')
    } catch (error) {
      console.error('Error claiming tokens:', error)
    }
  }

  return (
    <Drawer open={isDrawerOpen} onOpenChange={setIsDrawerOpen}>
      {' '}
      {/* Control drawer open state */}
      <DrawerTrigger asChild>
        <Button onClick={() => setIsDrawerOpen(true)}>
          {/* Open drawer on button click */}
          Propose Initiative &nbsp; <PlusIcon size={24} />
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="mx-auto w-full max-w-lg pt-8 pb-12">
          <DrawerHeader>
            <DrawerTitle>Propose a new initiative</DrawerTitle>
            <DrawerDescription>
              This board requires your wallet to hold <strong>XX SGNL</strong> tokens to propose an
              idea. You have <strong>1e+24 SGNL</strong> tokens.{' '}
              {lockTokens
                ? `Your tokens will be locked for ${duration} month${duration !== 1 ? 's' : ''}.`
                : 'Your tokens will not be locked.'}
            </DrawerDescription>
          </DrawerHeader>
          <div className="p-4 pb-0">
            <div className="my-2">
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                placeholder="On-chain forums."
                value={title} // Bind state to input
                onChange={(e) => setTitle(e.target.value)} // Update state on change
              />
            </div>
            <div className="my-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                placeholder="Enter something novel. Remember to search for existing ideas first and a reminder this is public."
                required
                value={description} // Bind state to textarea
                onChange={(e) => setDescription(e.target.value)} // Update state on change
              />
            </div>

            <div className="flex items-center py-4 gap-4">
              <Switch
                id="lock-tokens"
                checked={lockTokens}
                onCheckedChange={() => setLockTokens(!lockTokens)} // Use onCheckedChange
              />
              <Label htmlFor="lock-tokens">Lock tokens</Label>
            </div>

            {lockTokens && (
              <div className="flex flex-col gap-8">
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center" htmlFor="amount">
                    Amount
                  </Label>
                  <div className="w-4/5 flex flex-col">
                    <Input
                      id="amount"
                      type="number"
                      value={amount}
                      onChange={(e) =>
                        setAmount(e.target.value ? Number(e.target.value) : undefined)
                      }
                      min="0" // Ensure the input cannot be negative
                    />
                    {lockTokens && !amount && (
                      <Label className="text-red-500 mt-2">Please enter an amount to lock</Label>
                    )}
                  </div>
                </div>
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center" htmlFor="duration">
                    Duration
                  </Label>
                  <div className="w-4/5 flex items-center justify-center whitespace-nowrap">
                    <Slider
                      defaultValue={[1]}
                      step={1}
                      min={1}
                      max={12}
                      onValueChange={(value) => setDuration(value[0])}
                    />
                    <p className="ml-4">{`${duration} month${duration !== 1 ? 's' : ''}`}</p>
                  </div>
                </div>
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center">Weight</Label>
                  <div className="w-4/5 flex items-center">
                    <p>{weight}</p>
                  </div>
                </div>
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center">Threshold</Label>
                  <div className="w-4/5 flex items-center">
                    <p>{threshold}</p>
                  </div>
                </div>
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center">Weight</Label>
                  <div className="w-4/5 flex items-center">
                    <p>{(weight / threshold).toFixed(2)}</p>
                  </div>
                </div>
                <div className="flex items-center">
                  <Label className="w-1/5 flex items-center">Percentage</Label>
                  <div className="w-4/5 flex items-center">
                    <p>{((weight / threshold) * 100).toFixed(2)}%</p>
                  </div>
                </div>
              </div>
            )}
          </div>
          <DrawerFooter>
            <div className="flex justify-end gap-2">
              <DrawerClose asChild>
                <Button variant="outline">Cancel</Button>
              </DrawerClose>
              <Button disabled={lockTokens && !amount} onClick={handleSubmit}>
                Submit
              </Button>
            </div>
          </DrawerFooter>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
