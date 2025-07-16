'use client'

import { useUnderlying } from '@/contexts/ContractContext'
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
import { DeploySignalsDrawer } from '../drawers/deploy-signals-drawer'
import { BoardSelector } from './board-selector'

export const Breadcrumbs: React.FC = () => {
  const { name, symbol } = useUnderlying()
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const handleBoardSelect = (boardAddress: string) => {
    // TODO: Implement switching to a different board
    console.log('Selected board:', boardAddress)
  }

  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <BreadcrumbLink>
            <div className="bg-neutral-900 rounded-full p-[2px]">
              <ArbitrumIcon />
            </div>
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
        <BreadcrumbSeparator>
          <Slash />
        </BreadcrumbSeparator>
        <BreadcrumbItem>
          <BoardSelector
            onDeployBoard={() => setIsDialogOpen(true)}
            onBoardSelect={handleBoardSelect}
          />
        </BreadcrumbItem>
      </BreadcrumbList>

      <DeploySignalsDrawer
        isOpen={isDialogOpen}
        onOpenChange={setIsDialogOpen}
        hideTrigger={true}
      />
    </Breadcrumb>
  )
}
