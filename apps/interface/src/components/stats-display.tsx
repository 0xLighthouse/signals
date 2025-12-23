'use client'

import { useState } from 'react'
import { useAccount } from '@/hooks/useAccount'
import { UserLocksDialog } from '@/components/dialogs/user-locks-dialog'
import { cn } from '@/lib/utils'
import { ChevronRight, Lock } from 'lucide-react'

type StatItemProps = {
  label: string
  value: string | number
}

export const StatItem = ({ label, value }: StatItemProps) => {
  const { isConnected } = useAccount()
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const isTotalLocked = label.toLowerCase() === 'total locked'
  const isClickable = isTotalLocked && isConnected

  return (
    <>
      <div
        onClick={() => {
          if (isClickable) {
            setIsDialogOpen(true)
          }
        }}
        className={cn(
          'bg-neutral-100 dark:bg-neutral-800 p-4 rounded-lg relative',
          isClickable && 
            'cursor-pointer transition-all duration-200 hover:bg-neutral-200 dark:hover:bg-neutral-700 hover:shadow-sm hover:border-neutral-300 dark:hover:border-neutral-700 border border-transparent',
        )}
        role={isClickable ? 'button' : undefined}
        aria-label={isClickable ? 'View your redeemable locks' : undefined}
        tabIndex={isClickable ? 0 : undefined}
        onKeyDown={(e) => {
          if (isClickable && (e.key === 'Enter' || e.key === ' ')) {
            e.preventDefault()
            setIsDialogOpen(true)
          }
        }}
      >
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1">
            <div className="flex items-center gap-1.5">
              {isClickable && <Lock className="h-3.5 w-3.5 text-neutral-400 dark:text-neutral-500" />}
              <p className="text-sm text-neutral-500 dark:text-neutral-400">
                {isClickable ? 'Total locked (view yours)' : label}
              </p>
            </div>
            <p className="text-2xl font-bold mt-1">{value}</p>
            {isClickable && (
              <p className="text-xs text-neutral-400 dark:text-neutral-500 mt-1.5">
                Click to view redeemable locks
              </p>
            )}
          </div>
          {isClickable && (
            <ChevronRight className="h-4 w-4 text-neutral-400 dark:text-neutral-500 flex-shrink-0 mt-1" />
          )}
        </div>
      </div>
      {isTotalLocked && (
        <UserLocksDialog open={isDialogOpen} onOpenChange={setIsDialogOpen} />
      )}
    </>
  )
}

type StatsDisplayProps = {
  stats: StatItemProps[]
  className?: string
}

export const StatsDisplay = ({ stats, className = '' }: StatsDisplayProps) => {
  return (
    <div className={`grid grid-cols-1 md:grid-cols-3 gap-4 ${className}`}>
      {stats.map((stat, index) => (
        <StatItem key={`stat-${index}`} label={stat.label} value={stat.value} />
      ))}
    </div>
  )
}
