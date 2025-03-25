'use client'

import { PrivyProvider, usePrivy, useWallets } from '@privy-io/react-auth'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { createContext, useContext, useEffect, useState } from 'react'
import {
  createPublicClient,
  http,
  Address,
  PublicClient,
  WalletClient,
  createWalletClient,
  custom,
} from 'viem'

const chain = process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia

const Web3Context = createContext<IWeb3Context>({
  publicClient: createPublicClient({
    chain,
    transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
  }),
  walletClient: null,
  isInitialized: false,
})

export const useWeb3 = () => useContext(Web3Context)

interface IWeb3Context {
  isInitialized: boolean
  publicClient: PublicClient
  walletClient: WalletClient | null
}

// Separate internal component that uses Privy hooks
const Web3ContextProvider = ({ children }: { children: React.ReactNode }) => {
  const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const { ready: privyReady } = usePrivy()
  const { ready: walletReady, wallets } = useWallets()
  const [isInitialized, setIsInitialized] = useState(false)

  const publicClient = createPublicClient({
    chain,
    transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
  })

  useEffect(() => {
    if (privyReady && walletReady) {
      console.info(`Web3 Context initialized: ${privyReady}`)
      setIsInitialized(true)
    }
  }, [privyReady, walletReady])

  // Make a viem signer available once the app has initialized
  useEffect(() => {
    const makeWalletClient = async () => {
      const provider = await wallets[0].getEthereumProvider()
      if (provider) {
        const walletClient = createWalletClient({
          chain,
          transport: custom(provider),
        })
        setWalletClient(walletClient)
      }
    }

    if (isInitialized) {
      makeWalletClient()
    }
  }, [isInitialized, wallets])

  return (
    <Web3Context.Provider value={{ publicClient, walletClient, isInitialized }}>
      {children}
    </Web3Context.Provider>
  )
}

// Main provider that sets up Privy
export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID as string}
      config={{
        appearance: {
          theme: 'dark',
        },
        supportedChains: [chain],
        defaultChain: chain,
      }}
    >
      <Web3ContextProvider>{children}</Web3ContextProvider>
    </PrivyProvider>
  )
}
