import { CircleAlert } from 'lucide-react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import { Label } from '@/components/ui/label'
import { useAccount } from '@/hooks/useAccount'
import { Card } from '@/components/ui/card'
import { useSignals } from '@/hooks/use-signals'
import { useState, useEffect, useMemo, useCallback } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import type { Initiative } from '@/indexers/api/types'
import { Alert, AlertDescription } from '../ui/alert'
import { AcceptanceProgressChart } from '../acceptance-progress-chart'
import { useInitiativesStore } from '@/stores/useInitiativesStore'

import { useLocksStore } from '@/stores/useLocksStore'
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
import { AmountInput } from './shared/AmountInput'
import { DurationSlider } from './shared/DurationSlider'
import { ImpactMetrics } from './shared/ImpactMetrics'

interface Props {
  initiative: Initiative
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function SupportInitiativeDrawer({ initiative, open, onOpenChange }: Props) {
  const { address } = useAccount()
  const {
    underlyingBalance: balance,
    underlyingSymbol: symbol,
    boardAddress,
    formatter,
    board,
  } = useSignals()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const underlyingTokenDecimals = board?.underlyingTokenDecimals ?? 18

  const [amountValue, setAmount] = useState('0')
  const [duration, setDuration] = useState(1)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showAllowanceDetails, setShowAllowanceDetails] = useState(false)

  // Memoize as a primitive to avoid effect loops when initiativeId is a BigInt/object
  const initiativeId = useMemo(() => initiative.initiativeId.toString(), [initiative.initiativeId])

  // Access store Maps directly with stable selectors
  const locksByInitiative = useLocksStore((s) => s.locksByInitiative)
  const initializedStates = useLocksStore((s) => s.initializedStates)
  const fetchInitiativeLocks = useLocksStore((s) => s.fetchInitiativeLocks)

  // Derive values outside the selector to avoid infinite loops
  const initiativeLocks = useMemo(
    () => locksByInitiative.get(initiativeId) ?? [],
    [locksByInitiative, initiativeId],
  )
  const initiativeInitialized = useMemo(
    () => initializedStates.get(initiativeId) ?? false,
    [initializedStates, initiativeId],
  )

  useEffect(() => {
    if (!initiativeId) return
    if (!open) return
    if (initiativeInitialized) return
    fetchInitiativeLocks(initiativeId)
  }, [initiativeId, initiativeInitialized, fetchInitiativeLocks, open])

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

  const parsedAmount = Number(amountValue)
  const amount = Number.isFinite(parsedAmount) ? parsedAmount : 0

  const parseNumericValue = useCallback(
    (value: unknown) => {
      if (typeof value === 'bigint') return Number(formatUnits(value, underlyingTokenDecimals))
      if (typeof value === 'number') return value
      if (typeof value === 'string') {
        try {
          return Number(formatUnits(BigInt(value), underlyingTokenDecimals))
        } catch {
          const parsed = Number(value)
          return Number.isFinite(parsed) ? parsed : 0
        }
      }
      return 0
    },
    [underlyingTokenDecimals],
  )

  const numericBalance = useMemo(
    () => parseNumericValue(balance),
    [balance, parseNumericValue],
  )
  const participantMinLockNumber = useMemo(() => {
    const raw = board?.participantRequirements?.minLockAmount
    if (raw == null) return 0
    try {
      if (typeof raw === 'bigint' || typeof raw === 'string') {
        return Number(formatUnits(BigInt(raw), underlyingTokenDecimals))
      }
      if (typeof raw === 'number') {
        return raw
      }
      return 0
    } catch {
      const fallback = Number(raw as unknown as string)
      return Number.isFinite(fallback) ? fallback : 0
    }
  }, [board?.participantRequirements?.minLockAmount, underlyingTokenDecimals])

  const maxLockIntervals = useMemo(() => {
    if (board?.maxLockIntervals && board.maxLockIntervals > 0) return board.maxLockIntervals
    return 30
  }, [board?.maxLockIntervals])

  const formatDurationLabel = (seconds: number) => {
    if (!seconds || seconds < 60) return `${seconds}s`
    const days = seconds / 86400
    if (days >= 1) {
      const rounded = Math.round(days * 10) / 10
      return `${rounded} day${rounded !== 1 ? 's' : ''}`
    }
    const hours = seconds / 3600
    const rounded = Math.round(hours * 10) / 10
    return `${rounded} hour${rounded !== 1 ? 's' : ''}`
  }

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
    tokenDecimals: underlyingTokenDecimals,
    enabled: open,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const resetFormState = () => {
    setAmount('0')
    setDuration(1)
    setIsSubmitting(false)
    setShowAllowanceDetails(false)
  }

  const handleOnOpenChange = (nextOpen: boolean) => {
    if (!address) {
      onOpenChange(false)
      return
    }
    if (!nextOpen) resetFormState()
    onOpenChange(nextOpen)
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
          parseUnits(String(amount), underlyingTokenDecimals),
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
      onOpenChange(false)
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
        Commit Support
      </Button>
    )
  }

  const unlockDate = useMemo(() => {
    const intervalSeconds = board?.lockInterval ?? 24 * 60 * 60
    const ms = Date.now() + duration * intervalSeconds * 1000
    return new Date(ms).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }, [board?.lockInterval, duration])

  const weightContributed = amount && duration ? amount * duration : 0
  const acceptanceThreshold = formatter(board.acceptanceThreshold)
  const progressDelta = acceptanceThreshold ? (weightContributed / acceptanceThreshold) * 100 : 0
  const coordinationPeers =
    weightContributed > 0 && acceptanceThreshold
      ? Math.max(0, Math.ceil((acceptanceThreshold - weightContributed) / weightContributed))
      : null
  const insufficientBalance = amount > 0 && numericBalance < amount

  return (
    <Drawer
      dismissible={!isSubmitting && !isApproving}
      open={open}
      onOpenChange={handleOnOpenChange}
    >
      <DrawerContent>
        <div className="overflow-y-auto p-8">
          <DrawerHeader className="px-0">
            <DrawerTitle className="text-2xl">Support initiative</DrawerTitle>
            <p className="text-sm text-muted-foreground">
              Signals measures conviction, not opinion. Support only if you're willing to accept
              real opportunity cost.
            </p>
          </DrawerHeader>

          <div className="flex flex-col lg:flex-row gap-8">
            {/* Left column: Initiative details */}
            <div className="flex-1 lg:w-1/2 space-y-6">
              <Card className="border-stone-200/80 dark:border-stone-800 bg-gradient-to-r from-orange-50 via-white to-amber-50 dark:from-stone-900 dark:via-stone-950 dark:to-stone-900 shadow-sm">
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
                    <h3 className="text-lg font-semibold leading-snug text-stone-900 dark:text-white">
                      {initiative.title}
                    </h3>
                    <p className="text-sm text-stone-700 dark:text-stone-200 leading-relaxed">
                      {initiative.description}
                    </p>
                  </div>
                </div>
              </Card>

              <Alert className="bg-amber-50 dark:bg-stone-800">
                <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
                <AlertDescription>
                  {participantMinBalance || participantMinLock ? (
                    <div className="space-y-1">
                      {participantMinBalance && (
                        <div>
                          Requires at least <strong>{participantMinBalance}</strong> {symbol} balance
                          to support.
                        </div>
                      )}
                      {participantMinLock && (
                        <div>
                          Minimum to lock: <strong>{participantMinLock}</strong> {symbol}.
                        </div>
                      )}
                      <div>
                        You have <strong>{formattedBalance ?? '—'}</strong> {symbol} available.
                      </div>
                    </div>
                  ) : (
                    <>
                      You have <strong>{formattedBalance ?? '—'}</strong> {symbol} available to
                      support this initiative.
                    </>
                  )}
                </AlertDescription>
              </Alert>
            </div>

            {/* Right column: Impact, Form inputs and preview */}
            <div className="flex-1 lg:w-1/2 space-y-6">
              <ImpactMetrics
                weightContributed={weightContributed}
                progressDelta={progressDelta}
                coordinationPeers={coordinationPeers}
              />

              <div className="space-y-6">
                <AmountInput
                  amount={amountValue}
                  symbol={symbol ?? undefined}
                  minAmount={participantMinLockNumber}
                  showError={insufficientBalance}
                  errorMessage={
                    insufficientBalance
                      ? `You don't currently have enough ${symbol} to make this commitment.`
                      : undefined
                  }
                  helperText={`These tokens will be locked and unavailable to be redeemed until ${unlockDate}.`}
                  onAmountChange={(value) => setAmount(String(value))}
                />

                <DurationSlider
                  duration={duration}
                  maxIntervals={maxLockIntervals}
                  lockInterval={board?.lockInterval}
                  formatDurationLabel={formatDurationLabel}
                  onDurationChange={setDuration}
                />

                <div className="space-y-2">
                  <p className="text-sm text-muted-foreground">
                    Longer locks amplify your signal. Available again on {unlockDate}
                  </p>
                </div>
              </div>

              {!hasAllowance && amount > 0 && (
                <p className="text-sm text-muted-foreground">
                  This requires a one-time approval to lock tokens.
                </p>
              )}
              {hasAllowance && (
                <div className="space-y-2">
                  <Button
                    type="button"
                    variant="link"
                    className="px-0 text-sm"
                    onClick={() => setShowAllowanceDetails((prev) => !prev)}
                  >
                    {showAllowanceDetails ? 'Hide advanced allowance' : 'Show allowance (Advanced)'}
                  </Button>
                  {showAllowanceDetails && allowance && (
                    <p className="text-sm text-muted-foreground">
                      Current allowance: {formattedAllowance}.{' '}
                      <Button variant="link" className="px-0" onClick={handleRevokeAllowance}>
                        Revoke
                      </Button>
                    </p>
                  )}
                </div>
              )}

              <AcceptanceProgressChart
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
        </div>
        <DrawerFooter>
          <div className="flex justify-end">{resolveAction()}</div>
        </DrawerFooter>
      </DrawerContent>
    </Drawer>
  )
}
