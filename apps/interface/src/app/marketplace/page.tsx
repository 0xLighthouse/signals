'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { BondsOwned } from '@/components/containers/marketplace/bonds-owned'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { BondsAvailable } from '@/components/containers/marketplace/bonds-available'
import { useState } from 'react'

type TabValue = 'sell-bonds' | 'purchase-bonds'

export default function Marketplace() {
  const [currentTab, setCurrentTab] = useState<TabValue>('sell-bonds')

  return (
    <PageLayout>
      <Tabs
        onValueChange={(value) => setCurrentTab(value as TabValue)}
        defaultValue="sell-bonds"
        className="w-full"
      >
        <TabsList className="grid w-full grid-cols-2 mb-8">
          <TabsTrigger value="sell-bonds">Sell Bond</TabsTrigger>
          <TabsTrigger value="purchase-bonds">Purchase Bond</TabsTrigger>
        </TabsList>

        <TabsContent value="sell-bonds">
          {currentTab === 'sell-bonds' && <BondsOwned />}
        </TabsContent>

        <TabsContent value="purchase-bonds">
          {currentTab === 'purchase-bonds' && <BondsAvailable />}
        </TabsContent>
      </Tabs>
    </PageLayout>
  )
}
