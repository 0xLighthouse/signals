'use client'
import { usePathname } from 'next/navigation'
import { ConnectButton } from '@/components/web3/connect-button'
import { SidebarTrigger } from '../ui/sidebar'
import { NetworkSwitcher } from './network-switcher'
import { useSignals } from '@/hooks/use-signals'

export const TopNav = () => {
  const { board, underlyingName, underlyingSymbol: symbol } = useSignals()
  const pathname = usePathname()
  const name = board.name ?? underlyingName
  const isCreateBoard = pathname.endsWith('/create-board')

  return (
    <>
      <div className="flex align-center py-6">
        <div className="container mx-auto max-w-7xl px-4 grid grid-cols-3 items-center">
          <div className="flex items-center gap-4">
            <div className="flex lg:hidden">
              <SidebarTrigger />
            </div>
            <NetworkSwitcher />
          </div>
          <div className="text-center">
            {isCreateBoard ? (
              <h1 className="text-h2 font-semibold">Create Board</h1>
            ) : name && symbol ? (
              <h1 className="text-h2 font-semibold">{`${name} (${symbol})`}</h1>
            ) : null}
          </div>
          <div className="hidden lg:flex items-center gap-4 justify-end">
            <ConnectButton />
          </div>
        </div>
      </div>
    </>
  )
}
