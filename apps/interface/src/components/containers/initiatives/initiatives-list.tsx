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
import { ButtonGroup } from '@/components/ui/button-group'
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

  const statusFilterButtons = (
    <ButtonGroup aria-label="Filter initiatives by status">
      <Button
        variant={statusFilter === 'active' ? 'default' : 'outline'}
        size="sm"
        onClick={() => setStatusFilter('active')}
      >
        Open
      </Button>
      <Button
        variant={statusFilter === 'accepted' ? 'default' : 'outline'}
        size="sm"
        onClick={() => setStatusFilter('accepted')}
      >
        Accepted
      </Button>
      <Button
        variant={statusFilter === 'archived' ? 'default' : 'outline'}
        size="sm"
        onClick={() => setStatusFilter('archived')}
      >
        Cancelled
      </Button>
    </ButtonGroup>
  )

  const plusButton = (
    <Button variant="icon" size="icon" onClick={handleTriggerDrawer}>
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
        <ListContainer leftAction={statusFilterButtons} rightAction={plusButton}>
          <PageSection>
            <div className="text-center py-8">
              <h3 className="text-lg font-medium mb-2">No initiatives found</h3>
              <p className="text-neutral-500 dark:text-neutral-400">
                There are currently no active initiatives.
              </p>
            </div>
          </PageSection>
          <InformationSection />
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
      <ListContainer leftAction={statusFilterButtons} rightAction={plusButton}>
        {_initiativesSorted.map((item, index) => (
          <InitiativeCard
            key={item.initiativeId}
            initiative={item}
            index={index}
            isFirst={index === 0}
            isLast={index === _initiativesSorted.length - 1}
          />
        ))}
        <InformationSection />
      </ListContainer>
    </>
  )
}

// Extract the information section into its own component for reuse
const InformationSection = () => (
  <PageSection className="bg-neutral-50 dark:bg-neutral-900 mt-5 border-0 shadow-none">
    <h3 className="text-lg font-medium mb-4">About Initiatives</h3>
    <ul className="list-disc pl-5 space-y-2">
      <li>Initiatives are community proposals that need support</li>
      <li>Support initiatives to help them progress to development</li>
      <li>Higher support increases an initiative's chance of implementation</li>
      <li>Create your own initiative to propose new features or improvements</li>
    </ul>
  </PageSection>
)
