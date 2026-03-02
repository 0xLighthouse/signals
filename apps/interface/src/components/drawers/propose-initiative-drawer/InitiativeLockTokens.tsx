import { AmountInput } from '../shared/AmountInput'
import { DurationSlider } from '../shared/DurationSlider'

type InitiativeLockTokensProps = {
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
  onAmountChange: (value: number) => void
  onDurationChange: (value: number) => void
  formatDurationLabel: (seconds: number) => string
}

export function InitiativeLockTokens({
  amount,
  duration,
  minProposerLockAmount,
  lockAmountBelowMinimum,
  maxLockIntervals,
  symbol,
  board,
  onAmountChange,
  onDurationChange,
  formatDurationLabel,
}: InitiativeLockTokensProps) {
  const boardRequiresLocking = minProposerLockAmount != null && minProposerLockAmount > 0
  const allowsZero = !boardRequiresLocking

  const showError = lockAmountBelowMinimum || (boardRequiresLocking && amount === 0)
  const errorMessage = showError
    ? boardRequiresLocking && amount === 0
      ? `This board requires at least ${minProposerLockAmount!.toLocaleString()} ${symbol ?? ''} to propose`
      : lockAmountBelowMinimum && minProposerLockAmount != null
        ? `Enter at least ${minProposerLockAmount.toLocaleString()} ${symbol ?? ''} to meet proposer requirements`
        : undefined
    : undefined

  return (
    <div className="flex flex-col gap-6 my-2">
      <p className="text-body-sm text-muted-foreground">
        {allowsZero
          ? `Locking tokens adds weight to your initiative and increases its chance of acceptance. Enter 0 to propose without locking.`
          : `This board requires you to lock at least ${minProposerLockAmount!.toLocaleString()} ${symbol ?? ''} to propose.`}
      </p>

      <AmountInput
        amount={amount}
        symbol={symbol}
        minAmount={minProposerLockAmount}
        showMinimum={boardRequiresLocking}
        showError={showError}
        errorMessage={errorMessage}
        onAmountChange={onAmountChange}
      />

      {/* Duration slider only relevant when the user is locking tokens */}
      {amount > 0 && (
        <DurationSlider
          duration={duration}
          maxIntervals={maxLockIntervals}
          lockInterval={board.lockInterval}
          formatDurationLabel={formatDurationLabel}
          onDurationChange={onDurationChange}
        />
      )}
    </div>
  )
}
