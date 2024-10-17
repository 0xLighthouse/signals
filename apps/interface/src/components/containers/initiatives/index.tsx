import { InitiativesList } from './list'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

export function Initiatives() {
  return (
    <Tabs defaultValue="upcoming">
      <TabsList className="grid w-full grid-cols-6">
        <TabsTrigger value="upcoming">Upcoming </TabsTrigger>
        <TabsTrigger value="accepted">Accepted</TabsTrigger>
        <TabsTrigger value="executed">Executed</TabsTrigger>
        <TabsTrigger value="archived">Archived </TabsTrigger>
      </TabsList>
      <TabsContent value="upcoming">
        <InitiativesList type="upcoming" />
      </TabsContent>
      <TabsContent value="accepted">
        <InitiativesList type="accepted" />
      </TabsContent>
      <TabsContent value="executed">
        <InitiativesList type="executed" />
      </TabsContent>
      <TabsContent value="archived">
        <InitiativesList type="archived" />
      </TabsContent>
    </Tabs>
  )
}
