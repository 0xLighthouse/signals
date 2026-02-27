'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { RouteSync } from '@/components/route-sync'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, timeAgoWords } from '@/lib/utils'
import { Info } from 'lucide-react'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

const DECAY_CURVE_LABELS: Record<number, string> = {
  0: 'Linear decay',
  1: 'Exponential decay',
}

const formatLockInterval = (seconds?: number | null) => {
  if (!seconds) return '—'
  const days = Math.round(seconds / 86400)
  if (days >= 1) {
    return `${days} ${days === 1 ? 'day' : 'days'}`
  }
  const hours = Math.round(seconds / 3600)
  return `${hours} ${hours === 1 ? 'hour' : 'hours'}`
}

export default function RulesPage() {
  const {
    board,
    boardAddress,
    network,
    underlyingName,
    underlyingSymbol,
    underlyingDecimals,
    underlyingTotalSupply,
    formatter,
  } = useSignals()

  const canFormatTokenValues = underlyingDecimals != null

  const formatTokenAmount = (value?: number | null) => {
    if (value == null || !canFormatTokenValues) {
      return '—'
    }

    const adjusted = formatter(value)
    if (!Number.isFinite(adjusted)) {
      return '—'
    }

    if (adjusted === 0) {
      return '0'
    }

    if (adjusted >= 1000) {
      return normaliseNumber(adjusted)
    }

    return adjusted.toLocaleString('en-US')
  }

  const withSymbol = (value: string) => {
    if (value === '—' || !underlyingSymbol) return value
    return `${value} ${underlyingSymbol}`
  }

  // Helper to convert string to number
  const parseToNumber = (value: string | number | null | undefined): number | null => {
    if (value == null) return null
    if (typeof value === 'number') return value
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : null
  }

  const boardTitle = board.name ?? 'Untitled board'
  const proposalThreshold = withSymbol(
    formatTokenAmount(parseToNumber(board.proposerRequirements?.minBalance)),
  )
  const acceptanceThreshold = withSymbol(
    formatTokenAmount(parseToNumber(board.acceptanceCriteria?.minThreshold)),
  )
  const lockInterval = formatLockInterval(parseToNumber(board.lockingConfig?.lockInterval))
  const decayCurve =
    board.decayConfig?.curveType != null
      ? (DECAY_CURVE_LABELS[board.decayConfig.curveType] ?? 'Custom curve')
      : 'Not set'

  // Format timestamps to local date/time
  const formatLocalDateTime = (timestamp: number | null | undefined) => {
    if (!timestamp) return '—'
    const date = new Date(timestamp * 1000) // Convert seconds to milliseconds
    return date.toLocaleString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZoneName: 'short',
    })
  }

  const opensAtLabel = formatLocalDateTime(board.opensAt)
  const closesAtLabel = formatLocalDateTime(board.closesAt)

  // Calculate min and max lock intervals
  const lockIntervalValue = parseToNumber(board.lockingConfig?.lockInterval)
  const maxLockIntervalsValue = parseToNumber(board.lockingConfig?.maxLockIntervals)
  const minLockInterval = lockIntervalValue ? formatLockInterval(lockIntervalValue) : null
  const maxLockInterval =
    lockIntervalValue && maxLockIntervalsValue
      ? formatLockInterval(lockIntervalValue * maxLockIntervalsValue)
      : null

  const lockIntervalValues: Array<{ label: string; value: string }> = []
  if (minLockInterval) {
    lockIntervalValues.push({ label: 'Min', value: minLockInterval })
  }
  if (maxLockInterval) {
    lockIntervalValues.push({ label: 'Max', value: maxLockInterval })
  }

  // Format proposer requirements
  const proposerMinBalanceRaw = board.proposerRequirements
    ? parseToNumber(board.proposerRequirements.minBalance)
    : null
  const proposerMinLockRaw = board.proposerRequirements
    ? parseToNumber(board.proposerRequirements.minLockAmount)
    : null
  const proposerMinBalance = withSymbol(formatTokenAmount(proposerMinBalanceRaw))
  const proposerMinLockAmount = withSymbol(formatTokenAmount(proposerMinLockRaw))

  const proposerRequirementsValues: Array<{ label: string; value: string }> = []
  if (proposerMinBalance && proposerMinBalance !== '0') {
    proposerRequirementsValues.push({ label: 'Min balance', value: proposerMinBalance })
  }
  if (proposerMinLockAmount && proposerMinLockAmount !== '0') {
    proposerRequirementsValues.push({ label: 'Min lock', value: proposerMinLockAmount })
  }

  // Format participant/supporter requirements
  const participantMinBalanceRaw = board.participantRequirements
    ? parseToNumber(board.participantRequirements.minBalance)
    : null
  const participantMinLockRaw = board.participantRequirements
    ? parseToNumber(board.participantRequirements.minLockAmount)
    : null
  const participantMinBalance = withSymbol(formatTokenAmount(participantMinBalanceRaw))
  const participantMinLockAmount = withSymbol(formatTokenAmount(participantMinLockRaw))

  const participantRequirementsValues: Array<{ label: string; value: string }> = []
  if (participantMinBalance && participantMinBalance !== '0') {
    participantRequirementsValues.push({ label: 'Min balance', value: participantMinBalance })
  }
  if (participantMinLockAmount && participantMinLockAmount !== '0') {
    participantRequirementsValues.push({ label: 'Min lock', value: participantMinLockAmount })
  }

  const commitmentWindow =
    lockIntervalValues.length === 2
      ? `Support can be locked for ${lockIntervalValues[0].value} to ${lockIntervalValues[1].value}.`
      : lockInterval
        ? `Support can be locked for ${lockInterval}.`
        : 'Lock duration not set.'

  return (
    <PageLayout>
      <RouteSync />
      <div className="space-y-8">
        <div>
          <h1 className="text-2xl font-semibold mb-2">Board rules</h1>
          {/* <p className="text-muted-foreground">
            These settings define how initiatives are proposed, supported, and accepted.
          </p> */}
        </div>

        <TooltipProvider delayDuration={50}>
          <div className="space-y-8">
            <section className="rounded-xl border border-stone-100 bg-stone-50 px-4 py-2 mb-6 dark:border-stone-800 dark:bg-stone-900">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-1 text-sm">
                <div className="space-y-1">
                  <div className="space-y-0.5 text-stone-900 dark:text-white">
                    <div>
                      <span className="text-stone-600 dark:text-stone-400">Board opens: </span>
                      {board.opensAt ? (
                        <>
                          {opensAtLabel}
                          <span className="text-stone-600 dark:text-stone-400">
                            {' '}({timeAgoWords(board.opensAt)})
                          </span>
                        </>
                      ) : (
                        '—'
                      )}
                    </div>
                    {board.closesAt && (
                      <div>
                        <span className="text-stone-600 dark:text-stone-400">Board closes: </span>
                        {closesAtLabel}
                        <span className="text-stone-600 dark:text-stone-400">
                          {' '}({timeAgoWords(board.closesAt)})
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Submitting new initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Minimum balance required
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        In order to propose a new initiative, you must have at least this amount of tokens in your wallet.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {proposalThreshold}
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Minimum starting support required                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        In order to propose a new initiative, you must also support it with at least this amount of tokens.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {/* {minLockAmount} */}
                    Minimum support goes here
                  </p>
                </div>
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Supporting existing initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Minimum balance required
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        In order to support an initiative, you must have at least this amount of tokens in your wallet.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {participantMinBalance}
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Minimum support amount
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        In order to support an initiative, you must contribute at least this amount of tokens.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {/* {minLockAmount} */}
                    Minimum support goes here
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Required boost lock duration
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        When adding support to an initiative, this is the minimum and maximum amount of time you can lock your tokens in order to boost the amount of support your contribution provides. A minimum of 0 days means no boost lock is required.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {minLockInterval} - {maxLockInterval}
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Boost mode
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Boosted support decays over time. This settings determines the rate at which the boosted support fades away.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {decayCurve}
                  </p>
                </div>
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Accepting and cancelling initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Support required to accept
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Once an initiative receives this amount of support, it can be accepted by the community.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {acceptanceThreshold}
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Inactivity timeout
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        If an initiative has not received any support for this amount of time, it can be closed and set as expired.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {/* {inactivityTimeout} */}
                    Inactivity timeout goes here (days?)
                  </p>
                </div>
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Minimum support amount
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        In order to support an initiative, you must contribute at least this amount of tokens.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {/* {acceptanceThreshold} */}
                    Minimum support goes here
                  </p>
                </div>
               
                <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
                      Refund delay
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-stone-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        After an initiative is accepted or closed, tokens will be returned after this amount of time.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">
                    {/* {releaseLockDuration} */}
                    Refund delay goes here (days?)
                  </p>
                </div>
             
              </div>
            </section>
          </div>
        </TooltipProvider>
      </div>
    </PageLayout>
  )
}

