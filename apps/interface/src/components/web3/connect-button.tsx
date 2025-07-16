import { usePrivy } from '@privy-io/react-auth'
import React from 'react'
import { Button } from '../ui/button'

// Uses Privy's login/logout functionality
export const ConnectButton: React.FC = () => {
  const { login, logout, authenticated, ready } = usePrivy()
  if (!ready) return null

  return (
    <div>
      <Button onClick={authenticated ? logout : login}>
        {authenticated ? 'Disconnect' : 'Connect'}
      </Button>
    </div>
  )
}
