import React from 'react'

interface CardGridProps {
  children: React.ReactNode
}

export function CardGrid({ children }: CardGridProps) {
  return (
    <div className="card-grid">
      {children}
      
    </div>
  )
}