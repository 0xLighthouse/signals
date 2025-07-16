import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'
import { tv, type VariantProps } from 'tailwind-variants'
import { PuffLoader } from 'react-spinners'

import { useTheme } from '@/contexts/ThemeContext'
import { UITheme } from '@/config/theme'

const buttonVariants = tv(
  {
    base: 'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-white transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-neutral-950 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:bg-neutral-400 dark:disabled:bg-neutral-500 dark:ring-offset-neutral-950 dark:focus-visible:ring-neutral-300',
    variants: {
      variant: {
        default:
          'bg-neutral-900 text-neutral-50 hover:bg-neutral-900/90 dark:bg-neutral-50 dark:text-neutral-900 dark:hover:bg-neutral-50/90',
        destructive:
          'bg-red-500 text-neutral-50 hover:bg-red-500/90 dark:bg-red-900 dark:text-neutral-50 dark:hover:bg-red-900/90',
        outline:
          'border border-neutral-200 bg-white hover:bg-neutral-100 hover:text-neutral-900 dark:border-neutral-700 dark:bg-neutral-900 dark:hover:bg-neutral-700 dark:hover:text-neutral-50',
        secondary:
          'bg-neutral-100 text-neutral-900 hover:bg-neutral-100/80 dark:bg-neutral-700 dark:text-neutral-50 dark:hover:bg-neutral-700/80',
        ghost:
          'hover:bg-neutral-100 hover:text-neutral-900 dark:hover:bg-neutral-700 dark:hover:text-neutral-50',
        link: 'text-neutral-900 underline-offset-4 hover:underline dark:text-neutral-50',
        icon: 'rounded-full bg-neutral-900 text-neutral-50 hover:bg-neutral-900/90 dark:bg-neutral-50 dark:text-neutral-900 dark:hover:bg-neutral-50/90 p-2 flex items-center justify-center cursor-pointer',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        md: 'h-10 rounded-md px-6',
        lg: 'h-11 rounded-md px-8',
        // Clear default size for icon
        icon: '', //h-10 w-10
      },
      full: {
        true: 'h-full dark:h-full',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
  isLoading?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      className,
      variant,
      size,
      full,
      asChild = false,
      disabled = false,
      isLoading = false,
      ...props
    },
    ref,
  ) => {
    const { theme } = useTheme()
    const Comp = asChild ? Slot : 'button'
    return (
      <Comp
        className={buttonVariants({ variant, size, full, class: className })}
        ref={ref}
        disabled={disabled || isLoading}
        {...props}
      >
        {props.children}
        {isLoading && (
          <div className="ml-2">
            <PuffLoader
              color={theme === UITheme.DARK ? '#fff' : '#000'}
              size={22}
              speedMultiplier={2.6}
            />
          </div>
        )}
      </Comp>
    )
  },
)
Button.displayName = 'Button'

export { Button, buttonVariants }
