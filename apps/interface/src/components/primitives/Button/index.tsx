import React from 'react'
import { tv, VariantProps } from 'tailwind-variants'

const button = tv(
  {
    base: 'font-semibold text-white py-3 px-3 rounded-full active:opacity-80',
    variants: {
      color: {
        primary: 'bg-blue-500 hover:bg-blue-700',
        secondary: 'bg-purple-500 hover:bg-purple-700',
        success: 'bg-green-500 hover:bg-green-700',
        error: 'bg-red-500 hover:bg-red-700',
      },
      disabled: {
        true: 'opacity-50 bg-gray-500 pointer-events-none',
      },
      size: {
        sm: 'text-sm',
        md: 'text-base px-4 py-4',
        lg: 'text-lg px-6 py-6',
      },
    },
    compoundVariants: [
      {
        color: ['primary'],
        disabled: true,
        class: 'bg-blue-100 text-blue-900',
      },
    ],
    defaultVariants: {
      size: 'sm',
      color: 'primary',
    },
  },
  {
    // TODO: where is this configured? Why is 'xs' not available on the types like in the docs?
    responsiveVariants: ['sm', 'md', 'lg'],
  },
)

type ButtonVariants = VariantProps<typeof button>

interface ButtonProps
  extends ButtonVariants,
    Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'color' | 'disabled'> {
  children: React.ReactNode
}
export const Button: React.FC<ButtonProps> = ({
  children,
  size = {
    md: 'md',
    lg: 'lg',
  },
  disabled,
  color,
  ...props
}) => {
  return (
    <button
      type="button"
      className={button({
        size,
        color,
        disabled,
      })}
      {...props}
    >
      {children}
    </button>
  )
}
