'use client'

import { ConnectKitButton } from 'connectkit'
import React from 'react'

// Wraps the ConnectKitButton component to apply 'use client' directive
export const ConnectButton: React.FC = () => {
  return (
    <div>
      <ConnectKitButton />
    </div>
  )
}
