import { FeedbackCards } from '@/components/containers/feedback-cards'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { HomeLogo } from '@/components/ui/home-logo'
import { ProductPrioritizationComponent } from '@/components/containers/product-prioritization'
import { FaucetCard } from '@/components/containers/faucet-card'

export default function Home() {
  return (
    <div className="">
      <div className="flex align-center p-4 border-neutral-200 dark:border-neutral-500 border-b">
        <div className="container mx-auto flex">
          <HomeLogo />
          <ThemeToggle className="ml-4" />
        </div>
      </div>
      <div className="container mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-[300px_1fr]">
          <div className="px-2 py-4">
            <FaucetCard />
          </div>
          <div className="px-2 py-4">
            <ProductPrioritizationComponent />
            {/* <div className="flex border rounded-t-md border-neutral-200 bg-neutral-50 dark:bg-neutral-800 p-4">
              <p>Showing trending posts</p>
            </div>
            <FeedbackCards /> */}
          </div>
        </div>
      </div>
    </div>
  )
}
