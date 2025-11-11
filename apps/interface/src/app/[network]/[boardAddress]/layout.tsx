import { ReactNode } from 'react'
import { CreateInitiativeDrawer } from '@/components/drawers/create-initiative-drawer'

export default function BoardLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <CreateInitiativeDrawer />
      {children}
    </>
  )
}
