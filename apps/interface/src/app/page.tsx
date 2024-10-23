import { TopNav } from '@/components/containers/topnav'
import { StatsBar } from '@/components/containers/stats-bar'
import { Footer } from '@/components/footer'
import { FAQs } from '@/components/faqs'
import { InitiativesList } from '@/components/containers/initiatives/list'
import { FaucetActions } from '@/components/containers/faucet-actions'
// import { History } from '@/components/history'

export default function Home() {
  return (
    <main className="w-full">
      <TopNav />
      <div className="container mx-auto max-w-7xl">
        {/* <AlertDemo /> */}
        <div className="grid grid-cols-1 md:grid-cols-[800px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <StatsBar />
            <InitiativesList />
          </div>
          <div className="px-4 py-8">
            {/* <History /> */}
            <FAQs />
            <FaucetActions />
            <Footer />
          </div>
        </div>
      </div>
    </main>
  )
}
