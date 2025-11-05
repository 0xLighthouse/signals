'use client'

import { features } from '@/config/features'
import { useAccount } from '@/hooks/useAccount'
import { createContext, useContext, useEffect, useState } from 'react'
import { getContract } from 'viem'

import { useNetworkStore } from '@/stores/useNetworkStore'
import { useWeb3 } from './Web3Provider'

interface ContextValues {
  address: string
  version: number | null
  allocations: bigint[] | null
  receivers: `0x${string}`[] | null
}

interface Props {
  children: React.ReactNode
}

//Provider
export const IncentivesProvider: React.FC<Props> = ({ children }) => {
  const { publicClient } = useWeb3()
  // Subscribe to only the specific config fields we need
  const incentivesAddress = useNetworkStore(
    (state) => state.config.contracts.Incentives?.address,
  )
  const incentivesAbi = useNetworkStore((state) => state.config.contracts.Incentives?.abi)

  if (!features.enableContributions || !incentivesAddress || !incentivesAbi) {
    return <>{children}</>
  }

  const { address } = useAccount()

  const [version, setVersion] = useState<number | null>(null)
  const [allocations, setAllocations] = useState<bigint[] | null>(null)
  const [receivers, setReceivers] = useState<`0x${string}`[] | null>(null)

  useEffect(() => {
    const fetchMetadata = async () => {
      if (!address || !publicClient) return

      try {
        const incentives = getContract({
          address: incentivesAddress,
          abi: incentivesAbi,
          client: publicClient,
        })

        const version = await incentives.read.version()
        // @ts-ignore
        const [_, allocations, receivers] = await incentives.read.config([version])

        setVersion(Number(version))
        setAllocations([...allocations])
        setReceivers([...receivers])
      } catch (error) {
        console.error('Error fetching contract metadata:', error)
      }
    }

    // Fetch contract metadata when the address changes
    fetchMetadata()
  }, [address, incentivesAddress, incentivesAbi, publicClient])

  // Provide contract data to children
  return (
    <IncentivesContext.Provider
      value={{
        address: incentivesAddress,
        version,
        allocations,
        receivers,
      }}
    >
      {children}
    </IncentivesContext.Provider>
  )
}

// Context
export const IncentivesContext = createContext<ContextValues | undefined>(undefined)

// Hook
export const useIncentives = () => {
  const context = useContext(IncentivesContext)
  if (!context) {
    throw new Error('useIncentives must be used within a IncentivesContext')
  }
  return context
}
