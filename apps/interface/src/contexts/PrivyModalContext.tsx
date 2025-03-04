'use client'

import React, { createContext, useContext, useState } from 'react'

interface PrivyModalContextType {
  isOpen: boolean
  setOpen: (open: boolean) => void
}

const PrivyModalContext = createContext<PrivyModalContextType>({
  isOpen: false,
  setOpen: () => {},
})

export const usePrivyModal = () => useContext(PrivyModalContext)

export const PrivyModalProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isOpen, setIsOpen] = useState(false)

  const setOpen = (open: boolean) => {
    setIsOpen(open)
  }

  return (
    <PrivyModalContext.Provider value={{ isOpen, setOpen }}>
      {children}
    </PrivyModalContext.Provider>
  )
}