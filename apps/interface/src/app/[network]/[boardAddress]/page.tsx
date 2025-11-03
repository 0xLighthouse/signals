import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { StatsBar } from '@/components/containers/stats-bar'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'

interface PageProps {
  params: Promise<{
    network: string
    boardAddress: string
  }>
}

export default async function BoardPage({ params }: PageProps) {
  const { network, boardAddress } = await params
  const networkKey = getNetworkFromSlug(network)

  console.log('networkKey', networkKey)
  console.log('boardAddress', boardAddress)

  if (!networkKey) {
    notFound()
  }

  return (
    <PageLayout>
      {/* <StatsBar /> */}
      <InitiativesList />
    </PageLayout>
  )
}
