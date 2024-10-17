'use client'

import { useAccount } from 'wagmi'
import { Submission } from '@/components/containers/submission'
import { ConnectCTAPanel } from '@/components/web3/connect-cta-panel'

export const Actions = () => {
  const { isConnected } = useAccount()
  return <div>{isConnected ? <Submission /> : <ConnectCTAPanel />}</div>
}
