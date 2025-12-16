'use client'

import { PrivyProvider, usePrivy, useWallets } from '@privy-io/react-auth'
import { base, baseSepolia, arbitrumSepolia } from 'viem/chains'
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { useChain, usePublicClient } from '@/contexts/ChainProvider'
import type { ChainKey } from '@/lib/chains'

// Create context without default value
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
  // const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const { ready: privyReady } = usePrivy()
  const { ready: walletReady, wallets } = useWallets()
  const [isInitialized, setIsInitialized] = useState(false)
  // const primaryWallet = wallets?.[0]
  const { chainKey, setChainKey } = useChain()

  // Get network config directly from URL
  const { config } = useNetworkConfig()
  const chain = config.chain
  const chainId = config.chain.id
  const chainIdToKey: Record<number, ChainKey> = {
    8453: 'base',
    84532: 'baseSepolia',
    421614: 'arbitrumSepolia',
  }
  const resolvedChainKey = chainIdToKey[chainId] ?? 'baseSepolia'
  const publicClient = usePublicClient(resolvedChainKey)

  // useEffect(() => {
  //   if (chainKey !== resolvedChainKey) {
  //     setChainKey(resolvedChainKey as ChainKey)
  //   }
  // }, [chainKey, resolvedChainKey, setChainKey])

  useEffect(() => {
    if (privyReady && walletReady) {
      setIsInitialized(true)
    }
  }, [privyReady, walletReady])

  // // Make a viem signer available once the app has initialized and a wallet exists
  // useEffect(() => {
  //   if (!isInitialized) return

  //   if (!primaryWallet) {
  //     setWalletClient(null)
  //     return
  //   }

  //   let cancelled = false
  //   const makeWalletClient = async () => {
  //     try {
  //       const provider = await primaryWallet.getEthereumProvider?.()
  //       if (!cancelled && provider) {
  //         const client = createWalletClient({
  //           chain,
  //           transport: custom(provider),
  //         })
  //         setWalletClient(client)
  //       } else if (!cancelled) {
  //         setWalletClient(null)
  //       }
  //     } catch (err) {
  //       console.error('Failed to create wallet client', err)
  //       if (!cancelled) setWalletClient(null)
  //     }
  //   }

  //   void makeWalletClient()
  //   return () => {
  //     cancelled = true
  //   }
  // }, [isInitialized, primaryWallet, chain])

  // useEffect(() => {
  //   if (!walletClient || !isInitialized) return

  //   walletClient.switchChain?.({ id: chainId }).catch((error) => {
  //     console.warn('Wallet chain switch failed or unsupported', error)
  //   })
  // }, [walletClient, chainId, isInitialized])

  // Initialize boards on network change
  // useEffect(() => {
  //   if (!isInitialized) return
  //   void useBoardsStore.getState().fetchBoards()
  // }, [isInitialized, chainId])

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
      clientId={'client-WY5i3H68g82HsSuPNrkBkv1WAhjpqtUXhxhr8FkGdLeXF'}
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
