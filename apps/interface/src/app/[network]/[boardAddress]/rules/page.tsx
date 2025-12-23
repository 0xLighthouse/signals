'use client'

import { useCallback } from 'react'
import { PageLayout } from '@/components/containers/page-layout'
import { RouteSync } from '@/components/route-sync'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, shortAddress } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'
import { Button } from '@/components/ui/button'
import { Copy, Info } from 'lucide-react'
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
  const addressLabel = boardAddress ? shortAddress(boardAddress) : 'Deploying soon (stub)'
  const networkLabel = network ? (NETWORKS[network]?.chain.name ?? network) : 'Unknown network'
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

  const handleCopyAddress = useCallback(() => {
    if (!boardAddress || !navigator?.clipboard?.writeText) return
    void navigator.clipboard.writeText(boardAddress)
  }, [boardAddress])

  return (
    <PageLayout>
      <RouteSync />
      <div className="space-y-8">
        <div>
          <h1 className="text-2xl font-semibold mb-2">How this board works</h1>
          <p className="text-muted-foreground">
            These settings define how initiatives are proposed, supported, and accepted.
          </p>
        </div>

        <TooltipProvider delayDuration={50}>
          <div className="space-y-8">
            <section className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
              <h3 className="text-sm font-medium mb-2">Board overview</h3>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 text-sm">
                <div className="space-y-1">
                  <p className="text-neutral-500 dark:text-neutral-400">Network</p>
                  <p className="font-medium text-neutral-900 dark:text-white">{networkLabel}</p>
                </div>
                <div className="space-y-1">
                  <p className="text-neutral-500 dark:text-neutral-400">Board contract</p>
                  <div className="flex items-center gap-2">
                    <span className="font-mono">{addressLabel}</span>
                    {boardAddress && (
                      <Button
                        size="icon"
                        variant="ghost"
                        onClick={handleCopyAddress}
                        aria-label="Copy board address"
                      >
                        <Copy className="h-4 w-4" />
                      </Button>
                    )}
                  </div>
                </div>
                <div className="space-y-1">
                  <p className="text-neutral-500 dark:text-neutral-400">Active period</p>
                  <p className="text-neutral-900 dark:text-white">
                    {board.opensAt ? `Opens ${opensAtLabel}` : 'Opens —'}
                    {board.closesAt ? ` · Closes ${closesAtLabel}` : ''}
                  </p>
                </div>
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-sm font-medium">Decision rules</h3>
                <p className="text-sm text-neutral-500 dark:text-neutral-400">
                  These parameters shape how ideas gain traction and move forward.
                </p>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      Who can propose
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Proposers lock this amount to submit. Discourages spam; signals commitment.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-neutral-900 dark:text-white mt-1">
                    {proposalThreshold}
                  </p>
                </div>
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      What it takes to pass
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Total support needed for acceptance. Support adds up as members lock tokens and time.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-neutral-900 dark:text-white mt-1">
                    {acceptanceThreshold}
                  </p>
                </div>
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      Commitment window
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Range of time supporters can lock. Longer locks = stronger signals, less flexibility.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-neutral-900 dark:text-white mt-1">
                    {lockInterval}
                  </p>
                  <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1">{commitmentWindow}</p>
                </div>
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      How support changes over time
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Influence decays unless participants renew or reinforce their commitment.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <p className="text-lg font-semibold text-neutral-900 dark:text-white mt-1">
                    {decayCurve}
                  </p>
                </div>
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-sm font-medium">Participation rules</h3>
                <p className="text-sm text-neutral-500 dark:text-neutral-400">
                  What's expected from proposers and supporters.
                </p>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      To propose an initiative
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Proposers must hold and lock to keep submissions meaningful.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <div className="mt-2 space-y-1 text-sm text-neutral-900 dark:text-white">
                    {proposerRequirementsValues.length > 0 ? (
                      proposerRequirementsValues.map(({ label, value }) => (
                        <div key={label} className="flex items-center gap-2">
                          <span className="text-neutral-600 dark:text-neutral-400">{label}:</span>
                          <span className="font-medium">{value}</span>
                        </div>
                      ))
                    ) : (
                      <p className="text-neutral-500 dark:text-neutral-400">
                        No additional requirements.
                      </p>
                    )}
                  </div>
                </div>
                <div className="rounded-xl border border-neutral-100 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                      To support an initiative
                    </p>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-neutral-400" />
                      </TooltipTrigger>
                      <TooltipContent side="top" className="max-w-xs text-xs">
                        Supporters commit balance and a minimum lock so every signal carries weight.
                      </TooltipContent>
                    </Tooltip>
                  </div>
                  <div className="mt-2 space-y-1 text-sm text-neutral-900 dark:text-white">
                    {participantRequirementsValues.length > 0 ? (
                      participantRequirementsValues.map(({ label, value }) => (
                        <div key={label} className="flex items-center gap-2">
                          <span className="text-neutral-600 dark:text-neutral-400">{label}:</span>
                          <span className="font-medium">{value}</span>
                        </div>
                      ))
                    ) : (
                      <p className="text-neutral-500 dark:text-neutral-400">
                        No additional requirements.
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </section>
          </div>
        </TooltipProvider>
      </div>
    </PageLayout>
  )
}

