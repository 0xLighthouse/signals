import { ReactNode } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

type ListContainerProps = {
  children: ReactNode
  title?: string | null
  count?: number
  className?: string
  action?: ReactNode
  leftAction?: ReactNode
  rightAction?: ReactNode
}

export const ListContainer = ({ children, title, count, className = '', action, leftAction, rightAction }: ListContainerProps) => {
  // Support both old action prop (for backward compatibility) and new leftAction/rightAction props
  const hasActions = action || leftAction || rightAction
  
  return (
    <div className={className}>
      {(title || hasActions) && (
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-4">
            {title && (
              <h1 className="text-2xl font-semibold">
                {title} {count !== undefined && `(${count})`}
              </h1>
            )}
            {leftAction && <div>{leftAction}</div>}
          </div>
          {(action || rightAction) && <div>{action || rightAction}</div>}
        </div>
      )}
      <ScrollArea className="w-full mb-24">
        <div>{children}</div>
      </ScrollArea>
    </div>
  )
}
