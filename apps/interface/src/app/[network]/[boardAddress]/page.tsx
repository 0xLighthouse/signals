import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { BoardConfig } from '@/components/containers/board-config'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'
import { StatsDisplay } from '@/components/stats-display'
import { RouteInitializer } from '@/components/route-initializer'

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

  const mockStats = [
    { label: 'Active initiatives', value: 12 },
    { label: 'Unique supporters', value: 348 },
    { label: 'Total staked', value: '1.2M' },
  ]

  return (
    <PageLayout>
      <BoardConfig />
      <StatsDisplay stats={mockStats} className="mb-6" />
      <InitiativesList boardAddress={boardAddress as `0x${string}`} />
    </PageLayout>
  )
}
