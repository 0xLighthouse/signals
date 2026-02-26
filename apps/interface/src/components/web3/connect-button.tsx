import { usePrivy } from '@privy-io/react-auth'
import React from 'react'
import { Button } from '../ui/button'
import { Avatar, AvatarImage, AvatarFallback } from '../ui/avatar'
import { useAccount } from '@/hooks/useAccount'
import { shortAddress, resolveAvatar } from '@/lib/utils'
import { ChevronsUpDown } from 'lucide-react'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu'

// Uses Privy's login/logout functionality
export const ConnectButton: React.FC = () => {
  const { login, logout, authenticated, ready } = usePrivy()
  const { address } = useAccount()

  if (!ready) return null

  // When authenticated, show dropdown menu
  if (authenticated && address) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="flex h-auto items-center gap-3 px-3 py-2">
            <Avatar className="h-10 w-10 rounded-xl">
              <AvatarImage src={resolveAvatar(address)} alt={address} />
              <AvatarFallback className="rounded-xl">{shortAddress(address).slice(0, 2)}</AvatarFallback>
            </Avatar>
            <div className="text-left leading-tight">
              <div className="text-base font-medium">{shortAddress(address)}</div>
            </div>
            <ChevronsUpDown className="h-4 w-4 text-muted-foreground" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem>Profile</DropdownMenuItem>
          <DropdownMenuItem onClick={logout}>Logout</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  }

  // When not authenticated, show simple connect button
  return (
    <Button variant="ghost" className="flex h-auto items-center gap-3 px-3 py-2 text-base font-medium" onClick={login}>
      Sign In
    </Button>
  )
}
