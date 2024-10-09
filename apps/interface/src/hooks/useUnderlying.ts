import { ContractContext } from '@/contexts/ContractContext'
import { useContext } from 'react'

// Custom hook to use the contract context
export const useUnderlying = () => {
  const context = useContext(ContractContext)
  if (!context) {
    throw new Error('useUnderlying must be used within a ContractContext')
  }
  return context
}
