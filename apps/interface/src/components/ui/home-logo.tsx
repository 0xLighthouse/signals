'use client'

import { UITheme } from '@/config/theme'
import React from 'react'

import Image from 'next/image'
import logoDark from '@/public/images/dark-logo.png'
import logoOrange from '@/public/images/orange-logo.png'
import { useTheme } from '@/contexts/ThemeContext'

export const HomeLogo: React.FC = (props) => {
  const { theme } = useTheme()
  return (
    <div className="flex">
      <Image
        src={theme === UITheme.LIGHT ? logoDark : logoOrange}
        alt="logo"
        width={100}
        height={25}
        className=""
      />
    </div>
  )
}
