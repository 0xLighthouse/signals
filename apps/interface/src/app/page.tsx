import { FeedbackCards } from '@/components/containers/feedback-cards'
import { ThemeToggle } from '@/components/ui/theme-toggle'
import { HomeLogo } from '@/components/ui/home-logo'
import { ProductPrioritizationComponent } from '@/components/containers/product-prioritization'

export default function Home() {
  return (
    <div className="">
      <div className="flex align-center p-4 border-neutral-200 border-b">
        <div className="container mx-auto flex">
          <HomeLogo />
          <ThemeToggle className="ml-4" />
        </div>
      </div>
      <div className="container mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-[300px_1fr]">
          <div className="p-4">
            <p>Sidenav</p>
          </div>
          <div>
            <div className="my-6">
              <p className="text-xl font-bold">Feature requests</p>
            </div>
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
