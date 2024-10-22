'use client'

import { ChevronUp, CircleAlert } from 'lucide-react'
import { toast } from 'sonner'

import { ERC20_ADDRESS, SIGNALS_ABI, readClient, SIGNALS_PROTOCOL } from '@/config/web3'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Slider } from '@/components/ui/slider'
import { custom, useAccount } from 'wagmi'
import { Card } from '@/components/ui/card'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useState } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import type { NormalisedInitiative } from '@/app/api/initiatives/route'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { createWalletClient } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { useInitiativesStore } from '@/stores/useInitiativesStore'

export function AddSupportDrawer({ initiative }: { initiative: NormalisedInitiative }) {
  const { address } = useAccount()
  const { balance, symbol } = useUnderlying()
  const { proposalThreshold, formatter, meetsThreshold } = useSignals()

  const [amount, setAmount] = useState<number | null>(null)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [duration, setDuration] = useState(1)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
    spenderAddress: SIGNALS_PROTOCOL,
    tokenAddress: ERC20_ADDRESS,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const weight = amount ? amount * duration : 0

  const resetFormState = () => {
    setAmount(null)
    setDuration(1)
  }

  const handleOnOpenChange = (open: boolean) => {
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (!amount) {
      return toast('Please enter an amount to lock')
    }

    try {
      setIsSubmitting(true)
      const nonce = await readClient.getTransactionCount({ address })

      const signer = createWalletClient({
        chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
        transport: custom(window.ethereum),
      })

      const { request } = await readClient.simulateContract({
        account: address,
        address: SIGNALS_PROTOCOL,
        abi: SIGNALS_ABI,
        functionName: 'supportInitiative',
        nonce,
        args: [initiative.initiativeId, amount * 1e18, duration],
      })

      const hash = await signer.writeContract(request)

      const receipt = await readClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Receipt:', receipt)
      setIsDrawerOpen(false)
      setIsSubmitting(false)
      resetFormState()
      toast('Upvote submitted!')
      fetchInitiatives()
      setIsDrawerOpen(false)
    } catch (error) {
      console.error(error)
      toast('Error submitting upvote :(')
      setIsSubmitting(false)
    }
  }

  const resolveAction = () => {
    if (!hasAllowance && amount) {
      return (
        <Button onClick={() => handleApprove(amount)} isLoading={isApproving}>
          {isApproving ? 'Confirming approval...' : 'Approve'}
        </Button>
      )
    }
    return (
      <Button disabled={!amount} onClick={handleSubmit} isLoading={isSubmitting}>
        Submit
      </Button>
    )
  }

  return (
    <Drawer open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button
          variant="outline"
          full
          size="md"
          onClick={() => setIsDrawerOpen(true)}
          className="flex flex-col items-center min-w-[80px]"
        >
          <ChevronUp className="h-6 w-6 -mt-1" />
          <span className="text-xs">{weight}</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="overflow-y-auto flex p-8 space-x-8">
          <div className="flex flex-col mx-auto lg:w-3/5">
            <DrawerHeader>
              <DrawerTitle>Support initiative</DrawerTitle>
              <Alert className="bg-blue-50 dark:bg-neutral-800">
                <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
                <AlertTitle>
                  Heads up! This board requires your wallet to hold{' '}
                  <strong>
                    {formatter(proposalThreshold)} {symbol}
                  </strong>{' '}
                  tokens to propose an idea.
                </AlertTitle>
                <AlertDescription>
                  You have{' '}
                  <strong>
                    {formatter(balance)} {symbol}
                  </strong>{' '}
                  tokens.{' '}
                  {meetsThreshold ? (
                    <strong>You have enough tokens to propose an idea.</strong>
                  ) : (
                    <strong>You do not have enough tokens to propose an idea.</strong>
                  )}
                  Your tokens will be locked for ${duration} month${duration !== 1 ? 's' : ''}.
                </AlertDescription>
              </Alert>
            </DrawerHeader>
            <div className="flex flex-col my-4 gap-4">
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="title">
                  Title
                </Label>
                <div className="w-4/5">
                  <Card className="p-4 dark:bg-neutral-800">
                    <div className="my-2">
                      <p className="line-clamp break-all">
                        {initiative.title || 'No title provided.'}
                      </p>
                    </div>
                  </Card>
                </div>
              </div>
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="description">
                  Description
                </Label>
                <div className="w-4/5">
                  <Card className="p-4 dark:bg-neutral-800">
                    <div className="my-2">
                      <p className="line-clamp break-all">
                        {initiative.description || 'No description provided.'}
                      </p>
                    </div>
                  </Card>
                </div>
              </div>
            </div>
            <div className="flex flex-col gap-8">
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="amount">
                  Amount
                </Label>
                <div className="w-4/5 flex flex-col">
                  <Input
                    id="amount"
                    type="number"
                    value={amount ?? ''}
                    onChange={(e) => setAmount(e.target.value ? Number(e.target.value) : null)}
                    min="0"
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
              <div className="block lg:hidden">
                <SubmissionLockDetails
                  initiative={initiative}
                  weight={weight}
                  amount={amount}
                  duration={duration}
                  threshold={formatter(proposalThreshold)}
                />
              </div>
            </div>

            <div className="flex justify-end py-8">{resolveAction()}</div>
          </div>
          <div className="hidden lg:block w-2/5 lg:mt-6">
            <SubmissionLockDetails
              initiative={initiative}
              weight={weight}
              amount={amount}
              duration={duration}
              threshold={formatter(proposalThreshold)}
            />
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
