import React from 'react'
import { TopNav } from '@/components/containers/topnav'

interface PageLayoutProps {
  children: React.ReactNode
  afterNav?: React.ReactNode
}

export function PageLayout({ children, afterNav }: PageLayoutProps) {
  return (
    <main className="w-full">
      <TopNav />
      {afterNav}
      <div className="max-w-3xl mx-auto px-4 py-8 space-y-6 sm:pt-8 pt-[calc(60px+2rem)]">
        {children}
      </div>
    </main>
  )
}
