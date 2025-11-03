'use client'

import { PrivyProvider, usePrivy, useWallets } from '@privy-io/react-auth'
import { base, arbitrumSepolia, hardhat } from 'viem/chains'
import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import {
  createPublicClient,
  http,
  PublicClient,
  WalletClient,
  createWalletClient,
  custom,
} from 'viem'

import { useNetworkStore } from '@/stores/useNetworkStore'

const initialNetwork = useNetworkStore.getState().config

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
const Web3ContextProvider = ({ children }: { children: React.ReactNode }) => {
  const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const { ready: privyReady } = usePrivy()
  const { ready: walletReady, wallets } = useWallets()
  const [isInitialized, setIsInitialized] = useState(false)
  const config = useNetworkStore((state) => state.config)

  console.log('----- WEB3 CONTEXT -----')
  console.log('----- WEB3 CONTEXT -----')
  console.log('----- WEB3 CONTEXT -----')
  console.log('----- WEB3 CONTEXT -----')
  // omit contracts
  const { contracts, ...rest } = config
  console.log(JSON.stringify(rest, null, 2))

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
  }, [isInitialized, wallets, config.chain])

  useEffect(() => {
    if (!walletClient || !isInitialized) return

    walletClient.switchChain?.({ id: config.chain.id }).catch((error) => {
      console.warn('Wallet chain switch failed or unsupported', error)
    })
  }, [walletClient, config.chain.id, isInitialized])

  return (
    <Web3Context.Provider value={{ publicClient, walletClient, isInitialized }}>
      {children}
    </Web3Context.Provider>
  )
}

// Main provider that sets up Privy
export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
  const config = useNetworkStore((state) => state.config)

  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID as string}
      config={{
        appearance: {
          theme: 'dark',
        },
        supportedChains: [hardhat, arbitrumSepolia, base],
        defaultChain: config.chain,
      }}
    >
      <Web3ContextProvider>{children}</Web3ContextProvider>
    </PrivyProvider>
  )
}
