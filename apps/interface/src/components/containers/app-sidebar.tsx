'use client'

import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarHeader,
  useSidebar,
} from '@/components/ui/sidebar'
import { Footer } from '../footer'
import { FaucetActions } from './faucet-actions'
import { ConnectButton } from '../web3/connect-button'
import { ThemeToggle } from '../ui/theme-toggle'

export function AppSidebar() {
  // const { state, open, setOpen, openMobile, setOpenMobile, toggleSidebar } = useSidebar()
  return (
    <Sidebar side="right" className="border-stone-200 dark:border-stone-700">
      <SidebarHeader className="p-0">
        <div className="flex items-center justify-end gap-2 border-b border-stone-200 dark:border-stone-700 p-2">
          <ThemeToggle />
          <ConnectButton />
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <Footer />
        </SidebarGroup>
      </SidebarContent>
    </Sidebar>
  )
}
