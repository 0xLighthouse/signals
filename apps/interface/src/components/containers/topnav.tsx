'use client'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { ConnectButton } from '@/components/web3/connect-button'
import { Breadcrumbs } from './breadcrumbs'
import { SidebarTrigger } from '../ui/sidebar'

export const TopNav = () => {
  return (
    <>
      <div className="flex align-center py-6">
        <div className="container mx-auto max-w-7xl px-4 flex justify-between">
          <div className="flex items-center">
            <Breadcrumbs />
          </div>
          <div className="flex lg:hidden items-center gap-4">
            <SidebarTrigger />
          </div>
          <div className="hidden lg:flex items-center gap-4">
            <ConnectButton />
            <ThemeToggle className="" />
          </div>
        </div>
      </div>
    </>
  )
}
