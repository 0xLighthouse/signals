import { FeedbackCards } from '@/components/containers/FeedbackCards'
import { ThemeToggle } from '@/components/ThemeToggle'
import { getThemeCookie } from '@/lib/nextjs/getThemeCookie'

export default function Home() {
  const theme = getThemeCookie()
  return (
    <div>
      <div className="flex p-4 border-neutral-200 border-b">
        <p>Lighthouse</p>
        <ThemeToggle initialTheme={theme} />
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
