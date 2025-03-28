import React from 'react'
import { usePrivy } from '@privy-io/react-auth'
import { Button } from '../ui/button'

export const GradientConnectButton = () => {
  const { login, logout, authenticated, user } = usePrivy()

  return (
    <Button
      onClick={authenticated ? logout : login}
      className="w-full bg-linear-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700 text-white! font-bold py-2 px-4 rounded-md"
    >
      {authenticated ? user?.wallet?.address || 'Connected' : 'Connect'}
    </Button>
  )
}
