import * as React from 'react'
import { cn } from '@/lib/utils'

const SwitchContainer = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        'flex items-center py-4 my-2 gap-4 border border-neutral-200 bg-white rounded-md px-3 dark:border-neutral-800 dark:bg-neutral-800',
        className,
      )}
      {...props}
    />
  ),
)
SwitchContainer.displayName = 'SwitchContainer'

export { SwitchContainer }
