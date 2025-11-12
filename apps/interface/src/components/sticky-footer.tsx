import { HomeLogo } from './ui/home-logo'

interface StickyFooterProps {
  stats?: Array<{
    label: string
    value: string
  }>
}

export function StickyFooter({ stats }: StickyFooterProps) {
  const defaultStats = [
    { label: 'Circulating Supply', value: 'Active' },
    { label: 'network', value: 'Base Sepolia' },
  ]

  const displayStats = stats || defaultStats

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 hidden sm:flex justify-center">
      <div className="w-full mx-auto max-w-7xl px-3 sm:px-8">
        <div className="bg-neutral-100 dark:bg-neutral-900 border-t border-x border-neutral-200 dark:border-neutral-800 rounded-t-xl h-12 shadow-lg">
          <div className="flex flex-row w-full justify-between items-center h-full text-body-sm font-medium text-neutral-500 dark:text-neutral-400">
            {/* Left section - Logo and links */}
            <div className="flex items-center justify-start">
              <div className="flex gap-8">
                <div className="flex items-center gap-2">
                  <a
                    href="https://lighthouse.cx"
                    target="_blank"
                    rel="noreferrer noopener"
                    className="transition-colors duration-200 hover:text-neutral-900 dark:hover:text-neutral-50"
                  >
                    <HomeLogo />
                  </a>
                </div>
                <div className="flex items-center gap-6 border-l border-neutral-200 dark:border-neutral-800 pl-6">
                  <a
                    href="/changelog"
                    className="transition-colors duration-200 hover:text-neutral-900 dark:hover:text-neutral-50"
                  >
                    Change log
                  </a>
                </div>
              </div>
            </div>

            {/* Right section - Stats */}
            <div className="flex items-center px-6 gap-6 border-l border-neutral-200 dark:border-neutral-800">
              {displayStats.map((stat, index) => (
                <div key={`stat-item-${index}`} className="flex items-center">
                  <span className="cursor-default content-center">
                    {stat.value} {stat.label}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
