'use client'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { ConnectButton } from '@/components/web3/connect-button'
import { Breadcrumbs } from './breadcrumbs'
import { SidebarTrigger } from '../ui/sidebar'
import { EdgeCityClaimDialog } from '@/components/edge-city/edge-city-claim-dialog'
import { TokenBalanceButton } from './token-balance-button'
import { useAccount } from '@/hooks/useAccount'
import { SecondaryNav } from './secondary-nav'

export const TopNav = () => {
  const { isConnected } = useAccount()

  return (
    <>
      <div className="flex align-center py-4 border-neutral-200 dark:border-neutral-700 border-b">
        <div className="container mx-auto max-w-7xl px-4 flex justify-between">
          <div className="flex items-center">
            <Breadcrumbs />
          </div>
          <div className="flex lg:hidden items-center gap-4">
            <TokenBalanceButton />
            <EdgeCityClaimDialog isVisible={isConnected} />
            <SidebarTrigger />
          </div>
          <div className="hidden lg:flex items-center gap-4">
            <TokenBalanceButton />
            <EdgeCityClaimDialog isVisible={isConnected} />
            <ConnectButton />
            <ThemeToggle className="" />
          </div>
        </div>
      </div>
      <SecondaryNav />
    </>
  )
}
