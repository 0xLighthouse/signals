import type { Metadata } from 'next'
import { apercu } from './fonts'

import './globals.css'

import { Toaster } from '@/components/ui/sonner'
import { getThemeCookie } from '@/lib/nextjs/getThemeCookie'
import { ThemeProvider } from '@/contexts/ThemeContext'
import { WalletProvider } from '@/contexts/WalletProvider'
import { SignalsProvider } from '@/contexts/SignalsContext'
import { ChainProvider } from '@/contexts/ChainProvider'
import type { ChainKey } from '@/lib/chains'
import { DEFAULT_NETWORK } from '@/config/network-config'
// TODO[fixme]: IncentivesProvider refactor
// import { IncentivesProvider } from '@/contexts/IncentivesContext'
import { SidebarProvider } from '@/components/ui/sidebar'
import { AppSidebar } from '@/components/containers/app-sidebar'
import { StickyFooter } from '@/components/sticky-footer'
import { ReactNode } from 'react'

export const metadata: Metadata = {
  title: 'Signals',
  description: 'Signals by Lighthouse',
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: ReactNode
}>) {
  // Set the tailwind theme from stored cookie preference
  const theme = await getThemeCookie()

  const sidebarContent = (
    <>
      <SidebarProvider defaultOpen={false}>
        <AppSidebar />
        {children}
      </SidebarProvider>
      <StickyFooter />
    </>
  )

  const allowedChainKeys: ChainKey[] = ['base', 'baseSepolia', 'arbitrumSepolia']
  const initialChainKey = (
    allowedChainKeys.includes(DEFAULT_NETWORK as ChainKey)
      ? (DEFAULT_NETWORK as ChainKey)
      : 'baseSepolia'
  ) satisfies ChainKey

  return (
    <html lang="en" className={`theme ${apercu.variable}`}>
      <body>
        <ThemeProvider initialTheme={theme}>
          <ChainProvider initialChainKey={initialChainKey}>
            <WalletProvider>
              <SignalsProvider>{sidebarContent}</SignalsProvider>
              <Toaster />
            </WalletProvider>
          </ChainProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
