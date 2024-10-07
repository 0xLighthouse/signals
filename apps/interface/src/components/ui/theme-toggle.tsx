'use client'

import { Moon, Sun } from '@phosphor-icons/react'
import React, { useCallback, useEffect } from 'react'
import { IconButton } from './icon-button'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'
import { cn } from '@/lib/utils'

/**
 * ThemeToggle component
 * Allows the user to toggle between dark and light themes, syncs with localStorage and the system theme.
 * Changing system preferences with the app open will take preference over the local storage theme.
 * TODO: Dropdown with Light/Dark/System opens for full user control
 */
export const ThemeToggle: React.FC<{ className?: string }> = ({ className }) => {
  const { theme, setTheme } = useTheme()

  const isDark = theme === UITheme.DARK

  const handleToggle = useCallback(() => {
    if (isDark) {
      setTheme(UITheme.LIGHT)
    } else {
      setTheme(UITheme.DARK)
    }
  }, [isDark, setTheme])

  useEffect(() => {
    // Setup event to watch the system theme
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    const handleChange = (event: MediaQueryListEvent) => {
      const newColorScheme = event.matches ? UITheme.DARK : UITheme.LIGHT
      setTheme(newColorScheme)
    }
    mediaQuery.addEventListener('change', handleChange)
    return () => mediaQuery.removeEventListener('change', handleChange)
  }, [setTheme])

  return (
    <div className={cn('flex items-center justify-center', className)}>
      <IconButton onClick={() => handleToggle()}>{isDark ? <Moon /> : <Sun />}</IconButton>
    </div>
  )
}
