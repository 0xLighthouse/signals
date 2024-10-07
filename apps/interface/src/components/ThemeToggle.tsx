'use client'

import { Moon, Sun } from '@phosphor-icons/react'
import React, { useCallback, useEffect } from 'react'
import { IconButton } from './primitives/IconButton'
import { setThemeCookie } from '@/lib/nextjs/setThemeCookie'
import { UITheme } from '@/config/theme'

interface ThemeToggleProps {
  initialTheme: UITheme
}

/**
 * ThemeToggle component
 * Allows the user to toggle between dark and light themes, syncs with localStorage and the system theme.
 * Changing system preferences with the app open will take preference over the local storage theme.
 * TODO: Dropdown with Light/Dark/System opens for full user control
 */
export const ThemeToggle: React.FC<ThemeToggleProps> = ({ initialTheme }) => {
  const [isDark, setIsDark] = React.useState(initialTheme === 'dark')

  const handleToggle = useCallback(() => {
    if (isDark) {
      setThemeCookie('light')
      setIsDark(false)
    } else {
      setThemeCookie('dark')
      setIsDark(true)
    }
  }, [isDark])

  useEffect(() => {
    // Sync initial state with react state for icon display
    setIsDark(document.documentElement.classList.contains('dark'))

    // Setup event to watch the system theme
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    const handleChange = (event: MediaQueryListEvent) => {
      const newColorScheme = event.matches ? 'dark' : 'light'
      setIsDark(newColorScheme === 'dark')
      setThemeCookie(newColorScheme)
    }
    mediaQuery.addEventListener('change', handleChange)
    return () => mediaQuery.removeEventListener('change', handleChange)
  }, [])

  return (
    <div>
      <IconButton onClick={() => handleToggle()}>{isDark ? <Moon /> : <Sun />}</IconButton>
    </div>
  )
}
