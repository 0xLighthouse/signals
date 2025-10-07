import React from 'react'
import { ArrowRight } from 'lucide-react'

interface CardProps {
  title: string
  description: string
  icon?: React.ReactNode
  tokenIcon?: string
  href?: string
  moreText?: string
}

export function Card({ 
  title, 
  description, 
  icon, 
  tokenIcon, 
  href = '#', 
  moreText = 'More' 
}: CardProps) {
  return (
    <div className="card">
      <div className="card-header">
        <h3 className="card-title">{title}</h3>
        <div className="card-icon">
          {tokenIcon ? (
            <img 
              src={`https://tokenicons.io/api/icon/${tokenIcon}`} 
              alt={title}
              width={24}
              height={24}
            />
          ) : (
            icon
          )}
        </div>
      </div>
      
      <p className="card-description">{description}</p>
      
      <a href={href} className="card-link">
        {moreText} <ArrowRight size={16} />
      </a>
      
    </div>
  )
}