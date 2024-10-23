import { ThemeToggle } from '@/components/ui/theme-toggle'
import { HomeLogo } from '@/components/ui/home-logo'
import { ConnectButton } from '@/components/web3/connect-button'
import { CreateInitiativeDrawer } from '../drawers/create-initiative-drawer'
import { Breadcrumbs } from './breadcrumbs'

export const TopNav = () => {
  return (
    <div className="flex align-center p-4 border-neutral-200 dark:border-neutral-500 border-b">
      <div className="container mx-auto max-w-7xl flex justify-between">
        <div className="flex align-center">
          {/* <HomeLogo /> */}
          <Breadcrumbs />
        </div>
        <div className="flex items-center gap-4">
          <CreateInitiativeDrawer />
          <ConnectButton />
          <ThemeToggle className="" />
        </div>
      </div>
    </div>
  )
}
