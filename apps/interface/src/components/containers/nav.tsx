'use client'

import { cn } from '@/lib/utils'
import type { LucideIcon } from 'lucide-react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

interface NavItem {
  href: string
  label: string
  icon?: LucideIcon
}

interface Props {
  items: NavItem[]
  className?: string
}

export function NavList({ items, className }: Props) {
  const pathname = usePathname()

  return (
    <div
      className={cn(
        'inline-flex h-10 items-center justify-center rounded-md bg-muted p-1 text-muted-foreground',
        className,
      )}
    >
      <nav className={cn('flex w-full')}>
        {items.map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium ring-offset-background transition-all focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
                isActive
                  ? 'bg-background text-foreground shadow-sm'
                  : 'hover:bg-background/50 hover:text-foreground',
              )}
            >
              {item.icon && <item.icon className="mr-2 h-4 w-4" />}
              {item.label}
            </Link>
          )
        })}
      </nav>
    </div>
  )
}
