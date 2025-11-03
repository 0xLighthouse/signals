import type { Metadata } from 'next'

import './globals.css'

import localFont from 'next/font/local'

import { Toaster } from '@/components/ui/sonner'
import { getThemeCookie } from '@/lib/nextjs/getThemeCookie'
import { ThemeProvider } from '@/contexts/ThemeContext'
import { Web3Provider } from '@/contexts/Web3Provider'
import { BoardProvider } from '@/contexts/BoardContext'
import { SignalsProvider } from '@/contexts/SignalsContext'
import { IncentivesProvider } from '@/contexts/IncentivesContext'
import { SidebarProvider } from '@/components/ui/sidebar'
import { AppSidebar } from '@/components/containers/app-sidebar'
import { features } from '@/config/features'
import { ReactNode } from 'react'
import { Debug } from '@/components/debug'

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

  return (
    <html lang="en" className={theme}>
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        <ThemeProvider initialTheme={theme}>
          <Web3Provider>
            <BoardProvider>
              <SignalsProvider>{sidebarContent}</SignalsProvider>
            </BoardProvider>
            <Toaster />
          </Web3Provider>
        </ThemeProvider>
      </body>
    </html>
  )
}
