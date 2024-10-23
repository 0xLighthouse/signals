'use client'

import { SIGNALS_PROTOCOL } from '@/config/web3'
import { useUnderlying } from '@/contexts/ContractContext'
import { shortAddress } from '@/lib/utils'
import React, { useState } from 'react'
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from '../ui/breadcrumb'
import { ChevronDownIcon, Slash } from 'lucide-react'

import { ArbitrumIcon } from '../icons/arbitrum'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu'
import { ContactUsDialog } from '../dialogs/contact-us'

export const Breadcrumbs: React.FC = () => {
  const { name, symbol } = useUnderlying()
  const [isDialogOpen, setIsDialogOpen] = useState(false) // Manage dialog open state
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
              <BreadcrumbLink>{`${name} ${symbol}`}</BreadcrumbLink>
            </BreadcrumbItem>
          </div>
        )}
        <BreadcrumbSeparator>
          <Slash />
        </BreadcrumbSeparator>
        <BreadcrumbItem>
          <DropdownMenu>
            <DropdownMenuTrigger className="flex items-center gap-1 text-neutral-800 dark:text-neutral-200 font-bold">
              {shortAddress(SIGNALS_PROTOCOL)}
              <ChevronDownIcon size={16} />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start">
              <DropdownMenuItem onClick={() => setIsDialogOpen(true)}>
                Deploy contract
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </BreadcrumbItem>
      </BreadcrumbList>
      <ContactUsDialog isOpen={isDialogOpen} onOpenChange={setIsDialogOpen} />{' '}
      {/* Pass state and handler */}
    </Breadcrumb>
  )
}
