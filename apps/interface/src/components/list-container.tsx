import { ReactNode } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

type ListContainerProps = {
  children: ReactNode
  title?: string | null
  count?: number
  className?: string
  action?: ReactNode
}

export const ListContainer = ({ children, title, count, className = '', action }: ListContainerProps) => {
  return (
    <div className={className}>
      {title && (
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-h2">
            {title} {count !== undefined && `(${count})`}
          </h1>
          {action && <div>{action}</div>}
        </div>
      )}
      <ScrollArea className="w-full mb-24">
        <div>{children}</div>
      </ScrollArea>
    </div>
  )
}
