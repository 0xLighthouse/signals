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
        <p>
          Prölss’s publication <em>Schriften für Architekten</em> (1957) [1] inspired a study of
          this typeface genre. It led to an exploration of the relation between form and
          counter-form which is at the core of the design. Angular counters respond to the letter’s
          external curves and do so differently for each weight. The forms and counter-forms of the
          Thin and Black versions are perfectly inverted. The Light and Ultra Light weights offer
          razor-sharp positive and negative forms.&nbsp;The width of the Medium and Regular weights
          is adapted, and both offer rounder counter-shapes that recall some aspects of Aldo
          Novarese’s Microgramma. This makes them just as suitable for text use and captions at
          smaller sizes. The Bold cut is a detailed exploration of the balance between square
          counters and organic curves. Finally, the Black is spaced and kerned tightly to create a
          masterful rhythmic interaction between glyph spacing and counter-shapes, which makes it
          perfect for typesetting in blocks to the strongest impact.&nbsp;
        </p>
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
