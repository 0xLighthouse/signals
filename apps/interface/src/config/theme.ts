export enum UITheme {
  DARK = 'dark',
  LIGHT = 'light',
}

/**
 * Color system
 * 
 * This system provides consistent colors throughout the application.
 */
export const colorSystem = {
  text: {
    primary: 'text-stone-900 dark:text-stone-50',
    secondary: 'text-stone-700 dark:text-stone-300',
    tertiary: 'text-stone-500 dark:text-stone-400',
    subtle: 'text-stone-400 dark:text-stone-500',
    brand: 'text-indigo-600 dark:text-indigo-400',
    danger: 'text-red-500 dark:text-red-400',
    success: 'text-green-500 dark:text-green-400',
    warning: 'text-yellow-500 dark:text-yellow-400',
  },
  bg: {
    primary: 'bg-white dark:bg-stone-950',
    secondary: 'bg-stone-100 dark:bg-stone-900',
    tertiary: 'bg-stone-200 dark:bg-stone-800',
    brand: 'bg-indigo-600 dark:bg-indigo-500',
    danger: 'bg-red-500 dark:bg-red-600',
    success: 'bg-green-500 dark:bg-green-600',
    warning: 'bg-yellow-500 dark:bg-yellow-600',
  }
}