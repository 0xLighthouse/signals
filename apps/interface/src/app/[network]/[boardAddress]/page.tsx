import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'
import { RouteSync } from '@/components/route-sync'

interface PageProps {
  params: Promise<{
    network: string
    boardAddress: string
  }>
}

export default async function BoardPage({ params }: PageProps) {
  const { network, boardAddress } = await params
  const networkKey = getNetworkFromSlug(network)

  if (!networkKey) {
    notFound()
  }

  return (
    <PageLayout>
      <RouteSync />
      <InitiativesList boardAddress={boardAddress as `0x${string}`} />
    </PageLayout>
  )
}
