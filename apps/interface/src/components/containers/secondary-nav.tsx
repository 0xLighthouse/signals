'use client'

import { useParams, usePathname } from 'next/navigation'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import { Activity, Info, BarChart, PlusCircle, BookOpenText, ExternalLink } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'

interface NavItem {
  href: string
  label: string
  icon: LucideIcon
}

export function SecondaryNav() {
  const params = useParams()
  const pathname = usePathname()

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
    { href: `${basePath}/support`, label: 'My Support', icon: PlusCircle },
  ]

  return (
    <nav className="flex flex-col sticky top-8">
      {navItems.map((item) => {
        const isActive =
          item.href === basePath ? pathname === basePath : pathname.startsWith(item.href)

        const Icon = item.icon

        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'inline-flex items-center gap-2 whitespace-nowrap px-2 py-1.5 text-sm transition-colors',
              isActive
                ? 'font-medium text-foreground'
                : 'text-stone-400 hover:text-stone-950 dark:text-stone-500 dark:hover:text-stone-50',
            )}
          >
            <Icon className="h-4 w-4" />
            {item.label}
          </Link>
        )
      })}
      <div className="h-px bg-stone-200 dark:bg-stone-700 my-1" />
      <a
        href="https://signals.docs.lighthouse.cx"
        target="_blank"
        rel="noreferrer"
        aria-label="Docs (opens in new tab)"
        className="inline-flex items-center gap-2 whitespace-nowrap px-2 py-1.5 text-sm text-stone-400 hover:text-stone-950 dark:text-stone-500 dark:hover:text-stone-50 transition-colors"
      >
        <BookOpenText className="h-4 w-4" />
        Docs
        <ExternalLink className="size-3 opacity-70" />
      </a>
    </nav>
  )
}
