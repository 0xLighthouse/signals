import React from 'react'
import { cn } from '@/lib/utils'
import { TypographyVariant, TypographyWeights, typography as typographyFn } from '@/config/theme'

interface TypographyProps {
  variant: TypographyVariant
  weight?: TypographyWeights
  children: React.ReactNode
  as?: React.ElementType
  className?: string
}

export const Typography = ({
  variant,
  weight,
  children,
  as: Component = getDefaultElement(variant),
  className,
  ...props
}: TypographyProps & React.HTMLAttributes<HTMLElement>) => {
  return (
    <Component
      className={cn(typographyFn(variant, weight), className)}
      {...props}
    >
      {children}
    </Component>
  )
}

// Helper function to determine default HTML element based on typography variant
function getDefaultElement(variant: TypographyVariant): React.ElementType {
  switch (variant) {
    case 'display':
      return 'h1'
    case 'h1':
      return 'h1'
    case 'h2':
      return 'h2'
    case 'h3':
      return 'h3'
    case 'h4':
      return 'h4'
    case 'body-lg':
    case 'body':
    case 'body-sm':
      return 'p'
    case 'caption':
      return 'span'
    case 'mono':
      return 'code'
    default:
      return 'span'
  }
}