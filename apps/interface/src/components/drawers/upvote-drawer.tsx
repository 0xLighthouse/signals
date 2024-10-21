'use client'

import { ChevronUp, CircleAlert, PlusIcon } from 'lucide-react'
import { toast } from 'sonner'

import { SIGNALS_PROTOCOL } from '@/config/web3'
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
import { useAccount } from 'wagmi'
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useState } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { useCheckAllowance } from '@/hooks/useCheckAllowance'
import type { NormalisedInitiative } from '@/app/api/initiatives/route'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { SubmissionLockDetails } from '../containers/submission-lock-details'

export function UpvoteDrawer({ initiative }: { initiative: NormalisedInitiative }) {
  const { address } = useAccount()
  const { balance, symbol } = useUnderlying()
  const { isApproving, handleApprove } = useApproveTokens(address)
  const { proposalThreshold, formatter, meetsThreshold } = useSignals()

  const [amount, setAmount] = useState<number | null>(null)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [duration, setDuration] = useState(1)

  const weight = amount ? amount * duration : 0

  const hasAllowance = useCheckAllowance(address, amount)

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
      // Simulate and submit the upvote transaction
      // This part of the code would use your existing logic to interact with the blockchain
      toast('Upvote submitted!')
      setIsDrawerOpen(false)
    } catch (error) {
      toast('Error submitting upvote :(')
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
      <Button
        disabled={!amount}
        onClick={handleSubmit}
        isLoading={false} // Assuming isSubmitting is managed elsewhere
      >
        Submit
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
        <div className="p-8 rounded-t-[10px] flex-1 overflow-y-auto flex flex-row gap-4">
          <div className="flex flex-col mx-auto lg:w-3/5">
            <DrawerHeader>
              <DrawerTitle>Propose a new initiative</DrawerTitle>
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
                      <p>{initiative.title || 'No title provided.'}</p>
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
                      <p>{initiative.description || 'No description provided.'}</p>
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
                <SubmissionLockDetails weight={weight} threshold={formatter(proposalThreshold)} />
              </div>
            </div>

            <div className="flex justify-end mt-8">{resolveAction()}</div>
          </div>
          <div className="hidden lg:block w-2/5 lg:mt-6">
            <SubmissionLockDetails weight={weight} threshold={formatter(proposalThreshold)} />
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
