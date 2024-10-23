'use client'

import React, { useState } from 'react'
import Hamburger from 'hamburger-react'

export const HamburgerMenu: React.FC = () => {
  const [isOpen, setOpen] = useState(false)

  return <Hamburger size={16} toggled={isOpen} toggle={setOpen} />
}
