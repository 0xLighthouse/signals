'use client'

import { formatDistanceToNow } from 'date-fns'
import { DateTime } from 'luxon'
import { useEffect, useState } from 'react'

interface MaturityTimelineProps {
  issueDate: DateTime
  maturityDate: DateTime
}

export function MaturityTimeline({ issueDate, maturityDate }: MaturityTimelineProps) {
  const [progressPercent, setProgressPercent] = useState(0)
  const [daysLeft, setDaysLeft] = useState(0)
  const [remainingTime, setRemainingTime] = useState('')

  useEffect(() => {
    const issue = issueDate.toMillis()
    const maturity = maturityDate.toMillis()
    const now = DateTime.now().toMillis()

    const _maturityDate = maturityDate.toJSDate()
    const remainingTime = formatDistanceToNow(_maturityDate, { addSuffix: true })

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
    setRemainingTime(remainingTime)
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
        <div>{issueDate.toLocaleString()}</div>
        <div>Redeem {remainingTime}</div>
        <div>Locked until: {maturityDate.toLocaleString()}</div>
      </div>
    </div>
  )
}
