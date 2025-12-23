import { CircleAlert, Loader2 } from 'lucide-react'
import { Typography } from '@/components/ui/typography'

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
      <Typography variant="h3" className="mb-2">
        Insufficient tokens
      </Typography>
      <Typography variant="body" className="text-muted-foreground max-w-md">
        You need at least {requiredAmount} {symbol} tokens to propose an initiative. Please acquire
        more tokens before trying again.
      </Typography>
      {isBalanceLoading ? (
        <div className="mt-3 flex items-center gap-2 text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          <Typography variant="body-sm">Fetching your balance…</Typography>
        </div>
      ) : (
        <Typography variant="body-sm" className="text-muted-foreground mt-3">
          Your balance: {balance} {symbol}
        </Typography>
      )}
    </div>
  )
}
