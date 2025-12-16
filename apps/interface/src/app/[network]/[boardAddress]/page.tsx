import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { BoardConfig } from '@/components/containers/board-config'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'
import { StatsDisplay } from '@/components/stats-display'
import { NETWORKS } from '@/config/networks'

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
        statsData?.totalLocked !== undefined
          ? Number(statsData.totalLocked).toLocaleString()
          : '—',
    },
  ]

  return (
    <PageLayout>
      <BoardConfig />
      <StatsDisplay stats={stats} className="mb-6" />
      <InitiativesList boardAddress={boardAddress as `0x${string}`} />
    </PageLayout>
  )
}
