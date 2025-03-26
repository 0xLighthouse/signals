import * as React from 'react'
import { tv, type VariantProps } from 'tailwind-variants'

const alertVariants = tv(
  {
    base: 'relative w-full rounded-lg border p-4 [&>svg~*]:pl-7 [&>svg+div]:translate-y-[-3px] [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-1/2 [&>svg]:transform [&>svg]:-translate-y-1/2 [&>svg]:text-neutral-950 dark:border-neutral-800 dark:[&>svg]:text-neutral-50',
    variants: {
      variant: {
        default:
          'bg-blue-50 text-black border-blue-200 dark:bg-neutral-900 dark:text-neutral-50 dark:border-neutral-800', // Updated text color to black for light mode
        destructive:
          'border-red-500/50 text-red-500 dark:border-red-500 [&>svg]:text-red-500 dark:border-red-900/50 dark:text-red-900 dark:dark:border-red-900 dark:[&>svg]:text-red-900',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
)

const Alert = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & VariantProps<typeof alertVariants>
>(({ className, variant, ...props }, ref) => (
  <div ref={ref} role="alert" className={alertVariants({ variant, class: className })} {...props} />
))
Alert.displayName = 'Alert'

const AlertTitle = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h5
      ref={ref}
      className={tv({ base: 'mb-1 font-medium leading-none tracking-tight' })({ class: className })}
      {...props}
    />
  ),
)
AlertTitle.displayName = 'AlertTitle'

const AlertDescription = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={tv({ base: 'text-sm [&_p]:leading-relaxed' })({ class: className })}
    {...props}
  />
))
AlertDescription.displayName = 'AlertDescription'

export { Alert, AlertTitle, AlertDescription }
