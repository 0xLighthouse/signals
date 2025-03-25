import { Address } from 'viem'
import { usePrivy } from '@privy-io/react-auth'
import { useIsClient } from './useIsClient'

interface AccountData {
  address: Address | undefined
  isConnected: boolean
  isConnecting: boolean
  status: 'connecting' | 'connected' | 'disconnected'
}

export const useAccount = (): AccountData => {
  const { authenticated, user } = usePrivy()
  const isClient = useIsClient()

  if (!isClient) {
    return {
      address: undefined,
      isConnected: false,
      isConnecting: false,
      status: 'disconnected',
    }
  }

  // If Privy has a wallet address
  if (authenticated && user?.wallet?.address) {
    return {
      address: user.wallet.address as Address,
      isConnected: true,
      isConnecting: false,
      status: 'connected',
    }
  }

  return {
    address: undefined,
    isConnected: false,
    isConnecting: false,
    status: 'disconnected',
  }
}
