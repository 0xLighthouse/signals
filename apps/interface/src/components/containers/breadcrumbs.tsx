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

export const Breadcrumbs: React.FC = () => {
  const { underlyingName: name, underlyingSymbol: symbol } = useSignals()
  const { config } = useNetworkConfig()
  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <BreadcrumbLink href={`/${config.chain.network}`}> {config.chain.name}</BreadcrumbLink>
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
        <BreadcrumbSeparator>
          <Slash />
        </BreadcrumbSeparator>
      </BreadcrumbList>
    </Breadcrumb>
  )
}
