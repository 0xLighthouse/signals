import { ReactNode } from 'react'
import { Card } from '@/components/ui/card'

type PageSectionProps = {
  children: ReactNode
  title?: string
  className?: string
  action?: ReactNode
}

export const PageSection = ({ children, title, className = '', action }: PageSectionProps) => {
  return (
    <Card className={`p-6 mb-6 ${className}`}>
      {(title || action) && (
        <div className="flex justify-between items-center mb-4">
          {title && <h4 className="text-lg font-semibold">{title}</h4>}
          {action}
        </div>
      )}
      <div className="w-full">{children}</div>
    </Card>
  )
}
