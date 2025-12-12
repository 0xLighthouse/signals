'use client'

import { useSignals } from '@/hooks/use-signals'
import { useAccount } from '@/hooks/useAccount'
import { Button } from '@/components/ui/button'
import { Wallet } from 'lucide-react'
import { normaliseNumber } from '@/lib/utils'

export const TokenBalanceButton = () => {
  const { boardAddress, underlyingAddress, underlyingBalance, underlyingSymbol, formatter } =
    useSignals()
  const { isConnected } = useAccount()

  // Don't show if user is not connected
  if (!isConnected) {
    return null
  }

  // Show loading state if board or underlying token is not yet loaded
  const isLoading = !boardAddress || !underlyingAddress

  // Format the balance
  const formatBalance = () => {
    if (isLoading || underlyingBalance == null) {
      return '—'
    }

    const adjusted = formatter(underlyingBalance)
    if (!Number.isFinite(adjusted)) {
      return '—'
    }

    if (adjusted === 0) {
      return '0'
    }

    if (adjusted >= 1000) {
      return normaliseNumber(adjusted)
    }

    return adjusted.toLocaleString('en-US', {
      maximumFractionDigits: 4,
      minimumFractionDigits: 0,
    })
  }

  const displayBalance = formatBalance()
  const displaySymbol = underlyingSymbol ?? 'Tokens'

  return (
    <Button variant="outline" className="gap-2" disabled>
      <Wallet className="h-4 w-4" />
      <span>
        {displayBalance} {displaySymbol}
      </span>
    </Button>
  )
}
