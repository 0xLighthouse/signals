'use client'

import { useAccount } from 'wagmi'
import { Submission } from '@/components/containers/submission'
import { ConnectCTAPanel } from '@/components/web3/connect-cta-panel'
import { useState, useEffect } from 'react'

export const Actions = () => {
  const { isConnected } = useAccount()
  const [isClient, setIsClient] = useState(false)

  useEffect(() => {
    setIsClient(true)
  }, [])

  if (!isClient) {
    return <div>Loading...</div>
  }

  return <div>{isConnected ? <Submission /> : <ConnectCTAPanel />}</div>
}
