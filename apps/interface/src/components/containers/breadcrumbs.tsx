'use client'

import { useSignals } from '@/hooks/use-signals'
import React from 'react'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from '../ui/breadcrumb'
import { Slash, ExternalLink } from 'lucide-react'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { BaseIcon } from '@/components/icons/base'
import { ArbitrumIcon } from '@/components/icons/arbitrum'
import type { SupportedNetworks } from '@/config/network-types'

const getNetworkIcon = (network: SupportedNetworks) => {
  if (network === 'base' || network === 'baseSepolia') {
    return BaseIcon
  }
  if (network === 'arbitrumSepolia') {
    return ArbitrumIcon
  }
  return BaseIcon // fallback
}

export const Breadcrumbs: React.FC = () => {
  const { board, boardAddress, underlyingName, underlyingSymbol: symbol } = useSignals()
  const { config, network } = useNetworkConfig()
  const NetworkIcon = getNetworkIcon(network)
  
  // Use board metadata name if available, fallback to underlying token name
  const name = board.name ?? underlyingName
  
  // Build explorer URL for the board contract
  const getExplorerUrl = (address: `0x${string}`) => {
    const explorerUrl = config.explorerUrl
    if (!explorerUrl) return null
    return `${explorerUrl}/address/${address}`
  }

  const explorerUrl = boardAddress ? getExplorerUrl(boardAddress) : null
  
  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <BreadcrumbLink
            href={`/${network}`}
            className="flex items-center"
            aria-label={config.chain.name}
          >
            <NetworkIcon className="h-6 w-6" aria-label={config.chain.name} />
          </BreadcrumbLink>
        </BreadcrumbItem>
        {name && symbol && (
          <div className="hidden sm:inline-flex items-center gap-1.5">
            <BreadcrumbSeparator>
              <Slash />
            </BreadcrumbSeparator>
            <BreadcrumbItem>
              {explorerUrl ? (
                <BreadcrumbLink
                  href={explorerUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1"
                >
                  {`${name} (${symbol})`}
                  <ExternalLink className="h-3 w-3" />
                </BreadcrumbLink>
              ) : (
                <BreadcrumbLink>{`${name} (${symbol})`}</BreadcrumbLink>
              )}
            </BreadcrumbItem>
          </div>
        )}
      </BreadcrumbList>
    </Breadcrumb>
  )
}
