'use client'

import { useParams, usePathname } from 'next/navigation'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import { Activity, Info, BarChart } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'

interface NavItem {
  href: string
  label: string
  icon: LucideIcon
}

export function SecondaryNav() {
  const params = useParams()
  const pathname = usePathname()

  // Only show secondary nav when we're on a board page
  const network = params?.network as string | undefined
  const boardAddress = params?.boardAddress as string | undefined

  if (!network || !boardAddress) {
    return null
  }

  const basePath = `/${network}/${boardAddress}`
  
  const navItems: NavItem[] = [
    { href: basePath, label: 'Initiatives', icon: Activity },
    { href: `${basePath}/rules`, label: 'Rules', icon: Info },
    { href: `${basePath}/insights`, label: 'Insights', icon: BarChart },
  ]

  return (
    <div className="border-b border-neutral-200 dark:border-neutral-700 bg-background">
      <div className="container mx-auto max-w-7xl px-4">
        <nav className="flex -mb-px space-x-8">
          {navItems.map((item) => {
            // For the base path (Initiatives), check if we're exactly on that path
            // For other paths, check if pathname starts with the item href
            const isActive = item.href === basePath
              ? pathname === basePath
              : pathname.startsWith(item.href)
            
            const Icon = item.icon
            
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'inline-flex items-center gap-2 whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium transition-colors',
                  isActive
                    ? 'border-primary text-foreground'
                    : 'border-transparent text-muted-foreground hover:border-neutral-300 hover:text-foreground dark:hover:border-neutral-600'
                )}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </Link>
            )
          })}
        </nav>
      </div>
    </div>
  )
}

