import { redirect, notFound } from 'next/navigation'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import { NETWORKS } from '@/config/networks'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'
import { BoardsList } from '@/components/containers/boards/boards-lists'
import { PageLayout } from '@/components/containers/page-layout'

interface PageProps {
  params: {
    network: string
  }
}

export default function NetworkPage({ params }: PageProps) {
  const networkKey = getNetworkFromSlug(params.network)

  if (!networkKey) {
    notFound()
  }

  const config = NETWORKS[networkKey]
  const defaultBoard = config.contracts.SignalsProtocol?.address

  if (!defaultBoard) {
    // TODO: Show board selection page or "no boards available" message
    return (
      <PageLayout>
        <BoardsList />
      </PageLayout>
    )
  }

  // Redirect to the default board
  redirect(getBoardUrl(networkKey, defaultBoard))
}
