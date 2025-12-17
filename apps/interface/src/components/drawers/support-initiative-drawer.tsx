import { ChevronUp, CircleAlert, Info } from 'lucide-react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Slider } from '@/components/ui/slider'
import { useAccount } from '@/hooks/useAccount'
import { Card } from '@/components/ui/card'
import { useSignals } from '@/hooks/use-signals'
import { useState, useEffect, useMemo, useCallback } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import type { Initiative } from '@/types/initiative'
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
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

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
  const [selectedTier, setSelectedTier] = useState<'mild' | 'strong' | 'conviction'>('strong')
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

  const ensureDisplayAmount = (value: number) => {
    if (!Number.isFinite(value) || value <= 0) return ''
    return String(Math.max(1, Math.floor(value)))
  }

  const tierPresets = useMemo(
    () => [
      {
        id: 'minimum' as const,
        title: 'Minimum',
        description: 'Bare minimum commitment',
        footnote: 'Symbolic signal • Little influence',
        minAmount: Math.max(participantMinLockNumber, Math.floor(numericBalance * 0.02) || 0, 1),
        style: 'border-neutral-200 dark:border-neutral-800',
      },
      {
        id: 'strong' as const,
        title: 'Strong',
        description: 'Meaningful commitment',
        footnote: 'Moves the needle • Real opportunity cost',
        minAmount: Math.max(participantMinLockNumber, Math.floor(numericBalance * 0.25) || 0, 1),
        style: 'border-neutral-300 dark:border-neutral-700',
      },
      {
        id: 'deep' as const,
        title: 'Deep Conviction',
        description: 'High confidence, higher cost',
        footnote: 'Substantial influence • Long lock expected',
        minAmount: Math.max(participantMinLockNumber, Math.floor(numericBalance * 0.5) || 0, 2500),
        style: 'border-orange-400 shadow-[0_0_0_1px_rgba(251,146,60,0.4)]',
      },
      {
        id: 'all-in' as const,
        title: 'All In',
        description: 'Maximum commitment',
        footnote: 'Decisive influence • Serious sacrifice',
        minAmount: Math.max(participantMinLockNumber, Math.floor(numericBalance * 0.75) || 0, 5000),
        style:
          'border-orange-500 bg-orange-50/60 dark:bg-neutral-900 shadow-[0_0_0_1px_rgba(249,115,22,0.5)]',
      },
    ],
    [numericBalance, participantMinLockNumber],
  )

  const selectedTierPreset = tierPresets.find((tier) => tier.id === selectedTier) ?? tierPresets[1]

  const maxLockIntervals = useMemo(() => {
    if (board?.maxLockIntervals && board.maxLockIntervals > 0) return board.maxLockIntervals
    return 30
  }, [board?.maxLockIntervals])

  const clampAmountForTier = useCallback(
    (desired: number) => {
      const minFloor = participantMinLockNumber > 0 ? participantMinLockNumber : 1
      if (!Number.isFinite(desired)) return minFloor
      if (numericBalance > 0) {
        return Math.max(minFloor, Math.min(desired, numericBalance))
      }
      return Math.max(minFloor, desired)
    },
    [numericBalance, participantMinLockNumber],
  )

  const getTierDefaults = useCallback(
    (tierId: typeof selectedTier) => {
      const baseMin = participantMinLockNumber || 0
      const quarterBalance = numericBalance * 0.25
      const halfBalance = numericBalance * 0.5
      const threeQuarterBalance = numericBalance * 0.75

      switch (tierId) {
        case 'minimum':
          return {
            amount: clampAmountForTier(Math.max(1, baseMin)),
            duration: 1,
          }
        case 'strong':
          return {
            amount: clampAmountForTier(Math.max(baseMin, Math.floor(quarterBalance), 1)),
            duration: Math.max(1, Math.round(maxLockIntervals * 0.25)),
          }
        case 'deep':
          return {
            amount: clampAmountForTier(Math.max(baseMin, Math.floor(halfBalance), 1)),
            duration: Math.max(1, Math.round(maxLockIntervals * 0.5)),
          }
        case 'all-in':
        default:
          return {
            amount: clampAmountForTier(Math.max(baseMin, Math.floor(threeQuarterBalance), 1)),
            duration: Math.max(1, maxLockIntervals),
          }
      }
    },
    [clampAmountForTier, maxLockIntervals, numericBalance, participantMinLockNumber],
  )

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

  useEffect(() => {
    if (maxLockIntervals && duration > maxLockIntervals) {
      setDuration(maxLockIntervals)
    }
  }, [duration, maxLockIntervals])

  useEffect(() => {
    // When drawer opens, seed defaults for the initial tier
    if (open) {
      const defaults = getTierDefaults(selectedTier)
      setAmount(ensureDisplayAmount(defaults.amount))
      setDuration(defaults.duration)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  useEffect(() => {
    // Keep amount above tier minimum when data changes
    const min = selectedTierPreset.minAmount || 0
    if (amount < min) {
      setAmount(ensureDisplayAmount(min))
    }
  }, [amount, selectedTierPreset.minAmount])

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
    setSelectedTier('strong')
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
        <div className="overflow-y-auto flex flex-col lg:flex-row p-8 gap-8">
          <div className="lg:w-2/5 space-y-4">
            <DrawerHeader className="px-0">
              <DrawerTitle className="text-2xl">Support initiative</DrawerTitle>
              <p className="text-sm text-muted-foreground">
                Signals measures conviction, not opinion. Support only if you're willing to accept
                real opportunity cost.
              </p>
            </DrawerHeader>
            <Card className="border-neutral-200/80 dark:border-neutral-800 bg-gradient-to-r from-orange-50 via-white to-amber-50 dark:from-neutral-900 dark:via-neutral-950 dark:to-neutral-900 shadow-sm">
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
                    <div>
                      Commitment levels help distinguish symbolic support from decisive intent.
                    </div>
                    {participantMinBalance ? (
                      <div>
                        Requires at least <strong>{participantMinBalance}</strong> {symbol} balance
                        to support.
                      </div>
                    ) : (
                      <div>No minimum balance required to support.</div>
                    )}
                    {participantMinLock ? (
                      <div>
                        Minimum to lock: <strong>{participantMinLock}</strong> {symbol}.
                      </div>
                    ) : (
                      <div>No minimum lock amount required.</div>
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

          <div className="lg:w-3/5 space-y-8">
            <section className="space-y-4">
              <div>
                <h3 className="text-lg font-semibold">Select commitment level</h3>
                <p className="text-sm text-muted-foreground">
                  Signals measures conviction. How far are you willing to go?
                </p>
              </div>
              <TooltipProvider delayDuration={50}>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                  {tierPresets.map((tier) => {
                    const isSelected = selectedTier === tier.id
                    const isDisabled = numericBalance < tier.minAmount
                    return (
                      <button
                        key={tier.id}
                        type="button"
                        onClick={() => {
                          setSelectedTier(tier.id)
                          const defaults = getTierDefaults(tier.id)
                          setAmount(ensureDisplayAmount(defaults.amount))
                          setDuration(defaults.duration)
                        }}
                        className={`rounded-lg border p-4 text-left transition focus-visible:outline focus-visible:outline-2 ${
                          isSelected ? 'ring-2 ring-orange-500' : ''
                        } ${tier.style}`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <p className="font-semibold">{tier.title}</p>
                            <p className="text-sm text-muted-foreground">{tier.description}</p>
                          </div>
                          {isSelected && <Badge variant="default">Selected</Badge>}
                          {isDisabled && (
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <Info className="h-4 w-4 text-muted-foreground" />
                              </TooltipTrigger>
                              <TooltipContent side="top" align="center" className="text-xs">
                                You can choose this level, but may not be able to complete the
                                commitment yet.
                              </TooltipContent>
                            </Tooltip>
                          )}
                        </div>
                        <p className="mt-3 text-xs text-muted-foreground leading-snug">
                          {tier.footnote}
                        </p>
                      </button>
                    )
                  })}
                </div>
              </TooltipProvider>
            </section>

            <section className="space-y-6">
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="amount">Tokens at risk</Label>
                  <span className="text-sm text-muted-foreground">
                    {amount ? `${amount.toLocaleString()} ${symbol}` : 'Set an amount'}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <Input
                    id="amount"
                    type="number"
                    value={amountValue ?? undefined}
                    onFocus={() => !Number(amountValue) && setAmount('')}
                    onBlur={() => !Number(amountValue) && setAmount('0')}
                    onChange={(e) => setAmount(e.target.value)}
                  />
                  <span className="text-sm text-muted-foreground">{symbol}</span>
                </div>
                <p className="text-sm text-muted-foreground">
                  These tokens will be locked and unavailable to be redeemed until {unlockDate}.
                </p>
                {selectedTierPreset.minAmount > 0 && amount < selectedTierPreset.minAmount && (
                  <p className="text-sm text-muted-foreground">
                    Minimum commitment for this tier:{' '}
                    {Math.ceil(selectedTierPreset.minAmount).toLocaleString()} {symbol}
                  </p>
                )}
                {insufficientBalance && (
                  <p className="text-sm text-muted-foreground">
                    You don't currently have enough {symbol} to make this commitment.
                  </p>
                )}
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="duration">Lock period</Label>
                  <span className="text-sm text-muted-foreground">
                    {duration} interval{duration !== 1 ? 's' : ''}{' '}
                    {board?.lockInterval
                      ? `(${formatDurationLabel(duration * board.lockInterval)})`
                      : ''}
                  </span>
                </div>
                <Slider
                  value={[duration]}
                  step={1}
                  min={1}
                  max={maxLockIntervals}
                  onValueChange={(value) => setDuration(value[0])}
                />
                <p className="text-sm text-muted-foreground">Longer locks amplify your signal.</p>
                <p className="text-sm text-muted-foreground">Available again on {unlockDate}</p>
              </div>
            </section>

            <div className="space-y-2">
              {!hasAllowance && amount > 0 && (
                <p className="text-sm text-muted-foreground">
                  This requires a one-time approval to lock tokens.
                </p>
              )}
              {hasAllowance && (
                <Button
                  type="button"
                  variant="link"
                  className="px-0 text-sm"
                  onClick={() => setShowAllowanceDetails((prev) => !prev)}
                >
                  {showAllowanceDetails ? 'Hide advanced allowance' : 'Show allowance (Advanced)'}
                </Button>
              )}
              {showAllowanceDetails && allowance && (
                <p className="text-sm text-muted-foreground">
                  Current allowance: {formattedAllowance}.{' '}
                  <Button variant="link" className="px-0" onClick={handleRevokeAllowance}>
                    Revoke
                  </Button>
                </p>
              )}
              <div className="flex justify-end pt-4">{resolveAction()}</div>
            </div>
          </div>

          <div className="hidden lg:block w-2/5 lg:mt-6 space-y-4">
            <section className="space-y-3">
              <h3 className="text-lg font-semibold">Your Impact</h3>
              <div className="grid grid-cols-1 gap-3">
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Weight contributed</p>
                  <p className="text-xl font-semibold">{weightContributed.toLocaleString()}</p>
                </Card>
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Progress toward acceptance</p>
                  <p className="text-xl font-semibold">
                    {progressDelta ? `+${progressDelta.toFixed(1)}%` : '—'}
                  </p>
                </Card>
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Coordination hint</p>
                  <p className="text-sm">
                    {weightContributed > 0 && coordinationPeers != null
                      ? coordinationPeers <= 0
                        ? 'This commitment alone reaches acceptance.'
                        : `If ${coordinationPeers} other${coordinationPeers === 1 ? '' : 's'} commit at this level, this initiative will reach acceptance.`
                      : 'Set an amount to see coordination impact.'}
                  </p>
                </Card>
              </div>
            </section>
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
          <div className="block lg:hidden w-full space-y-4">
            <section className="space-y-3">
              <h3 className="text-lg font-semibold">Your Impact</h3>
              <div className="grid grid-cols-1 gap-3">
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Weight contributed</p>
                  <p className="text-xl font-semibold">{weightContributed.toLocaleString()}</p>
                </Card>
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Progress toward acceptance</p>
                  <p className="text-xl font-semibold">
                    {progressDelta ? `+${progressDelta.toFixed(1)}%` : '—'}
                  </p>
                </Card>
                <Card className="p-4">
                  <p className="text-sm text-muted-foreground">Coordination hint</p>
                  <p className="text-sm">
                    {weightContributed > 0 && coordinationPeers != null
                      ? coordinationPeers <= 0
                        ? 'This commitment alone reaches acceptance.'
                        : `If ${coordinationPeers} other${coordinationPeers === 1 ? '' : 's'} commit at this level, this initiative will reach acceptance.`
                      : 'Set an amount to see coordination impact.'}
                  </p>
                </Card>
              </div>
            </section>
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
      </DrawerContent>
    </Drawer>
  )
}
