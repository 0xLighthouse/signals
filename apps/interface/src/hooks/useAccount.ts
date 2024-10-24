import { Config, UseAccountReturnType, useAccount as useWagmiAccount } from 'wagmi'
import { useIsClient } from './useIsClient'

export const useAccount = () => {
  const account = useWagmiAccount()
  const isClient = useIsClient()

  if (!isClient) return {} as UseAccountReturnType<Config>

  return account
}