'use client'

import { useState } from 'react'
import { CircleAlert, PlusIcon } from 'lucide-react'
import { createWalletClient, custom } from 'viem'
import { hardhat } from 'viem/chains'
import { toast } from 'sonner'

import {
  ERC20_ADDRESS,
  INCENTIVES,
  SIGNALS_ABI,
  SIGNALS_PROTOCOL,
  USDC_ADDRESS,
} from '@/config/web3'
import { readClient } from '@/config/web3'
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
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Slider } from '@/components/ui/slider'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { useAccount } from 'wagmi'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { useCheckAllowance } from '@/hooks/useCheckAllowance'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { SwitchContainer } from '../ui/switch-container'

export function InitiativeDrawer() {
  const { balance, symbol } = useUnderlying()
  const { address } = useAccount()
  const { proposalThreshold, formatter, meetsThreshold } = useSignals()

  const { isApproving, handleApprove } = useApproveTokens({
    actor: address,
    spenderAddress: SIGNALS_PROTOCOL,
    tokenAddress: ERC20_ADDRESS,
  })

  const [duration, setDuration] = useState(1)
  const [amount, setAmount] = useState<number | null>(null)
  const [lockTokens, setLockTokens] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const weight = amount ? amount * duration : 0

  const hasAllowance = useCheckAllowance({
    actor: address,
    amount,
    spenderAddress: SIGNALS_PROTOCOL,
    tokenAddress: ERC20_ADDRESS,
  })

  const resetFormState = () => {
    setAmount(null)
    setLockTokens(false)
    setTitle('')
    setDescription('')
    setDuration(1)
  }

  const handleOnOpenChange = (open: boolean) => {
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (lockTokens && !amount) {
      return toast('Please enter an amount to lock')
    }

    try {
      setIsSubmitting(true)
      const nonce = await readClient.getTransactionCount({ address })

      const signer = createWalletClient({
        chain: hardhat,
        transport: custom(window.ethereum),
      })

      const functionName = amount ? 'proposeInitiativeWithLock' : 'proposeInitiative'
      const args = amount ? [title, description, amount * 1e18, duration] : [title, description]

      try {
        const { request } = await readClient.simulateContract({
          account: address,
          address: SIGNALS_PROTOCOL,
          abi: SIGNALS_ABI,
          functionName,
          nonce,
          args,
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
        toast('Initiative submitted!')
        fetchInitiatives()
      } catch (err) {
        toast('Failed to simulate contract call', {
          // @ts-ignore
          description: err.message,
        })
      }
    } catch (error) {
      // @ts-ignore
      if (error?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error submitting initiative :(')
      }
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
      <Button
        disabled={(lockTokens && !amount) || !title || !description}
        onClick={handleSubmit}
        isLoading={isSubmitting}
      >
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  if (!address) return null

  return (
    <Drawer open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button onClick={() => setIsDrawerOpen(true)}>
          Propose Initiative &nbsp; <PlusIcon size={24} />
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
                  {lockTokens
                    ? ` Your tokens will be locked for ${duration} month${duration !== 1 ? 's' : ''}.`
                    : ' Your tokens will not be locked.'}
                </AlertDescription>
              </Alert>
            </DrawerHeader>
            <div className="my-2">
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                placeholder="On-chain forums."
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>
            <div className="my-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                placeholder="Enter something novel. Remember to search for existing ideas first and a reminder this is public."
                required
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                style={{ resize: 'none', height: '200px' }}
              />
            </div>
            <SwitchContainer>
              <Switch
                id="lock-tokens"
                checked={lockTokens}
                onCheckedChange={() => setLockTokens(!lockTokens)}
              />
              <Label htmlFor="lock-tokens">Lock tokens</Label>
            </SwitchContainer>
            {lockTokens && (
              <div className="flex flex-col gap-8 my-2">
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
                <div className="block lg:hidden">
                  <SubmissionLockDetails weight={weight} threshold={formatter(proposalThreshold)} />
                </div>
              </div>
            )}

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
