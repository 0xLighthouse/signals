'use client'

import { WagmiProvider, createConfig, http } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PrivyProvider } from '@privy-io/react-auth'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { PrivyModalProvider } from './PrivyModalContext'

const chain = process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia

const wagmiConfig = createConfig({
  chains: [chain],
  transports: {
    [hardhat.id]: http(process.env.NEXT_PUBLIC_RPC_URL!),
    [arbitrumSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL!),
  },
})

const queryClient = new QueryClient()

export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
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
      <WagmiProvider config={wagmiConfig}>
        <QueryClientProvider client={queryClient}>
          <PrivyModalProvider>
            {children}
          </PrivyModalProvider>
        </QueryClientProvider>
      </WagmiProvider>
    </PrivyProvider>
  )
}
