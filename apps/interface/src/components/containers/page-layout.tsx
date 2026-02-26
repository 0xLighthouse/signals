import React from 'react'
import { TopNav } from '@/components/containers/topnav'
import { SecondaryNav } from '@/components/containers/secondary-nav'

interface PageLayoutProps {
  children: React.ReactNode
  afterNav?: React.ReactNode
}

export function PageLayout({ children, afterNav }: PageLayoutProps) {
  return (
    <main className="w-full">
      <TopNav />
      {afterNav}
      <div className="relative max-w-3xl mx-auto px-4 py-8 sm:pt-8 pt-[calc(60px+2rem)]">
        <aside className="hidden md:block absolute right-full mr-6 w-36">
          <SecondaryNav />
        </aside>
        <div className="space-y-6">
          {children}
        </div>
      </div>
    </main>
  )
}
