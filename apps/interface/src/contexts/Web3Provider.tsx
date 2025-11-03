'use client'

import { PrivyProvider, usePrivy, useWallets } from '@privy-io/react-auth'
import { base, anvil } from 'viem/chains'
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import {
  createPublicClient,
  http,
  PublicClient,
  WalletClient,
  createWalletClient,
  custom,
} from 'viem'

import { useNetworkStore } from '@/stores/useNetworkStore'
import { useBoardsStore } from '@/stores/useBoardsStore'

// Lazy initialization to avoid module-level store access
const getInitialNetwork = () => useNetworkStore.getState().config

const initialNetwork = getInitialNetwork()

const Web3Context = createContext<IWeb3Context>({
  publicClient: createPublicClient({
    chain: initialNetwork.chain,
    transport: http(initialNetwork.rpcUrl),
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
const Web3ContextProvider = ({ children }: { children: ReactNode }) => {
  const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const { ready: privyReady } = usePrivy()
  const { ready: walletReady, wallets } = useWallets()
  const [isInitialized, setIsInitialized] = useState(false)
  const config = useNetworkStore((state) => state.config)

  const publicClient = useMemo(
    () =>
      createPublicClient({
        chain: config.chain,
        transport: http(config.rpcUrl),
      }),
    [config.chain, config.rpcUrl],
  )

  useEffect(() => {
    if (privyReady && walletReady) {
      console.info(`Web3 Context initialized: ${privyReady}`)
      setIsInitialized(true)
    }
  }, [privyReady, walletReady])

  // Make a viem signer available once the app has initialized and a wallet exists
  useEffect(() => {
    if (!isInitialized) return

    if (!wallets || wallets.length === 0) {
      setWalletClient(null)
      return
    }

    let cancelled = false
    const makeWalletClient = async () => {
      try {
        const provider = await wallets[0]?.getEthereumProvider?.()
        if (!cancelled && provider) {
          const client = createWalletClient({
            chain: config.chain,
            transport: custom(provider),
          })
          setWalletClient(client)
        } else if (!cancelled) {
          setWalletClient(null)
        }
      } catch (err) {
        console.error('Failed to create wallet client', err)
        if (!cancelled) setWalletClient(null)
      }
    }

    void makeWalletClient()
    return () => {
      cancelled = true
    }
  }, [isInitialized, wallets, config])

  useEffect(() => {
    if (!walletClient || !isInitialized) return

    walletClient.switchChain?.({ id: config.chain.id }).catch((error) => {
      console.warn('Wallet chain switch failed or unsupported', error)
    })
  }, [walletClient, config.chain.id, isInitialized])

  // Initialize boards on network change
  useEffect(() => {
    if (!isInitialized) return
    void useBoardsStore.getState().fetchBoards()
  }, [isInitialized, config.chain.id])

  return (
    <Web3Context.Provider value={{ publicClient, walletClient, isInitialized }}>
      {children as ReactNode}
    </Web3Context.Provider>
  )
}

/**
 * Core Web3 provider that sets up Privy
 * @param children - The child components to wrap
 * @returns
 */
export const Web3Provider = ({ children }: { children: ReactNode }) => {
  const config = useNetworkStore((state) => state.config)

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
        supportedChains: [anvil, base],
        defaultChain: config.chain,
      }}
    >
      <Web3ContextProvider>{children}</Web3ContextProvider>
    </PrivyProvider>
  )
}
