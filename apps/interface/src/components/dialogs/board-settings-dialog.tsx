'use client'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, shortAddress } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'

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

interface BoardSettingsDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function BoardSettingsDialog({ open, onOpenChange }: BoardSettingsDialogProps) {
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
  const proposalThreshold = withSymbol(formatTokenAmount(board.proposalThreshold))
  const acceptanceThreshold = withSymbol(formatTokenAmount(board.acceptanceThreshold))
  const lockInterval = formatLockInterval(board.lockInterval)
  const decayCurve =
    board.decayCurveType != null
      ? (DECAY_CURVE_LABELS[board.decayCurveType] ?? 'Custom curve')
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
  const minLockInterval = board.lockInterval ? formatLockInterval(board.lockInterval) : null
  const maxLockInterval =
    board.lockInterval && board.maxLockIntervals
      ? formatLockInterval(board.lockInterval * board.maxLockIntervals)
      : null

  const lockIntervalValues: Array<{ label: string; value: string }> = []
  if (minLockInterval) {
    lockIntervalValues.push({ label: 'Min', value: minLockInterval })
  }
  if (maxLockInterval) {
    lockIntervalValues.push({ label: 'Max', value: maxLockInterval })
  }

  // Format proposer requirements
  const proposerMinBalance = board.proposerRequirements?.minBalance
    ? withSymbol(formatTokenAmount(parseToNumber(board.proposerRequirements.minBalance)))
    : null
  const proposerMinLockAmount = board.proposerRequirements?.minLockAmount
    ? withSymbol(formatTokenAmount(parseToNumber(board.proposerRequirements.minLockAmount)))
    : null

  const proposerRequirementsValues: Array<{ label: string; value: string }> = []
  if (proposerMinBalance && proposerMinBalance !== '0') {
    proposerRequirementsValues.push({ label: 'Min balance', value: proposerMinBalance })
  }
  if (proposerMinLockAmount && proposerMinLockAmount !== '0') {
    proposerRequirementsValues.push({ label: 'Min lock', value: proposerMinLockAmount })
  }

  // Format participant/supporter requirements
  const participantMinBalance = board.participantRequirements?.minBalance
    ? withSymbol(formatTokenAmount(parseToNumber(board.participantRequirements.minBalance)))
    : null
  const participantMinLockAmount = board.participantRequirements?.minLockAmount
    ? withSymbol(formatTokenAmount(parseToNumber(board.participantRequirements.minLockAmount)))
    : null

  const participantRequirementsValues: Array<{ label: string; value: string }> = []
  if (participantMinBalance && participantMinBalance !== '0') {
    participantRequirementsValues.push({ label: 'Min balance', value: participantMinBalance })
  }
  if (participantMinLockAmount && participantMinLockAmount !== '0') {
    participantRequirementsValues.push({ label: 'Min lock', value: participantMinLockAmount })
  }

  const governanceConfig = [
    { label: 'Proposal threshold', value: proposalThreshold, values: undefined },
    { label: 'Acceptance threshold', value: acceptanceThreshold, values: undefined },
    {
      label: 'Lock interval',
      value: lockInterval,
      values: lockIntervalValues.length > 0 ? lockIntervalValues : undefined,
    },
    { label: 'Decay curve', value: decayCurve, values: undefined },
  ]

  // Add requirement cards if they have values
  if (proposerRequirementsValues.length > 0) {
    governanceConfig.push({
      label: 'Proposer requirements',
      value: '—',
      values: proposerRequirementsValues,
    })
  }

  if (participantRequirementsValues.length > 0) {
    governanceConfig.push({
      label: 'Supporter requirements',
      value: '—',
      values: participantRequirementsValues,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Board Settings</DialogTitle>
          <DialogDescription>View and manage settings for {boardTitle}</DialogDescription>
        </DialogHeader>
        <div className="space-y-6">
          <div>
            <h3 className="text-sm font-medium mb-2">Board Information</h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-neutral-500 dark:text-neutral-400">Address</span>
                <span className="font-mono">{addressLabel}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-neutral-500 dark:text-neutral-400">Network</span>
                <span>{networkLabel}</span>
              </div>
              {board.opensAt && (
                <div className="flex justify-between">
                  <span className="text-neutral-500 dark:text-neutral-400">Opens</span>
                  <span>{opensAtLabel}</span>
                </div>
              )}
              {board.closesAt && (
                <div className="flex justify-between">
                  <span className="text-neutral-500 dark:text-neutral-400">Closes</span>
                  <span>{closesAtLabel}</span>
                </div>
              )}
            </div>
          </div>

          <div>
            <h3 className="text-sm font-medium mb-4">Governance Configuration</h3>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              {governanceConfig.map(({ label, value, values }) => (
                <div
                  key={label}
                  className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900"
                >
                  <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                    {label}
                  </p>
                  {values && values.length > 0 ? (
                    <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                      {values.map(({ label: valueLabel, value: valueValue }, index) => (
                        <div key={valueLabel} className="flex items-baseline gap-1.5">
                          <span className="text-xs font-medium text-neutral-500 dark:text-neutral-400">
                            {valueLabel}
                          </span>
                          <span className="text-lg font-semibold text-neutral-900 dark:text-white">
                            {valueValue}
                          </span>
                          {index < values.length - 1 && (
                            <span className="text-neutral-300 dark:text-neutral-600">•</span>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-lg font-semibold text-neutral-900 dark:text-white mt-1">
                      {value}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
