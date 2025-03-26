import React from 'react'
import { tv, VariantProps } from 'tailwind-variants'

const iconButton = tv(
  {
    base: 'flex items-center justify-center rounded-full p-2',
    variants: {
      clear: {
        true: 'bg-transparent',
        false:
          'bg-neutral-100 dark:bg-neutral-800 dark:text-white-0 hover:bg-orange-200 dark:hover:bg-orange-500',
      },
      size: {
        sm: 'p-2',
        md: 'p-3',
        lg: 'p-4',
      },
    },
    defaultVariants: {
      size: 'sm',
      color: 'primary',
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
