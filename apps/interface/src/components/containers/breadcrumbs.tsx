'use client'

import { useBoard } from '@/contexts/BoardContext'
import React, { useState } from 'react'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from '../ui/breadcrumb'
import { Slash } from 'lucide-react'

import { DeploySignalsDrawer } from '../drawers/deploy-signals-drawer'
import { BoardSelector } from './board-selector'
import { ArbitrumIcon } from '../icons/arbitrum'
import { BaseIcon } from '../icons/base'
import { FoundryIcon } from '../icons/foundry'
import { NetworkSwitcherDialog } from './network-switcher-dialog'
import { useNetwork } from '@/hooks/useNetwork'

export const Breadcrumbs: React.FC = () => {
  const { underlyingName: name, underlyingSymbol: symbol, setActiveBoard } = useBoard()
  const [isDeployDrawerOpen, setIsDeployDrawerOpen] = useState(false)
  const [isNetworkDialogOpen, setIsNetworkDialogOpen] = useState(false)
  const { selected } = useNetwork()

  const Icon = selected === 'local' ? FoundryIcon : selected === 'base' ? BaseIcon : ArbitrumIcon

  const handleBoardSelect = (boardAddress: string) => {
    void setActiveBoard(boardAddress as `0x${string}`)
  }

  return (
    <Breadcrumb className="flex items-center">
      <BreadcrumbList>
        <BreadcrumbItem>
          <button
            type="button"
            onClick={() => setIsNetworkDialogOpen(true)}
            className="bg-neutral-900 rounded-full p-[2px] focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
          >
            <Icon className="h-6 w-6" />
          </button>
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
            onDeployBoard={() => setIsDeployDrawerOpen(true)}
            onBoardSelect={handleBoardSelect}
          />
        </BreadcrumbItem>
      </BreadcrumbList>

      <DeploySignalsDrawer
        isOpen={isDeployDrawerOpen}
        onOpenChange={setIsDeployDrawerOpen}
        hideTrigger={true}
      />
      <NetworkSwitcherDialog open={isNetworkDialogOpen} onOpenChange={setIsNetworkDialogOpen} />
    </Breadcrumb>
  )
}
