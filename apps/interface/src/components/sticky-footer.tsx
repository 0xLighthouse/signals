'use client'

import { useContext } from 'react'
import { ExternalLink } from 'lucide-react'
import { HomeLogo } from './ui/home-logo'
import { SignalsContext } from '@/contexts/SignalsContext'
import { useTotalSupply } from '@/hooks/use-total-supply'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'

interface StickyFooterProps {
  stats?: Array<{
    label: string
    value: string
  }>
}

export function StickyFooter({ stats }: StickyFooterProps) {
  const signalsContext = useContext(SignalsContext)
  const underlyingAddress = signalsContext?.underlyingAddress
  const underlyingSymbol = signalsContext?.underlyingSymbol
  const { totalSupply, isLoading, refetch } = useTotalSupply(underlyingAddress)
  const { config: networkConfig } = useNetworkConfig()

  // Build explorer URL for the token contract
  const getExplorerUrl = (address: `0x${string}`) => {
    const explorerUrl = networkConfig.explorerUrl
    if (!explorerUrl) return null
    // Most block explorers use /address/{address} format
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
            label: 'Total Supply:',
            value: isLoading ? '...' : totalSupply || '—',
          },
        ]
      : [])

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 hidden sm:flex justify-center">
      <div className="container mx-auto max-w-7xl px-4">
        <div className="bg-neutral-100 dark:bg-neutral-900 border-t border-x border-neutral-200 dark:border-neutral-800 rounded-t-xl h-12">
          <div className="flex flex-row w-full justify-between items-center h-full text-body-sm font-medium text-neutral-500 dark:text-neutral-400">
            {/* Left section - Logo and links */}
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
                <div className="flex items-center gap-6 border-l border-neutral-200 dark:border-neutral-800 pl-6">
                  <a
                    href="/changelog"
                    className="transition-colors duration-200 hover:text-neutral-900 dark:hover:text-neutral-50"
                  >
                    Change log
                  </a>
                </div>
              </div>
            </div>

            {/* Right section - Stats */}
            <div className="flex items-center px-6 gap-6 border-l border-neutral-200 dark:border-neutral-800">
              {displayStats.map((stat) => (
                <div key={stat.label} className="flex items-center">
                  {stats ? (
                    <span className="cursor-default content-center">
                      {stat.label} {stat.value}
                    </span>
                  ) : explorerUrl ? (
                    <a
                      href={explorerUrl}
                      target="_blank"
                      rel="noreferrer noopener"
                      onContextMenu={() => void refetch()}
                      className="cursor-pointer content-center transition-colors duration-200 hover:text-neutral-900 dark:hover:text-neutral-50 inline-flex items-center gap-1"
                      aria-label={`${stat.label}: ${stat.value}. Click to view on block explorer, right-click to refresh`}
                    >
                      {stat.label} {stat.value}
                      {underlyingSymbol && ` ${underlyingSymbol}`}
                      <ExternalLink className="h-3 w-3" aria-hidden="true" />
                    </a>
                  ) : (
                    <button
                      type="button"
                      onClick={() => void refetch()}
                      className="cursor-pointer content-center transition-colors duration-200 hover:text-neutral-900 dark:hover:text-neutral-50"
                      aria-label={`${stat.label}: ${stat.value}. Click to refresh`}
                    >
                      {stat.label} {stat.value}
                      {underlyingSymbol && ` ${underlyingSymbol}`}
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
