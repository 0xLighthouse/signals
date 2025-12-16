import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { BoardsList } from '@/components/containers/boards/boards-lists'
import { PageLayout } from '@/components/containers/page-layout'

interface PageProps {
  params: Promise<{
    network: string
  }>
}

export default async function NetworkPage({ params }: PageProps) {
  const { network } = await params
  const networkKey = getNetworkFromSlug(network)

  if (!networkKey) {
    notFound()
  }

  return (
    <PageLayout>
      <BoardsList />
    </PageLayout>
  )
}
