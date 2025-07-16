import React from 'react'
import { TopNav } from '@/components/containers/topnav'
import { Footer } from '@/components/footer'
import { FAQs } from '@/components/faqs'
import { FaucetActions } from '@/components/containers/faucet-actions'

interface PageLayoutProps {
  children: React.ReactNode
  sidebar?: React.ReactNode
  fullWidth?: boolean
}

export function PageLayout({ 
  children, 
  sidebar,
  fullWidth = false 
}: PageLayoutProps) {
  const sidebarContent = sidebar || (
    <>
      <FAQs />
      <FaucetActions />
      <Footer />
    </>
  )

  return (
    <main className="w-full">
      <TopNav />
      <div className="container mx-auto max-w-7xl">
        <div className={`grid grid-cols-1 ${!fullWidth ? 'lg:grid-cols-[800px_1fr]' : ''}`}>
          <div className="px-4 py-8 space-y-6 sm:pt-8 pt-[calc(60px+2rem)]">
            {children}
          </div>
          {!fullWidth && (
            <div className="hidden lg:block px-4 py-8">
              {sidebarContent}
            </div>
          )}
        </div>
      </div>
    </main>
  )
}