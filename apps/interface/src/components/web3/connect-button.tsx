import { usePrivy } from '@privy-io/react-auth'
import React from 'react'
import { Button } from '../ui/button'
import { Avatar, AvatarImage, AvatarFallback } from '../ui/avatar'
import { useAccount } from '@/hooks/useAccount'
import { shortAddress, resolveAvatar } from '@/lib/utils'
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
          <Button className="gap-2">
            <Avatar className="h-5 w-5">
              <AvatarImage src={resolveAvatar(address)} alt={address} />
              <AvatarFallback>{shortAddress(address).slice(0, 2)}</AvatarFallback>
            </Avatar>
            <span>{shortAddress(address)}</span>
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
    <Button onClick={login}>
      Sign In
    </Button>
  )
}
