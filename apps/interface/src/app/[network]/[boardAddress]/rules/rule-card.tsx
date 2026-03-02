'use client'

import { Info } from 'lucide-react'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'

interface RuleCardProps {
  label: string
  value: React.ReactNode
  tooltip?: string
}

export function RuleCard({ label, value, tooltip }: RuleCardProps) {
  return (
    <div className="rounded-xl border border-stone-100 bg-white p-4 dark:border-stone-800 dark:bg-stone-900">
      <div className="flex items-center justify-between gap-2">
        <p className="text-xs uppercase tracking-wide text-stone-500 dark:text-stone-400">
          {label}
        </p>
        {tooltip ? (
          <Tooltip>
            <TooltipTrigger asChild>
              <Info className="h-4 w-4 text-stone-400" />
            </TooltipTrigger>
            <TooltipContent side="top" className="max-w-xs text-xs">
              {tooltip}
            </TooltipContent>
          </Tooltip>
        ) : null}
      </div>
      <p className="text-lg font-semibold text-stone-900 dark:text-white mt-1">{value}</p>
    </div>
  )
}
