'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { RouteSync } from '@/components/route-sync'
import { UserLocks } from '@/components/user-locks'

export default function SupportPage() {
  return (
    <PageLayout>
      <RouteSync />
      <div className="space-y-8">
        <div>
          <h1 className="text-2xl font-semibold mb-2">Your Supported Initiatives</h1>
          <p className="text-muted-foreground">
            View the initiatives you are currently supporting, and redeem tokens from closed initiatives.
          </p>
        </div>
        <UserLocks />
      </div>
    </PageLayout>
  )
}

