'use client'

import { useSignals } from '@/hooks/use-signals'
import { useAccount } from '@/hooks/useAccount'
import { Button } from '@/components/ui/button'
import { Loader2, Wallet } from 'lucide-react'
import { normaliseNumber } from '@/lib/utils'
import { useBalanceOf } from '@/hooks/useBalanceOf'

export const TokenBalanceButton = () => {
  const { boardAddress, underlyingAddress, underlyingSymbol, formatter } = useSignals()
  const { isConnected, address } = useAccount()
  const { balance, isLoading, refetch } = useBalanceOf(address, underlyingAddress)

  // Don't show if user is not connected
  if (!isConnected || !underlyingAddress) {
    return null
  }

  // Format the balance
  const formatBalance = () => {
    if (isLoading || balance == null) {
      return '—'
    }

    const adjusted = formatter(Number(balance))
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
    <Button
      variant="outline"
      className="gap-2"
      onClick={() => void refetch()}
      disabled={!boardAddress || !underlyingAddress || isLoading}
    >
      {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Wallet className="h-4 w-4" />}
      <span>
        {displayBalance} {displaySymbol}
      </span>
    </Button>
  )
}
