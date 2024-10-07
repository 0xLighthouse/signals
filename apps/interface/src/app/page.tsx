import { FeedbackCards } from '@/components/containers/FeedbackCards'
import { ThemeToggle } from '@/components/ThemeToggle'
import { HomeLogo } from '@/components/HomeLogo'

export default function Home() {
  return (
    <div>
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
            <div className="flex border border-t-0 border-neutral-200 bg-neutral-100 p-4">
              <p>Showing trending posts</p>
            </div>
            <FeedbackCards />
          </div>
        </div>
      </div>
    </div>
  )
}
