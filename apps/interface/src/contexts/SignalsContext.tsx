'use client'

import { readClient, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { createContext, useContext, useEffect, useState } from 'react'
import { getContract } from 'viem'
import { useAccount } from 'wagmi'

// Types for contract metadata
type ProtocolContextType = {
  initiativesCount: number | null
  proposalThreshold: number | null
  acceptanceThreshold: number | null
}

// Default values for the context
export const ProtocolContext = createContext<ProtocolContextType | undefined>(undefined)

// Custom hook to use the contract context
export const useSignals = () => {
  const context = useContext(ProtocolContext)
  if (!context) {
    throw new Error('useSignals must be used within a ProtocolContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const ProtocolProvider: React.FC<Props> = ({ children }) => {
  const { address } = useAccount()

  const [initiativesCount, setInitiativesCount] = useState<number | null>(null)
  const [proposalThreshold, setProposalThreshold] = useState<number | null>(null)
  const [acceptanceThreshold, setAcceptanceThreshold] = useState<number | null>(null)

  useEffect(() => {
    const fetchContractMetadata = async () => {
      if (!address) return

      try {
        const protocol = getContract({
          address: SIGNALS_PROTOCOL,
          abi: SIGNALS_ABI,
          client: readClient,
        })

        // Fetch contract data in parallel using Promise.all
        const [proposalThreshold, acceptanceThreshold, count] = await Promise.all([
          protocol.read.proposalThreshold(),
          protocol.read.acceptanceThreshold(),
          protocol.read.count(),
        ])

        // Update state with fetched metadata
        setInitiativesCount(Number(count))
        setProposalThreshold(Number(proposalThreshold))
        setAcceptanceThreshold(Number(acceptanceThreshold))
      } catch (error) {
        console.error('Error fetching contract metadata:', error)
      }
    }

    // Fetch contract metadata when the address changes
    fetchContractMetadata()
  }, [address])

  // Provide contract data to children
  return (
    <ProtocolContext.Provider value={{ initiativesCount, proposalThreshold, acceptanceThreshold }}>
      {children}
    </ProtocolContext.Provider>
  )
}
