'use client'

import React from 'react'
import { ConnectKitButton } from 'connectkit'
import { Button } from '../ui/button'

export const GradientConnectButton = () => {
  return (
    <ConnectKitButton.Custom>
      {({ isConnected, isConnecting, show, hide, address, ensName, chain }) => {
        return (
          <Button
            onClick={show}
            className="w-full bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700  !text-white font-bold py-2 px-4 rounded-md"
          >
            {isConnected ? address : 'Connect'}
          </Button>
        )
      }}
    </ConnectKitButton.Custom>
  )
}
