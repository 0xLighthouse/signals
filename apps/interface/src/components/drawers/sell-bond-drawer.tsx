import { CircleAlert, Tag } from 'lucide-react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { useState } from 'react'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { BondSell } from '@/components/containers/marketplace/bond-sell'

interface SellBondDrawerProps {
  tokenId: bigint
}

export function SellBondDrawer({ tokenId }: SellBondDrawerProps) {
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)

  const handleTriggerDrawer = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    setIsDrawerOpen(true)
  }

  const handleOnOpenChange = (open: boolean) => {
    setIsDrawerOpen(open)
  }

  return (
    <Drawer dismissible={true} open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button
          variant="outline"
          size="md"
          onClick={handleTriggerDrawer}
          className="flex items-center gap-2"
        >
          <Tag className="h-4 w-4" />
          <span>Sell</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent className="p-0">
        <div className="flex-1 overflow-y-auto">
          <DrawerHeader className="p-8 pb-2">
            <DrawerTitle>Sell Bond</DrawerTitle>
            <Alert className="bg-yellow-50 dark:bg-neutral-800 mt-4">
              <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
              <AlertTitle>Sell your bond in the marketplace</AlertTitle>
              <AlertDescription>
                You can sell your bond directly into a pool or list it for sale at a fixed price.
              </AlertDescription>
            </Alert>
          </DrawerHeader>
          <div className="p-8 pt-2">
            <BondSell initialTokenId={tokenId} onSell={() => setIsDrawerOpen(false)} />
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
