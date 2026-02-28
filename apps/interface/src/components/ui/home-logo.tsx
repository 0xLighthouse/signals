'use client'

import { UITheme } from '@/config/theme'
import React from 'react'

import Image from 'next/image'
import logoDark from '@/public/images/logo-v3.png'
import logoOrange from '@/public/images/orange-logo.png'
import { useTheme } from '@/contexts/ThemeContext'

export const HomeLogo: React.FC = (props) => {
  const { theme } = useTheme()
  return (
    <div className="flex items-center">
      <Image
        src={theme === UITheme.LIGHT ? logoDark : logoOrange}
        alt="Lighthouse"
        width={100}
        height={25}
        className="transition-opacity duration-200 hover:opacity-80"
        style={{
          imageRendering: 'crisp-edges',
          filter: 'contrast(1.05)',
        }}
        priority
      />
    </div>
  )
}
