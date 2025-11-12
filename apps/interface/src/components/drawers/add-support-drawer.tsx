import { ChevronUp, CircleAlert } from 'lucide-react'
import { toast } from 'sonner'

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
import { useAccount } from '@/hooks/useAccount'
import { Card } from '@/components/ui/card'
import { useSignals } from '@/hooks/use-signals'
import { useState, useEffect } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import type { Initiative } from 'indexers/src/api/types'
import { Alert, AlertDescription } from '../ui/alert'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { useWeb3 } from '@/contexts/Web3Provider'
import { useInitiativesStore } from '@/stores/useInitiativesStore'

import { usePrivy } from '@privy-io/react-auth'
import { useBondsStore } from '@/stores/useBondsStore'
import { useNetwork } from '@/hooks/useNetwork'
import { parseUnits } from 'viem'

export function AddSupportDrawer({ initiative }: { initiative: Initiative }) {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const { authenticated, login } = usePrivy()
  const {
    underlyingBalance: balance,
    underlyingSymbol: symbol,
    fetchUnderlyingMetadata: fetchContractMetadata,
    boardAddress,
    formatter,
    board,
  } = useSignals()
  const { config } = useNetwork()
  const signalsContract = config.contracts.SignalsProtocol
  const underlyingContract = config.contracts.BoardUnderlyingToken
  const tokenDecimals = underlyingContract?.decimals ?? 18

  const [amountValue, setAmount] = useState('0')
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [duration, setDuration] = useState(1)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const initiativeLocks = useBondsStore((s) => s.initiativeLocks)
  const fetchInitiativeLocks = useBondsStore((s) => s.fetchInitiativeLocks)
  const isInitiativeLocksInitialized = useBondsStore((s) => s.isInitiativeLocksInitialized)

  useEffect(() => {
    if (!isInitiativeLocksInitialized) {
      console.log(`Fetching locks for [initiativeId:${initiative.initiativeId}]`)
      fetchInitiativeLocks(initiative.initiativeId.toString())
    }
  }, [initiative.initiativeId, isInitiativeLocksInitialized, fetchInitiativeLocks])

  const amount = amountValue ? Number(amountValue) : 0

  const {
    isApproving,
    hasAllowance,
    handleApprove,
    allowance,
    formattedAllowance,
    handleRevokeAllowance,
  } = useApproveTokens({
    amount,
    actor: address,
    spender: signalsContract?.address,
    tokenAddress: underlyingContract?.address,
    tokenDecimals,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const resetFormState = () => {
    setAmount('0')
    setDuration(1)
  }

  const handleTriggerDrawer = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    setIsDrawerOpen(true)
  }

  const handleOnOpenChange = (open: boolean) => {
    if (!address) {
      setIsDrawerOpen(false)
      return
    }
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (!amount) {
      return toast('Please enter an amount to lock')
    }
    if (!walletClient) {
      toast('Wallet not connected')
      return
    }
    if (!signalsContract || !underlyingContract) {
      toast('Network is missing Signals configuration. Please try again later.')
      return
    }

    try {
      setIsSubmitting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      const { request } = await publicClient.simulateContract({
        account: address,
        address: signalsContract.address,
        abi: signalsContract.abi,
        functionName: 'supportInitiative',
        nonce,
        args: [
          BigInt(initiative.initiativeId),
          parseUnits(String(amount), tokenDecimals),
          BigInt(duration),
        ],
      })

      console.log('Request:', request)
      const hash = await walletClient.writeContract(request)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Receipt:', receipt)
      setIsDrawerOpen(false)
      resetFormState()
      toast('Upvote submitted!')
      if (boardAddress) {
        fetchInitiatives(boardAddress)
      }
      fetchContractMetadata()
    } catch (err) {
      console.error(err)
      toast('Error adding support')
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
    <Drawer
      dismissible={!isSubmitting && !isApproving}
      open={isDrawerOpen}
      onOpenChange={handleOnOpenChange}
    >
      <DrawerTrigger asChild>
        <Button
          variant="outline"
          full
          size="md"
          onClick={handleTriggerDrawer}
          className="flex flex-col items-center min-w-[80px]"
        >
          <ChevronUp className="h-6 w-6 -mt-1" />
          <span className="text-xs">
            {Number.parseFloat(String(initiative.support * 100)).toFixed(2)}%
          </span>
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="overflow-y-auto flex p-8 space-x-8">
          <div className="flex flex-col mx-auto lg:w-3/5 lg:pr-8">
            <DrawerHeader>
              <DrawerTitle>Support initiative</DrawerTitle>
              <Alert className="bg-blue-50 dark:bg-neutral-800">
                <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
                <AlertDescription>
                  You have{' '}
                  <strong>
                    {formatter(balance)} {symbol}
                  </strong>{' '}
                  tokens which can be used to support this initiative.{' '}
                </AlertDescription>
              </Alert>
            </DrawerHeader>
            <div className="flex flex-col my-4 gap-4">
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="title">
                  Title
                </Label>
                <div className="w-4/5">
                  <Card className="p-4 dark:bg-neutral-900 border-none shadow-none">
                    <div className="my-2">
                      <p className="line-clamp break-words">
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
                  <Card className="p-4 dark:bg-neutral-900 border-none shadow-none">
                    <div className="my-2">
                      <p className="line-clamp break-words">
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
                    type="text"
                    value={amountValue ?? undefined}
                    onFocus={() => !Number(amountValue) && setAmount('')}
                    onBlur={() => !Number(amountValue) && setAmount('0')}
                    onChange={(e) => setAmount(e.target.value)}
                  />
                  {!amount && (
                    <Label className="text-red-500 mt-2">Please enter an amount to lock</Label>
                  )}
                  {allowance && (
                    <Label className="text-gray-500 mt-2">
                      Current allowance is: {formattedAllowance}.{' '}
                      <Button
                        variant="link"
                        className="text-gray-500 underline"
                        onClick={handleRevokeAllowance}
                      >
                        Revoke?
                      </Button>
                    </Label>
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
                    //TODO: Populate max from (maxLockDuration) in the smart contract
                    max={30}
                    onValueChange={(value) => setDuration(value[0])}
                  />
                  <p className="ml-4">{`${duration} day${duration !== 1 ? 's' : ''}`}</p>
                </div>
              </div>
              <div className="block lg:hidden">
                <SubmissionLockDetails
                  initiative={{
                    createdAt: initiative.createdAtTimestamp,
                    lockInterval: board.lockInterval,
                    decayCurveType: board.decayCurveType,
                    decayCurveParameters: board.decayCurveParameters,
                  }}
                  supporters={initiative.supporters}
                  amount={amount}
                  duration={duration}
                  threshold={formatter(board.acceptanceThreshold)}
                  supportInitiative={true}
                  existingLocks={initiativeLocks}
                />
              </div>
            </div>

            <div className="flex justify-end py-8">{resolveAction()}</div>
          </div>
          <div className="hidden lg:block w-2/5 lg:mt-6">
            <SubmissionLockDetails
              initiative={{
                createdAt: initiative.createdAtTimestamp,
                lockInterval: board.lockInterval,
                decayCurveType: board.decayCurveType,
                decayCurveParameters: board.decayCurveParameters,
              }}
              supporters={initiative.supporters}
              amount={amount}
              duration={duration}
              threshold={formatter(board.acceptanceThreshold)}
              supportInitiative={true}
              existingLocks={initiativeLocks}
            />
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
