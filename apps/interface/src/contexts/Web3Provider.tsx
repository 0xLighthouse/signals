'use client'

import { WagmiProvider, createConfig, http } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ConnectKitProvider, getDefaultConfig } from 'connectkit'
import { arbitrumSepolia, hardhat } from 'viem/chains'

const chain = process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia

const config = createConfig(
  getDefaultConfig({
    chains: [chain],
    transports: {
      [hardhat.id]: http(process.env.NEXT_PUBLIC_RPC_URL!),
      [arbitrumSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL!),
    },

    // Required API Keys
    walletConnectProjectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID as string,

    // Required App Info
    appName: 'Signals',

    appDescription: 'Signals by Lighthouse',
    appUrl: 'https://lighthouse.cx',
    appIcon: 'https://avatars.githubusercontent.com/u/128300619?s=200&v=4', // your app's icon, no bigger than 1024x1024px (max. 1MB)
  }),
)

const queryClient = new QueryClient()

export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ConnectKitProvider debugMode>{children}</ConnectKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
