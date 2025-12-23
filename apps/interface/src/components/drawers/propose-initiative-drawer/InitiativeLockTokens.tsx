import { DateTime } from 'luxon'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { SwitchContainer } from '@/components/ui/switch-container'
import { AcceptanceProgressChart } from '@/components/acceptance-progress-chart'
import { AmountInput } from '../shared/AmountInput'
import { DurationSlider } from '../shared/DurationSlider'

type InitiativeLockTokensProps = {
  lockTokens: boolean
  amount: number
  duration: number
  minProposerLockAmount: number | null
  lockAmountBelowMinimum: boolean
  maxLockIntervals: number
  symbol?: string
  board: {
    lockInterval: number
    acceptanceThreshold: bigint
    decayCurveType: number
    decayCurveParameters: string
  }
  formatter: (value: number) => number
  onToggleLock: () => void
  onAmountChange: (value: number) => void
  onDurationChange: (value: number) => void
  formatDurationLabel: (seconds: number) => string
}

export function InitiativeLockTokens({
  lockTokens,
  amount,
  duration,
  minProposerLockAmount,
  lockAmountBelowMinimum,
  maxLockIntervals,
  symbol,
  board,
  formatter,
  onToggleLock,
  onAmountChange,
  onDurationChange,
  formatDurationLabel,
}: InitiativeLockTokensProps) {
  return (
    <div className="flex flex-col gap-6 my-2">
      {/* Lock tokens toggle */}
      <div className="flex items-center">
        <Label className="w-1/5 flex items-center">Lock Tokens</Label>
        <div className="w-4/5">
          <SwitchContainer className="border-0 bg-transparent dark:bg-transparent px-0">
            <Switch id="lock-tokens" checked={lockTokens} onCheckedChange={onToggleLock} />
            <Label htmlFor="lock-tokens">Also lock tokens to add support</Label>
          </SwitchContainer>
        </div>
      </div>

      {/* Amount field */}
      {lockTokens && (
        <AmountInput
          amount={amount}
          symbol={symbol}
          minAmount={minProposerLockAmount}
          showMinimum={true}
          showError={!amount || lockAmountBelowMinimum}
          errorMessage={
            !amount
              ? 'Please enter an amount to lock'
              : lockAmountBelowMinimum && minProposerLockAmount != null
                ? `Enter at least ${minProposerLockAmount.toLocaleString()} ${symbol} to meet proposer requirements`
                : undefined
          }
          onAmountChange={onAmountChange}
        />
      )}

      {/* Duration - only shown when lockTokens is true */}
      {lockTokens && (
        <>
          <DurationSlider
            duration={duration}
            maxIntervals={maxLockIntervals}
            lockInterval={board.lockInterval}
            formatDurationLabel={formatDurationLabel}
            onDurationChange={onDurationChange}
          />
          <div className="block lg:hidden">
            <AcceptanceProgressChart
              amount={amount}
              duration={duration}
              threshold={formatter(board.acceptanceThreshold)}
              initiative={{
                createdAt: DateTime.now().toSeconds(),
                lockInterval: board.lockInterval,
                decayCurveType: board.decayCurveType,
                decayCurveParameters: board.decayCurveParameters,
              }}
              existingLocks={[]}
              proposeNewInitiative={true}
              supportInitiative={lockTokens}
            />
          </div>
        </>
      )}
    </div>
  )
}
