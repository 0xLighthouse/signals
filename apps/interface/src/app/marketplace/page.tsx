import { PageLayout } from '@/components/containers/page-layout'
import { BondsList } from '@/components/containers/marketplace/bond.list'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

export default function Marketplace() {
  return (
    <PageLayout>
      <Tabs defaultValue="sell-bonds" className="w-full">
        <TabsList className="grid w-full grid-cols-2 mb-8">
          <TabsTrigger value="sell-bonds">Sell Bond</TabsTrigger>
          <TabsTrigger value="purchase-bonds">Purchase Bond</TabsTrigger>
        </TabsList>

        <TabsContent value="sell-bonds">
          <BondsList />
        </TabsContent>

        <TabsContent value="purchase-bonds">
          <p>TODO: Purchase Bonds</p>
        </TabsContent>
      </Tabs>
    </PageLayout>
  )
}
