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
import type { Initiative } from '@/types/initiative'
import { Alert, AlertDescription } from '../ui/alert'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { useInitiativesStore } from '@/stores/useInitiativesStore'

import { usePrivy } from '@privy-io/react-auth'
import { useBondsStore } from '@/stores/useBondsStore'
import { parseUnits } from 'viem'
import { SignalsABI } from '../../../../../packages/abis'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import { formatUnits } from 'viem'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'

export function SupportInitiativeDrawer({ initiative }: { initiative: Initiative }) {
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const {
    underlyingBalance: balance,
    underlyingSymbol: symbol,
    boardAddress,
    formatter,
    board,
  } = useSignals()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const tokenDecimals = board?.underlyingTokenDecimals ?? 18

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

  const formatTokenAmount = (value?: string | number | bigint | null) => {
    if (value == null || board?.underlyingTokenDecimals == null) return null
    try {
      const asBigInt = BigInt(value)
      const formatted = Number(formatUnits(asBigInt, board.underlyingTokenDecimals))
      if (!Number.isFinite(formatted)) return null
      if (formatted >= 1) {
        return formatted.toLocaleString('en-US', { maximumFractionDigits: 2 })
      }
      return formatted.toLocaleString('en-US', { maximumFractionDigits: 6 })
    } catch {
      return null
    }
  }

  const participantMinBalance = formatTokenAmount(board?.participantRequirements?.minBalance)
  const participantMinLock = formatTokenAmount(board?.participantRequirements?.minLockAmount)
  const formattedBalance = formatTokenAmount(balance)
  const proposerName = useAsyncProp(
    resolveName(initiative.proposer),
    shortAddress(initiative.proposer),
  )

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
    spender: board?.contractAddress ?? undefined,
    tokenAddress: board?.underlyingToken ?? undefined,
    tokenDecimals,
    enabled: isDrawerOpen,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const resetFormState = () => {
    setAmount('0')
    setDuration(1)
    setIsSubmitting(false)
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
    if (!publicClient) {
      toast('Web3 is still initializing. Please try again in a moment.')
      return
    }
    if (!board?.contractAddress || !board?.underlyingToken) {
      toast('Missing board contract info. Please refresh and try again.')
      return
    }

    try {
      setIsSubmitting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      const { request } = await publicClient.simulateContract({
        account: address,
        address: board.contractAddress,
        abi: SignalsABI,
        functionName: 'supportInitiative',
        nonce,
        args: [
          BigInt(initiative.initiativeId),
          parseUnits(String(amount), tokenDecimals),
          BigInt(duration),
        ],
      })

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
              <Alert className="bg-amber-50 dark:bg-neutral-800">
                <AlertDescription>
                  Signals is not a vote system. Lock only if you care enough to trade time or tokens
                  for the outcome.
                </AlertDescription>
              </Alert>
              <Card className="mt-3 border-neutral-200/80 dark:border-neutral-800 bg-gradient-to-r from-orange-50 via-white to-amber-50 dark:from-neutral-900 dark:via-neutral-950 dark:to-neutral-900 shadow-sm">
                <div className="flex items-start gap-4 p-4">
                  <Avatar className="h-12 w-12 ring-2 ring-white shadow-sm">
                    <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
                  </Avatar>
                  <div className="flex-1 space-y-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="secondary" className="uppercase text-[10px] tracking-wide">
                        Proposer
                      </Badge>
                      <span className="text-sm text-muted-foreground">
                        {proposerName} • {timeAgoWords(initiative.createdAtTimestamp)}
                      </span>
                    </div>
                    <h3 className="text-lg font-semibold leading-snug text-neutral-900 dark:text-white">
                      {initiative.title}
                    </h3>
                    <p className="text-sm text-neutral-700 dark:text-neutral-200 leading-relaxed">
                      {initiative.description}
                    </p>
                  </div>
                </div>
              </Card>
              <Alert className="bg-blue-50 dark:bg-neutral-800">
                <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
                <AlertDescription>
                  {participantMinBalance || participantMinLock ? (
                    <div className="space-y-1">
                      {participantMinBalance ? (
                        <div>
                          Requires at least{' '}
                          <strong>
                            {participantMinBalance} {symbol}
                          </strong>{' '}
                          balance to support.
                        </div>
                      ) : (
                        <div>No minimum balance required to support.</div>
                      )}
                      {participantMinLock ? (
                        <div>
                          Requires locking at least{' '}
                          <strong>
                            {participantMinLock} {symbol}
                          </strong>
                          .
                        </div>
                      ) : (
                        <div>No minimum lock amount required.</div>
                      )}
                      <div>
                        You have{' '}
                        <strong>
                          {formattedBalance ?? '—'} {symbol}
                        </strong>{' '}
                        available.
                      </div>
                    </div>
                  ) : (
                    <>
                      You have{' '}
                      <strong>
                        {formattedBalance ?? '—'} {symbol}
                      </strong>{' '}
                      available to support this initiative.
                    </>
                  )}
                </AlertDescription>
              </Alert>
            </DrawerHeader>
            <div className="flex flex-col my-4 gap-4">
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
