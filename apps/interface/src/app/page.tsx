import { TopNav } from '@/components/containers/topnav'
import { FaucetBar } from '@/components/containers/faucet-bar'
import { Footer } from '@/components/footer'
import { FAQs } from '@/components/faqs'
import { History } from '@/components/history'
import { InitiativesList } from '@/components/containers/initiatives/list'
import { FaucetActions } from '@/components/containers/faucet-actions'

export default function Home() {
  return (
    <div>
      <TopNav />
      <div className="container mx-auto max-w-7xl">
        {/* <AlertDemo /> */}
        <div className="grid grid-cols-1 md:grid-cols-[800px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <FaucetBar />
            <InitiativesList />
          </div>
          <div className="px-4 py-8">
            <History />
            <FAQs />
            <FaucetActions />
            <Footer />
          </div>
        </div>
      </div>
    </div>
  )
}
