'use client'

import { useSignals } from '@/hooks/use-signals'
import React, { useState } from 'react'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from '../ui/breadcrumb'
import { Slash } from 'lucide-react'

import { ArbitrumIcon } from '../icons/arbitrum'
import { BaseIcon } from '../icons/base'
import { FoundryIcon } from '../icons/foundry'

export const Breadcrumbs: React.FC = () => {
  const { underlyingName: name, underlyingSymbol: symbol, network } = useSignals()
  const [isDeployDrawerOpen, setIsDeployDrawerOpen] = useState(false)

  const Icon = network === 'local' ? FoundryIcon : network === 'base' ? BaseIcon : ArbitrumIcon

  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <p>Network</p>
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
