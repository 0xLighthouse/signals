import { Initiatives } from '@/components/containers/initiatives'
import { TopNav } from '@/components/containers/topnav'
import { Actions } from '@/components/containers/actions'
import { FaucetBar } from '@/components/containers/faucet-bar'
import { Footer } from '@/components/footer'
import { FAQs } from '@/components/faqs'

export default function Home() {
  return (
    <div>
      <TopNav />
      <div className="container mx-auto max-w-7xl">
        {/* <AlertDemo /> */}
        <div className="grid grid-cols-1 md:grid-cols-[800px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <FaucetBar />
            <Initiatives />
          </div>
          <div className="px-4 py-8">
            <Actions />
            <FAQs />
            <Footer />
          </div>
        </div>
      </div>
    </div>
  )
}
