import { notFound } from 'next/navigation'
import { getNetworkFromSlug } from '@/lib/routing'
import { PageLayout } from '@/components/containers/page-layout'
import { CreateBoardForm } from '@/components/containers/create-board-form'

interface PageProps {
  params: Promise<{
    network: string
  }>
}

export default async function CreateBoardPage({ params }: PageProps) {
  const { network } = await params
  const networkKey = getNetworkFromSlug(network)

  if (!networkKey) {
    notFound()
  }

  return (
    <PageLayout>
      <CreateBoardForm />
    </PageLayout>
  )
}
