'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { BondsOwned } from '@/components/containers/marketplace/bonds-owned'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { BondsAvailable } from '@/components/containers/marketplace/bonds-available'

export default function Marketplace() {
  return (
    <PageLayout>
      <Tabs defaultValue="sell-bonds" className="w-full">
        <TabsList className="grid w-full grid-cols-2 mb-8">
          <TabsTrigger value="sell-bonds">Sell Bond</TabsTrigger>
          <TabsTrigger value="purchase-bonds">Purchase Bond</TabsTrigger>
        </TabsList>

        <TabsContent value="sell-bonds">
          <BondsOwned />
        </TabsContent>

        <TabsContent value="purchase-bonds">
          <BondsAvailable />
        </TabsContent>
      </Tabs>
    </PageLayout>
  )
}
