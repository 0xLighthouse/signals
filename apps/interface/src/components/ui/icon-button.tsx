import React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'

const iconButton = cva(
  'flex items-center justify-center rounded-full p-2',
  {
    variants: {
      clear: {
        true: 'bg-transparent',
        false:
          'bg-stone-100 dark:bg-stone-800 dark:text-white-0 hover:bg-orange-200 dark:hover:bg-orange-500',
      },
      size: {
        sm: 'p-2',
        md: 'p-3',
        lg: 'p-4',
      },
    },
    defaultVariants: {
      size: 'sm',
    },
  },
)

type IconButtonVariants = VariantProps<typeof iconButton>

interface IconButtonProps
  extends IconButtonVariants,
    React.ButtonHTMLAttributes<HTMLButtonElement> {}

export const IconButton: React.FC<IconButtonProps> = ({ children, clear, size, ...props }) => {
  return (
    <button
      className={iconButton({
        clear,
        size,
      })}
      {...props}
    >
      {children}
    </button>
  )
}
