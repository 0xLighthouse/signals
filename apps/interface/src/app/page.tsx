import { TopNav } from '@/components/containers/topnav'
import { StatsBar } from '@/components/containers/stats-bar'
import { Footer } from '@/components/footer'
import { FAQs } from '@/components/faqs'
import { InitiativesList } from '@/components/containers/initiatives/list'
import { FaucetActions } from '@/components/containers/faucet-actions'

export default function Home() {
  return (
    <main className="w-full">
      <TopNav />
      <div className="container mx-auto max-w-7xl">
        <div className="grid grid-cols-1 lg:grid-cols-[800px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <StatsBar />
            <InitiativesList />
          </div>
          <div className="hidden lg:block px-4 py-8">
            <FAQs />
            <FaucetActions />
            <Footer />
          </div>
        </div>
      </div>
    </main>
  )
}
