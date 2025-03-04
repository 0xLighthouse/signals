'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PrivyProvider, usePrivy } from '@privy-io/react-auth'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { PrivyModalProvider } from './PrivyModalContext'
import { createContext, useContext, useEffect, useState } from 'react'
import { createPublicClient, http, createWalletClient, custom, Address, PublicClient, WalletClient } from 'viem'

const chain = process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia

// Create a client context to provide viem clients throughout the app
interface Web3ContextType {
  publicClient: PublicClient
  walletClient: WalletClient | null
  address: Address | null
  connect: () => Promise<void>
}

const Web3Context = createContext<Web3ContextType>({
  publicClient: createPublicClient({
    chain,
    transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
  }),
  walletClient: null,
  address: null,
  connect: async () => { },
})

export const useWeb3 = () => useContext(Web3Context)

const queryClient = new QueryClient()

export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
  const [address, setAddress] = useState<Address | null>(null)
  const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const { authenticated, ready, user, getEthereumProvider } = usePrivy()

  const publicClient = createPublicClient({
    chain,
    transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
  })

  // Connect wallet using Privy's provider
  const connect = async () => {
    try {
      const provider = await getEthereumProvider()
      if (!provider) return

      const client = createWalletClient({
        chain,
        transport: custom(provider),
      })

      const [walletAddress] = await client.requestAddresses()
      setAddress(walletAddress)
      setWalletClient(client)
    } catch (error) {
      console.error('Failed to connect wallet:', error)
    }
  }

  // Update wallet client when Privy authentication changes
  useEffect(() => {
    if (authenticated && ready && user?.wallet?.address) {
      connect()
    } else if (!authenticated) {
      setAddress(null)
      setWalletClient(null)
    }
  }, [authenticated, ready, user?.wallet?.address])

  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID as string}
      config={{
        appearance: {
          theme: 'dark',
          accentColor: '#6366f1',
        },
        supportedChains: [chain],
        defaultChain: chain,
      }}
    >
      <Web3Context.Provider value={{ publicClient, walletClient, address, connect }}>
        <QueryClientProvider client={queryClient}>
          <PrivyModalProvider>
            {children}
          </PrivyModalProvider>
        </QueryClientProvider>
      </Web3Context.Provider>
    </PrivyProvider>
  )
}
