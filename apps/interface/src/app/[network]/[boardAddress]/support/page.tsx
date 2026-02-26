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
          <h1 className="text-2xl font-semibold mb-2">Your Locks</h1>
          <p className="text-muted-foreground">
            View and redeem your locked tokens for this board
          </p>
        </div>
        <UserLocks />
      </div>
    </PageLayout>
  )
}

