import { Address } from 'viem'
import { usePrivy } from '@privy-io/react-auth'
import { useIsClient } from './useIsClient'
import { useWeb3 } from '@/contexts/Web3Provider'

interface AccountData {
  address: Address | undefined
  isConnected: boolean
  isConnecting: boolean
  status: 'connecting' | 'connected' | 'disconnected'
}

export const useAccount = (): AccountData => {
  const { address } = useWeb3()
  const { authenticated, user } = usePrivy()
  const isClient = useIsClient()

  if (!isClient) {
    return {
      address: undefined,
      isConnected: false,
      isConnecting: false,
      status: 'disconnected'
    }
  }

  // If we have an address from our viem context
  if (address) {
    return {
      address,
      isConnected: true,
      isConnecting: false,
      status: 'connected'
    }
  }

  // If Privy has a wallet address
  if (authenticated && user?.wallet?.address) {
    return {
      address: user.wallet.address as Address,
      isConnected: true,
      isConnecting: false,
      status: 'connected'
    }
  }

  return {
    address: undefined,
    isConnected: false,
    isConnecting: false,
    status: 'disconnected'
  }
}