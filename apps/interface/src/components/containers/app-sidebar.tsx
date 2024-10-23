'use client'

import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarHeader,
  useSidebar,
} from '@/components/ui/sidebar'
import { FAQs } from '../faqs'
import { Footer } from '../footer'
import { FaucetActions } from './faucet-actions'
import { ConnectButton } from '../web3/connect-button'
import { ThemeToggle } from '../ui/theme-toggle'
export function AppSidebar() {
  // const { state, open, setOpen, openMobile, setOpenMobile, toggleSidebar } = useSidebar()
  return (
    <Sidebar side="right">
      <SidebarHeader className="p-0">
        <div className="flex items-center justify-end gap-2 border-b border-neutral-200 dark:border-neutral-500 p-2">
          <ThemeToggle />
          <ConnectButton />
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <FAQs />
          <FaucetActions />
          <Footer />
        </SidebarGroup>
      </SidebarContent>
    </Sidebar>
  )
}
