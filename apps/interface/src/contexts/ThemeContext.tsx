'use client'

import { UITheme } from '@/config/theme'
import { setThemeCookie } from '@/lib/nextjs/setThemeCookie'
import { createContext, useContext, useState, type ReactNode, type FC, useCallback } from 'react'

interface ThemeContextType {
  theme: UITheme
  setTheme: (theme: UITheme) => void
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export const ThemeProvider: FC<{ children: ReactNode; initialTheme: UITheme }> = ({
  children,
  initialTheme,
}) => {
  const [theme, _setTheme] = useState(initialTheme)

  const setTheme = useCallback((theme: UITheme) => {
    setThemeCookie(theme)
    _setTheme(theme)
  }, [])

  return <ThemeContext.Provider value={{ theme, setTheme }}>{children}</ThemeContext.Provider>
}

export const useTheme = (): ThemeContextType => {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider')
  }
  return context
}
