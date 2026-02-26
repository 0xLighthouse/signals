'use client'

import { useEffect, useMemo, useState } from 'react'
import { PlusIcon } from 'lucide-react'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useSupportDrawerStore } from '@/stores/useSupportDrawerStore'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ListContainer } from '@/components/list-container'
import { InitiativeCard } from '@/components/containers/initiatives/initiative-card'
import { PageSection } from '@/components/page-section'
import { ProposeInitiativeDrawer } from '@/components/drawers/propose-initiative-drawer'
import { SupportInitiativeDrawer } from '@/components/drawers/support-initiative-drawer'
import { Button } from '@/components/ui/button'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { toast } from 'sonner'

export const InitiativesList = ({ boardAddress }: { boardAddress: `0x${string}` }) => {
  const initiatives = useInitiativesStore((state) => state.initiatives)
  const isFetching = useInitiativesStore((state) => state.isFetching)
  const isInitialized = useInitiativesStore((state) => state.isInitialized)
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)

  // Global support drawer state
  const selectedInitiative = useSupportDrawerStore((state) => state.selectedInitiative)
  const isSupportDrawerOpen = useSupportDrawerStore((state) => state.isOpen)
  const closeDrawer = useSupportDrawerStore((state) => state.closeDrawer)

  useEffect(() => {
    if (!isInitialized && boardAddress) {
      void fetchInitiatives(boardAddress)
    }
  }, [isInitialized, fetchInitiatives, boardAddress])

  const [sortBy, setSortBy] = useState<'support' | 'createdAt'>('support')
  const [statusFilter, setStatusFilter] = useState<'active' | 'accepted' | 'archived' | null>(
    'active',
  )

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

  const handleSupportDrawerOpenChange = (open: boolean) => {
    if (!open) {
      closeDrawer()
    }
  }

  const _initiativesFiltered = useMemo(() => {
    if (!statusFilter) return initiatives
    return initiatives.filter((initiative) => initiative.status === statusFilter)
  }, [initiatives, statusFilter])

  const _initiativesSorted = useMemo(() => {
    const arr = Array.isArray(_initiativesFiltered) ? [..._initiativesFiltered] : []
    return arr.sort((a, b) =>
      sortBy === 'support' ? b.support - a.support : b.createdAtTimestamp - a.createdAtTimestamp,
    )
  }, [_initiativesFiltered, sortBy])

  if (isFetching) {
    return <LoadingSpinner />
  }

  const statusFilterTabs = (
    <Tabs
      value={statusFilter || 'active'}
      onValueChange={(value) => setStatusFilter(value as 'active' | 'accepted' | 'archived')}
    >
      <TabsList aria-label="Filter initiatives by status">
        <TabsTrigger value="active">Open</TabsTrigger>
        <TabsTrigger value="accepted">Accepted</TabsTrigger>
        <TabsTrigger value="archived">Cancelled</TabsTrigger>
      </TabsList>
    </Tabs>
  )

  const plusButton = (
    <Button variant="ghost" size="icon" onClick={handleTriggerDrawer}>
      <PlusIcon size={18} />
    </Button>
  )

  if (_initiativesSorted.length === 0) {
    return (
      <>
        <ProposeInitiativeDrawer
          open={isDrawerOpen}
          onOpenChange={setIsDrawerOpen}
          showTrigger={false}
        />
        {selectedInitiative && (
          <SupportInitiativeDrawer
            initiative={selectedInitiative}
            open={isSupportDrawerOpen}
            onOpenChange={handleSupportDrawerOpenChange}
          />
        )}
        <ListContainer leftAction={statusFilterTabs} rightAction={plusButton}>
          <PageSection>
            <div className="text-center py-8">
              <h3 className="text-lg font-medium mb-2">No initiatives found</h3>
              <p className="text-stone-500 dark:text-stone-400">
                There are currently no active initiatives.
              </p>
            </div>
          </PageSection>
        </ListContainer>
      </>
    )
  }

  return (
    <>
      <ProposeInitiativeDrawer
        open={isDrawerOpen}
        onOpenChange={setIsDrawerOpen}
        showTrigger={false}
      />
      {selectedInitiative && (
        <SupportInitiativeDrawer
          initiative={selectedInitiative}
          open={isSupportDrawerOpen}
          onOpenChange={handleSupportDrawerOpenChange}
        />
      )}
      <ListContainer leftAction={statusFilterTabs} rightAction={plusButton}>
        <div className="space-y-3">
          {_initiativesSorted.map((item, index) => (
            <InitiativeCard
              key={item.initiativeId}
              initiative={item}
              index={index}
            />
          ))}
        </div>
      </ListContainer>
    </>
  )
}
