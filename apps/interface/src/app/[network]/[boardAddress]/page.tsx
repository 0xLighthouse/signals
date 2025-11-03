import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { StatsBar } from '@/components/containers/stats-bar'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'

interface PageProps {
  params: {
    network: string
    boardAddress: string
  }
}

export default function BoardPage({ params }: PageProps) {
  const networkKey = getNetworkFromSlug(params.network)

  if (!networkKey) {
    notFound()
  }

  // Validate board address format
  if (!params.boardAddress.match(/^0x[a-fA-F0-9]{40}$/)) {
    notFound()
  }

  return (
    <PageLayout>
      <StatsBar />
      <InitiativesList />
    </PageLayout>
  )
}
