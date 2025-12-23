import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { StatsDisplay } from '@/components/stats-display'
import { NETWORKS } from '@/config/networks'
import { RouteSync } from '@/components/route-sync'

interface PageProps {
  params: Promise<{
    network: string
    boardAddress: string
  }>
}

export default async function InsightsPage({ params }: PageProps) {
  const { network, boardAddress } = await params
  const networkKey = getNetworkFromSlug(network)

  if (!networkKey) {
    notFound()
  }

  const config = NETWORKS[networkKey]
  const boardAddressNormalized = boardAddress.toLowerCase()

  type StatsResponse = {
    activeInitiativeCount: number
    uniqueSupporters: number
    totalLocked: number | string
  }

  let statsData: StatsResponse | null = null

  try {
    const resp = await fetch(
      `${config.indexerEndpoint}/stats/${config.chain.id}/${boardAddressNormalized}`,
      { cache: 'no-store' },
    )

    if (resp.ok) {
      statsData = (await resp.json()) as StatsResponse
    } else {
      console.error(`Failed to fetch stats: ${resp.status} ${resp.statusText}`)
    }
  } catch (error) {
    console.error('Error fetching stats', error)
  }

  const stats = [
    { label: 'Active initiatives', value: statsData?.activeInitiativeCount ?? '—' },
    { label: 'Unique supporters', value: statsData?.uniqueSupporters ?? '—' },
    {
      label: 'Total locked',
      value:
        statsData?.totalLocked !== undefined ? Number(statsData.totalLocked).toLocaleString() : '—',
    },
  ]

  return (
    <PageLayout>
      <RouteSync />
      <div className="space-y-8">
        <div>
          <h1 className="text-2xl font-semibold mb-2">Board insights</h1>
          <p className="text-muted-foreground">
            Overview of activity and engagement on this board.
          </p>
        </div>
        <div>
          <h2 className="text-lg font-medium mb-4">Overview</h2>
          <StatsDisplay stats={stats} />
        </div>
      </div>
    </PageLayout>
  )
}

