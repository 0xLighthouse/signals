import { PageLayout } from '@/components/containers/page-layout'
import { StatsBar } from '@/components/containers/stats-bar'
import { InitiativesList } from '@/components/containers/initiatives/initiatives-list'

export default function Home() {
  return (
    <PageLayout>
      <StatsBar />
      <InitiativesList />
    </PageLayout>
  )
}