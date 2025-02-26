import { Config, UseAccountReturnType, useAccount as useWagmiAccount } from 'wagmi'
import { usePrivy } from '@privy-io/react-auth'
import { useIsClient } from './useIsClient'

export const useAccount = () => {
  const account = useWagmiAccount()
  const { authenticated, user } = usePrivy()
  const isClient = useIsClient()

  if (!isClient) return {} as UseAccountReturnType<Config>

  // If Privy has a wallet address but Wagmi doesn't, override with Privy's
  if (authenticated && user?.wallet?.address && !account.address) {
    return {
      ...account,
      address: user.wallet.address as `0x${string}`,
      isConnected: true,
    }
  }

  return account
}