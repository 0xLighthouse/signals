'use client'

import { useEffect, useState } from 'react'

interface MaturityTimelineProps {
  issueDate: string
  maturityDate: string
}

export function MaturityTimeline({ issueDate, maturityDate }: MaturityTimelineProps) {
  const [progressPercent, setProgressPercent] = useState(0)
  const [daysLeft, setDaysLeft] = useState(0)

  useEffect(() => {
    const issue = new Date(issueDate).getTime()
    const maturity = new Date(maturityDate).getTime()
    const now = new Date().getTime()
    
    // Calculate total duration in days
    const totalDuration = (maturity - issue) / (1000 * 60 * 60 * 24)
    
    // Calculate days elapsed
    const elapsed = (now - issue) / (1000 * 60 * 60 * 24)
    
    // Calculate percentage of time elapsed
    const percent = Math.min(Math.max((elapsed / totalDuration) * 100, 0), 100)
    
    // Calculate days left until maturity
    const remaining = Math.max(Math.ceil((maturity - now) / (1000 * 60 * 60 * 24)), 0)
    
    setProgressPercent(percent)
    setDaysLeft(remaining)
  }, [issueDate, maturityDate])

  return (
    <div className="space-y-2">
      <div className="h-2 bg-neutral-200 dark:bg-neutral-700 rounded-full overflow-hidden">
        <div
          className="h-full bg-blue-500 rounded-full transition-all duration-500"
          style={{ width: `${progressPercent}%` }}
        />
      </div>
      <div className="flex justify-between text-xs text-neutral-500 dark:text-neutral-400">
        <div>Issue Date: {new Date(issueDate).toLocaleDateString()}</div>
        <div>{daysLeft} days left</div>
        <div>Maturity: {new Date(maturityDate).toLocaleDateString()}</div>
      </div>
    </div>
  )
}