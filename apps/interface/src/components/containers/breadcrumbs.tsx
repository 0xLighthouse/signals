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
import { Slash } from 'lucide-react'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { NETWORK_SLUGS } from '@/lib/routing'
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
  const { underlyingName: name, underlyingSymbol: symbol } = useSignals()
  const { config, network } = useNetworkConfig()
  const NetworkIcon = getNetworkIcon(network)
  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <BreadcrumbLink
            href={`/${config.chain.network}`}
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
              <BreadcrumbLink>{`${name} (${symbol})`}</BreadcrumbLink>
            </BreadcrumbItem>
          </div>
        )}
      </BreadcrumbList>
    </Breadcrumb>
  )
}
