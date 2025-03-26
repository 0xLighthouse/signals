export enum UITheme {
  DARK = 'dark',
  LIGHT = 'light',
}

/**
 * Typography system
 * 
 * This system provides consistent typography sizes and styles throughout the application.
 * Use these utilities with the `typography` function:
 * 
 * Example: typography('h1')
 */

export type TypographyVariant = 
  | 'h1' 
  | 'h2' 
  | 'h3' 
  | 'h4' 
  | 'body-lg' 
  | 'body' 
  | 'body-sm' 
  | 'caption' 
  | 'mono'
  | 'display'

export type TypographyWeights = 'normal' | 'medium' | 'semibold' | 'bold'

interface TypographyStyles {
  fontSize: string
  lineHeight: string
  fontWeight: string
  fontFamily?: string
  letterSpacing?: string
}

export const typographyDefinitions: Record<TypographyVariant, TypographyStyles> = {
  display: {
    fontSize: 'text-5xl md:text-6xl',
    lineHeight: 'leading-tight',
    fontWeight: 'font-bold',
    letterSpacing: 'tracking-tight',
  },
  h1: {
    fontSize: 'text-3xl md:text-4xl',
    lineHeight: 'leading-tight',
    fontWeight: 'font-bold',
    letterSpacing: 'tracking-tight',
  },
  h2: {
    fontSize: 'text-2xl md:text-3xl',
    lineHeight: 'leading-tight',
    fontWeight: 'font-semibold',
    letterSpacing: 'tracking-tight',
  },
  h3: {
    fontSize: 'text-xl md:text-2xl',
    lineHeight: 'leading-snug',
    fontWeight: 'font-semibold',
  },
  h4: {
    fontSize: 'text-lg md:text-xl',
    lineHeight: 'leading-snug',
    fontWeight: 'font-semibold',
  },
  'body-lg': {
    fontSize: 'text-lg',
    lineHeight: 'leading-normal',
    fontWeight: 'font-normal',
  },
  body: {
    fontSize: 'text-base',
    lineHeight: 'leading-normal',
    fontWeight: 'font-normal',
  },
  'body-sm': {
    fontSize: 'text-sm',
    lineHeight: 'leading-normal',
    fontWeight: 'font-normal',
  },
  caption: {
    fontSize: 'text-xs',
    lineHeight: 'leading-tight',
    fontWeight: 'font-normal',
  },
  mono: {
    fontSize: 'text-sm',
    lineHeight: 'leading-normal',
    fontWeight: 'font-normal',
    fontFamily: 'font-mono',
  },
}

export const fontWeights: Record<TypographyWeights, string> = {
  normal: 'font-normal',
  medium: 'font-medium',
  semibold: 'font-semibold',
  bold: 'font-bold',
}

/**
 * Helper function to get typography classes
 * 
 * @param variant The typography variant
 * @param weight Optional custom weight to override the default
 * @returns A string of Tailwind classes
 */
export function typography(
  variant: TypographyVariant, 
  weight?: TypographyWeights
): string {
  const definition = typographyDefinitions[variant]
  const classes = [
    definition.fontSize,
    definition.lineHeight,
    weight ? fontWeights[weight] : definition.fontWeight,
  ]
  
  if (definition.letterSpacing) {
    classes.push(definition.letterSpacing)
  }
  
  if (definition.fontFamily) {
    classes.push(definition.fontFamily)
  }
  
  return classes.join(' ')
}

/**
 * Color system
 * 
 * This system provides consistent colors throughout the application.
 */
export const colorSystem = {
  text: {
    primary: 'text-neutral-900 dark:text-neutral-50',
    secondary: 'text-neutral-700 dark:text-neutral-300',
    tertiary: 'text-neutral-500 dark:text-neutral-400',
    subtle: 'text-neutral-400 dark:text-neutral-500',
    brand: 'text-blue-500 dark:text-blue-400',
    danger: 'text-red-500 dark:text-red-400',
    success: 'text-green-500 dark:text-green-400',
    warning: 'text-yellow-500 dark:text-yellow-400',
  },
  bg: {
    primary: 'bg-white dark:bg-neutral-950',
    secondary: 'bg-neutral-100 dark:bg-neutral-900',
    tertiary: 'bg-neutral-200 dark:bg-neutral-800',
    brand: 'bg-blue-500 dark:bg-blue-600',
    danger: 'bg-red-500 dark:bg-red-600',
    success: 'bg-green-500 dark:bg-green-600',
    warning: 'bg-yellow-500 dark:bg-yellow-600',
  }
}