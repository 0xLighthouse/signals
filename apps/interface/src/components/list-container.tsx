'use client'

import { ReactNode } from 'react'
import { ScrollArea } from '@/components/ui/scroll-area'

type ListContainerProps = {
  children: ReactNode
  title?: string
  count?: number
  className?: string
}

export const ListContainer = ({ 
  children, 
  title, 
  count, 
  className = ''
}: ListContainerProps) => {
  return (
    <div className={className}>
      {title && (
        <h1 className="text-2xl font-bold mb-4">
          {title} {count !== undefined && `(${count})`}
        </h1>
      )}
      <ScrollArea className="w-full mb-24">
        <div>{children}</div>
      </ScrollArea>
    </div>
  )
}