import { useContext } from 'react'

import { SignalsContext } from '@/contexts/SignalsContext'

export const useSignals = () => {
  const context = useContext(SignalsContext)
  if (!context) {
    throw new Error('useSignals must be used within a SignalsProvider')
  }
  return context
}
