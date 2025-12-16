import type { Metadata } from 'next'

import './globals.css'

import localFont from 'next/font/local'

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

const geistSans = localFont({
  src: './fonts/GeistVF.woff',
  variable: '--font-geist-sans',
  weight: '100 900',
})
const geistMono = localFont({
  src: './fonts/GeistMonoVF.woff',
  variable: '--font-geist-mono',
  weight: '100 900',
})

export const metadata: Metadata = {
  title: 'Signals',
  description: 'Signals by Lighthouse',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode
}>) {
  // Set the tailwind theme from stored cookie preference
  const theme = getThemeCookie()

  const sidebarContent = (
    <SidebarProvider defaultOpen={false}>
      <AppSidebar />
      {children}
    </SidebarProvider>
  )

  const allowedChainKeys: ChainKey[] = ['base', 'baseSepolia', 'arbitrumSepolia']
  const initialChainKey = (
    allowedChainKeys.includes(DEFAULT_NETWORK as ChainKey)
      ? (DEFAULT_NETWORK as ChainKey)
      : 'baseSepolia'
  ) satisfies ChainKey

  return (
    <html lang="en" className={theme}>
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        <ThemeProvider initialTheme={theme}>
          <ChainProvider initialChainKey={initialChainKey}>
            <WalletProvider>
              <SignalsProvider>{sidebarContent}</SignalsProvider>
              <StickyFooter />
              <Toaster />
            </WalletProvider>
          </ChainProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
