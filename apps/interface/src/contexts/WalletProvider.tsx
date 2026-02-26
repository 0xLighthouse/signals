'use client'

import { PrivyProvider, usePrivy, useWallets } from '@privy-io/react-auth'
import { base, baseSepolia, arbitrumSepolia } from 'viem/chains'
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'

const WalletContext = createContext<IWalletContext | null>(null)

export const useWeb3 = () => {
  const context = useContext(WalletContext)
  if (!context) {
    throw new Error('useWeb3 must be used within Web3Provider')
  }
  return context
}

interface IWalletContext {
  isInitialized: boolean
}

// Separate internal component that uses Privy hooks
const WalletContextProvider = ({ children }: { children: ReactNode }) => {
  const { ready: privyReady } = usePrivy()
  const { ready: walletReady, wallets } = useWallets()
  const [isInitialized, setIsInitialized] = useState(false)

  useEffect(() => {
    if (privyReady && walletReady) {
      setIsInitialized(true)
    }
  }, [privyReady, walletReady])

  const contextValue = useMemo(
    () => ({
      isInitialized,
    }),
    [isInitialized],
  )

  return (
    <WalletContext.Provider value={contextValue}>{children as ReactNode}</WalletContext.Provider>
  )
}

/**
 * Core Web3 provider that sets up Privy
 * @param children - The child components to wrap
 * @returns
 */
export const WalletProvider = ({ children }: { children: ReactNode }) => {
  const privyAppId = process.env.NEXT_PUBLIC_PRIVY_APP_ID
  if (!privyAppId) {
    throw new Error('NEXT_PUBLIC_PRIVY_APP_ID environment variable is required')
  }

  return (
    <PrivyProvider
      appId={privyAppId}
      config={{
        appearance: {
          theme: 'dark',
        },
        supportedChains: [base, baseSepolia, arbitrumSepolia],
        defaultChain: baseSepolia, // Use baseSepolia as default
      }}
    >
      <WalletContextProvider>{children}</WalletContextProvider>
    </PrivyProvider>
  )
}
