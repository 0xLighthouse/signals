import { ProductPrioritizationComponent } from '@/components/containers/product-prioritization'
import { FaucetCard } from '@/components/containers/faucet-card'
import { TopNav } from '@/components/containers/topnav'
import { InstructionsCard } from '@/components/containers/instructions'

export default function Home() {
  return (
    <div>
      <TopNav />
      <div className="container mx-auto  max-w-5xl">
        <div className="grid grid-cols-1 md:grid-cols-[300px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <InstructionsCard />
            <FaucetCard />
          </div>
          <div className="px-4 py-8">
            <ProductPrioritizationComponent />
          </div>
        </div>
      </div>
    </div>
  )
}
