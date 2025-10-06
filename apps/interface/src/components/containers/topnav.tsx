'use client'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { ConnectButton } from '@/components/web3/connect-button'
import { CreateInitiativeDrawer } from '../drawers/create-initiative-drawer'
import { Breadcrumbs } from './breadcrumbs'
import { SidebarTrigger } from '../ui/sidebar'
import { Lightbulb } from 'lucide-react'
import { NavList } from './nav'

export const TopNav = () => {
  return (
    <div className="flex align-center p-4 border-neutral-200 dark:border-neutral-700 border-b">
      <div className="container mx-auto max-w-7xl flex justify-between relative">
        <div className="flex items-center">
          <Breadcrumbs />
        </div>
        <div className="flex items-center absolute left-1/2 transform -translate-x-1/2 sm:top-0 top-[60px]">
          <NavList
            items={[
              { href: '/', label: 'Initiatives', icon: Lightbulb },
            ]}
            className="max-w-md"
          />
        </div>
        <div className="flex lg:hidden items-center gap-4">
          <CreateInitiativeDrawer />
          <SidebarTrigger />
        </div>
        <div className="hidden lg:flex items-center gap-4">
          <CreateInitiativeDrawer />
          <ConnectButton />
          <ThemeToggle className="" />
        </div>
      </div>
    </div>
  )
}
