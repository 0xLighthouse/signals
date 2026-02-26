import { CircleAlert, Loader2 } from 'lucide-react'

type InsufficientTokensMessageProps = {
  requiredAmount: number
  symbol?: string
  balance: number
  isBalanceLoading: boolean
}

export function InsufficientTokensMessage({
  requiredAmount,
  symbol,
  balance,
  isBalanceLoading,
}: InsufficientTokensMessageProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <CircleAlert className="h-12 w-12 text-orange-500 mb-4" />
      <h3 className="text-xl font-semibold mb-2">
        Insufficient tokens
      </h3>
      <p className="text-base text-muted-foreground max-w-md">
        You need at least {requiredAmount} {symbol} tokens to propose an initiative. Please acquire
        more tokens before trying again.
      </p>
      {isBalanceLoading ? (
        <div className="mt-3 flex items-center gap-2 text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          <span className="text-sm">Fetching your balance…</span>
        </div>
      ) : (
        <p className="text-sm text-muted-foreground mt-3">
          Your balance: {balance} {symbol}
        </p>
      )}
    </div>
  )
}
