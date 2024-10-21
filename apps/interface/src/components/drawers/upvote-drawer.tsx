'use client'

import { ChevronUp, PlusIcon } from 'lucide-react'
import { createWalletClient, custom } from 'viem'
import { hardhat } from 'viem/chains'
import { toast } from 'sonner'

import { ABI, ERC20_ADDRESS, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
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
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useState, useEffect } from 'react'
import type { NormalisedInitiative } from '@/app/api/initiatives/route'

const threshold = 30_000

export function UpvoteDrawer({ initiative }: { initiative: NormalisedInitiative }) {
  const { address } = useAccount()
  const { balance, symbol } = useUnderlying()
  const [amount, setAmount] = useState<number | undefined>(undefined)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [duration, setDuration] = useState(1)
  const [hasAllowance, setHasAllowance] = useState(false)
  const [isApproving, setIsApproving] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { proposalThreshold, acceptanceThreshold, formatter } = useSignals()

  const weight = amount ? amount * duration : 0

  const handleOnOpenChange = (open: boolean) => {
    // if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  // Every time the allowance changes; ensure account has enough tokens
  useEffect(() => {
    const checkAllowance = async () => {
      if (!amount) return

      const allowance = await readClient.readContract({
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'allowance',
        args: [address, SIGNALS_PROTOCOL], // Corrected the second argument to the protocol address
      })

      const _hasAllowance = Number(allowance) >= amount * 1e18
      console.log('hasAllowance', _hasAllowance)
      setHasAllowance(_hasAllowance)
    }

    checkAllowance()
  }, [address, amount])

  const meetsThreshold = balance && proposalThreshold && balance >= proposalThreshold

  const resolveAction = () => {
    if (!hasAllowance && amount) {
      return (
        <Button onClick={() => handleApprove(amount)} isLoading={isApproving}>
          {isApproving ? 'Confirming approval...' : 'Approve'}
        </Button>
      )
    }
    return (
      <Button
        disabled={(lockTokens && !amount) || !title || !description}
        onClick={handleSubmit}
        isLoading={isSubmitting}
      >
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  return (
    <Drawer open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button variant="outline" size="sm" onClick={() => setIsDrawerOpen(true)}>
          <ChevronUp className="mr-1 h-4 w-4" />
          Upvote
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="p-4 bg-white rounded-t-[10px] flex-1 overflow-y-auto flex flex-row">
          <div className="flex flex-col w-3/5 p-8">
            {/* <div className="my-2">
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
                style={{ resize: 'none', height: '200px' }} // Disable resize and set fixed height
              />
            </div> */}

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
                    onChange={(e) => setAmount(e.target.value ? Number(e.target.value) : undefined)}
                    min="0" // Ensure the input cannot be negative
                  />
                  {!amount && (
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
            </div>

            <div className="flex justify-end mt-8">{resolveAction()}</div>
          </div>
          <div className="flex flex-col w-2/5 p-8">
            <DrawerHeader>
              <DrawerTitle>Propose a new initiative</DrawerTitle>
              <DrawerDescription>
                This board requires your wallet to hold{' '}
                <strong>
                  {formatter(proposalThreshold)} {symbol}
                </strong>{' '}
                tokens to propose an idea. You have{' '}
                <strong>
                  {formatter(balance)} {symbol}
                </strong>{' '}
                tokens.
                {meetsThreshold ? (
                  <strong>You have enough tokens to propose an idea.</strong>
                ) : (
                  <strong>You do not have enough tokens to propose an idea.</strong>
                )}
                Your tokens will be locked for ${duration} month${duration !== 1 ? 's' : ''}.
              </DrawerDescription>
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
            </DrawerHeader>
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
