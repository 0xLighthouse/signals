'use client'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { ConnectButton } from '@/components/web3/connect-button'
import { CreateInitiativeDrawer } from '../drawers/create-initiative-drawer'
import { Breadcrumbs } from './breadcrumbs'
import { SidebarTrigger } from '../ui/sidebar'
import { Lightbulb, Store } from 'lucide-react'
import { NavList } from './nav'

export const TopNav = () => {
  return (
    <div className="flex align-center p-4 border-neutral-200 dark:border-neutral-500 border-b">
      <div className="container mx-auto max-w-7xl flex justify-between">
        <div className="flex items-center">
          <Breadcrumbs />
        </div>
        <div className="flex items-center">
          <NavList
            items={[
              { href: '/', label: 'Initiatives', icon: Lightbulb },
              { href: '/marketplace', label: 'Marketplace', icon: Store },
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
