'use client'

import { useContext } from 'react'
import { ExternalLink } from 'lucide-react'
import { HomeLogo } from './ui/home-logo'
import { Wallet, Loader2 } from 'lucide-react'
import { EdgeCityClaimDialog } from '@/components/edge-city/edge-city-claim-dialog'
import { SignalsContext } from '@/contexts/SignalsContext'
import { useAccount } from '@/hooks/useAccount'
import { useSignals } from '@/hooks/use-signals'
import { useBalanceOf } from '@/hooks/useBalanceOf'
import { normaliseNumber } from '@/lib/utils'
import { useTotalSupply } from '@/hooks/use-total-supply'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

interface StickyFooterProps {
  stats?: Array<{
    label: string
    value: string
  }>
}

export function StickyFooter({ stats }: StickyFooterProps) {
  const { isConnected, address } = useAccount()
  const { underlyingAddress: sigAddress, underlyingSymbol: sigSymbol, formatter } = useSignals()
  const {
    balance: walletBalance,
    isLoading: balanceLoading,
    refetch: refetchBalance,
  } = useBalanceOf(address, sigAddress)
  const signalsContext = useContext(SignalsContext)
  const underlyingAddress = signalsContext?.underlyingAddress
  const underlyingSymbol = signalsContext?.underlyingSymbol
  const { totalSupply, isLoading, refetch } = useTotalSupply(underlyingAddress)
  const { config: networkConfig } = useNetworkConfig()

  // Build explorer URL for the token contract
  const getExplorerUrl = (address: `0x${string}`) => {
    const explorerUrl = networkConfig.explorerUrl
    if (!explorerUrl) return null
    return `${explorerUrl}/address/${address}`
  }

  const explorerUrl = underlyingAddress ? getExplorerUrl(underlyingAddress) : null

  // Use provided stats if available
  // Otherwise, if we have a board context, show total supply
  // Otherwise, don't show any stats
  const displayStats =
    stats ||
    (underlyingAddress
      ? [
          {
            label: 'Tracker:',
            value: isLoading ? '...' : totalSupply || '—',
          },
        ]
      : [])

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 hidden sm:flex justify-center">
      <div className="container mx-auto max-w-7xl px-4">
        <div className="relative backdrop-blur-sm bg-white/80 dark:bg-stone-900/80 border-t border-x border-stone-200 dark:border-stone-700 rounded-t-xl h-12">
          {/* Center section - Edge City Claim (absolute centered) */}
          <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
            <div className="pointer-events-auto cursor-pointer">
              <EdgeCityClaimDialog isVisible={isConnected} triggerVariant="inline" />
            </div>
          </div>

          <div className="relative flex flex-row w-full justify-between items-center h-full text-sm font-medium text-stone-500 dark:text-stone-400">
            {/* Left section - Logo */}
            <div className="flex items-center justify-start">
              <div className="flex gap-8 pl-2">
                <div className="flex items-center">
                  <a
                    href="https://lighthouse.cx"
                    target="_blank"
                    rel="noreferrer noopener"
                    className="transition-opacity duration-200 hover:opacity-80"
                    aria-label="Lighthouse"
                  >
                    <HomeLogo />
                  </a>
                </div>
              </div>
            </div>

            {/* Right section - Stats & Balance */}
            <div className="flex items-center h-full px-6 gap-6">
              {displayStats.map((stat) => (
                <div key={stat.label} className="flex items-center">
                  {stats ? (
                    <span className="cursor-default content-center">
                      {stat.label} {stat.value}
                    </span>
                  ) : explorerUrl ? (
                    <TooltipProvider>
                      <Tooltip>
                        <TooltipTrigger asChild>
                          <a
                            href={explorerUrl}
                            target="_blank"
                            rel="noreferrer noopener"
                            onContextMenu={() => void refetch()}
                            className="cursor-pointer content-center transition-colors duration-200 hover:text-stone-900 dark:hover:text-stone-50 inline-flex items-center gap-1"
                            aria-label={`${stat.label}: ${stat.value}. Click to view on block explorer, right-click to refresh`}
                          >
                            {stat.label} {stat.value}
                            <ExternalLink className="h-3 w-3" aria-hidden="true" />
                          </a>
                        </TooltipTrigger>
                        <TooltipContent>
                          {underlyingSymbol && <p>{underlyingSymbol}</p>}
                        </TooltipContent>
                      </Tooltip>
                    </TooltipProvider>
                  ) : (
                    <button
                      type="button"
                      onClick={() => void refetch()}
                      className="cursor-pointer content-center transition-colors duration-200 hover:text-stone-900 dark:hover:text-stone-50"
                      aria-label={`${stat.label}: ${stat.value}. Click to refresh`}
                    >
                      {stat.label} {stat.value}
                    </button>
                  )}
                </div>
              ))}
              {isConnected && sigAddress && (
                <>
                  <div className="h-4 w-px bg-stone-300 dark:bg-stone-600" />
                  <button
                    type="button"
                    onClick={() => void refetchBalance()}
                    className="inline-flex items-center gap-1 cursor-pointer transition-colors duration-200 hover:text-stone-900 dark:hover:text-stone-50"
                  >
                    {balanceLoading ? (
                      <Loader2 className="h-3 w-3 animate-spin" />
                    ) : (
                      <Wallet className="h-3 w-3" />
                    )}
                    Balance: {(() => {
                      if (balanceLoading || walletBalance == null) return '—'
                      const adjusted = formatter(Number(walletBalance))
                      if (!Number.isFinite(adjusted)) return '—'
                      if (adjusted === 0) return `0 ${sigSymbol ?? 'Tokens'}`
                      if (adjusted >= 1000)
                        return `${normaliseNumber(adjusted)} ${sigSymbol ?? 'Tokens'}`
                      return `${adjusted.toLocaleString('en-US', { maximumFractionDigits: 4, minimumFractionDigits: 0 })} ${sigSymbol ?? 'Tokens'}`
                    })()}
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
