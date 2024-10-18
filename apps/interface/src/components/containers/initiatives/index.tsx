import { Button } from '@/components/ui/button'
import { InitiativesList } from './list'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { PlusIcon } from 'lucide-react'

export function Initiatives() {
  return (
    <Tabs defaultValue="active">
      <div className="flex justify-between items-center gap-4">
        <TabsList className="grid w-full grid-cols-6">
          <TabsTrigger value="active">Active</TabsTrigger>
          <TabsTrigger value="accepted">Accepted</TabsTrigger>
          <TabsTrigger value="archived">Archived</TabsTrigger>
        </TabsList>
      </div>
      <TabsContent value="active">
        <InitiativesList type="active" />
      </TabsContent>
      <TabsContent value="accepted">
        <InitiativesList type="accepted" />
      </TabsContent>
      <TabsContent value="archived">
        <InitiativesList type="archived" />
      </TabsContent>
    </Tabs>
  )
}
