import { ThemeToggle } from '@/components/ui/theme-toggle'
import { HomeLogo } from '@/components/ui/home-logo'
import { ConnectButton } from '@/components/web3/connect-button'

export const TopNav = () => {
  return (
    <div className="flex align-center p-4 border-neutral-200 dark:border-neutral-500 border-b">
      <div className="container mx-auto max-w-5xl flex justify-between">
        <div className="flex align-center">
          <HomeLogo />
          <ThemeToggle className="ml-4" />
        </div>
        <ConnectButton />
      </div>
    </div>
  )
}
