'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { RouteSync } from '@/components/route-sync'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, timeAgoWords } from '@/lib/utils'
import { TooltipProvider } from '@/components/ui/tooltip'
import { RuleCard } from './rule-card'

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
            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Board schedule</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <RuleCard
                  label="Board opens"
                  value={
                    board.opensAt ? (
                      <>
                        {opensAtLabel} ({timeAgoWords(board.opensAt)})
                      </>
                    ) : (
                      '—'
                    )
                  }
                />
                <RuleCard
                  label="Board closes"
                  value={
                    board.closesAt ? (
                      <>
                        {closesAtLabel} ({timeAgoWords(board.closesAt)})
                      </>
                    ) : (
                      '—'
                    )
                  }
                />
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Submitting new initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <RuleCard
                  label="Minimum balance required"
                  value={proposalThreshold}
                  tooltip="In order to propose a new initiative, you must have at least this amount of tokens in your wallet."
                />
                <RuleCard
                  label="Minimum starting support required"
                  value={proposerMinLockAmount !== '—' ? proposerMinLockAmount : '—'}
                  tooltip="In order to propose a new initiative, you must also support it with at least this amount of tokens."
                />
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Supporting existing initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <RuleCard
                  label="Minimum balance required"
                  value={participantMinBalance}
                  tooltip="In order to support an initiative, you must have at least this amount of tokens in your wallet."
                />
                <RuleCard
                  label="Minimum support amount"
                  value={participantMinLockAmount !== '—' ? participantMinLockAmount : '—'}
                  tooltip="In order to support an initiative, you must contribute at least this amount of tokens."
                />
                <RuleCard
                  label="Required boost lock duration"
                  value={`${minLockInterval ?? '—'} - ${maxLockInterval ?? '—'}`}
                  tooltip="When adding support to an initiative, this is the minimum and maximum amount of time you can lock your tokens in order to boost the amount of support your contribution provides. A minimum of 0 days means no boost lock is required."
                />
                <RuleCard
                  label="Boost mode"
                  value={decayCurve}
                  tooltip="Boosted support decays over time. This setting determines the rate at which the boosted support fades away."
                />
              </div>
            </section>

            <section className="space-y-3">
              <div>
                <h3 className="text-lg font-medium">Accepting and cancelling initiatives</h3>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <RuleCard
                  label="Support required to accept"
                  value={acceptanceThreshold}
                  tooltip="Once an initiative receives this amount of support, it can be accepted by the community."
                />
                <RuleCard
                  label="Inactivity timeout"
                  value="—"
                  tooltip="If an initiative has not received any support for this amount of time, it can be closed and set as expired."
                />
                <RuleCard
                  label="Refund delay"
                  value="—"
                  tooltip="After an initiative is accepted or closed, tokens will be returned after this amount of time."
                />
              </div>
            </section>
          </div>
        </TooltipProvider>
      </div>
    </PageLayout>
  )
}

