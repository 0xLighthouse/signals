'use client'

import { readClient, SIGNALS_ABI, SIGNALS_PROTOCOL } from '@/config/web3'
import { createContext, useContext, useEffect, useState } from 'react'
import { getContract } from 'viem'
import { useUnderlying } from './ContractContext'
import { useAccount } from '@/hooks/useAccount'

interface IBoard {
  // TODO: Move this out of IBoard as its metadata
  initiativesCount: number | null
  proposalThreshold: number | null
  // TODO: Move this out of IBoard as its related to the users balance
  meetsThreshold: boolean
  acceptanceThreshold: number | null
  lockInterval: number | null
  decayCurveType: number | null
  decayCurveParameters: number[] | null
}

// TODO: Surface underlying token metadata
interface IUnderlyingToken {
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
}

// TODO: Surface incentives metadata, related to the board
interface IIncentives {
  address: string
  version: number | null
  allocations: bigint[] | null
  receivers: `0x${string}`[] | null
}

// Types for contract metadata
type ISignalsContext = {
  board: IBoard
  underlyingToken?: IUnderlyingToken
  incentives?: IIncentives
  formatter: (value?: number | null) => number
}

// Default values for the context
export const SignalsContext = createContext<ISignalsContext | undefined>(undefined)

// Custom hook to use the contract context
export const useSignals = () => {
  const context = useContext(SignalsContext)
  if (!context) {
    throw new Error('useSignals must be used within a SignalsContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const SignalsProvider: React.FC<Props> = ({ children }) => {
  const { address } = useAccount()
  const { decimals, balance } = useUnderlying()

  const [initiativesCount, setInitiativesCount] = useState<number | null>(null)
  const [proposalThreshold, setProposalThreshold] = useState<number | null>(null)
  const [acceptanceThreshold, setAcceptanceThreshold] = useState<number | null>(null)
  const [lockInterval, setLockInterval] = useState<number | null>(null)
  const [decayCurveType, setDecayCurveType] = useState<number | null>(null)
  const [decayCurveParameters, setDecayCurveParameters] = useState<number[] | null>(null)
  const meetsThreshold = Boolean(balance && proposalThreshold && balance >= proposalThreshold)

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
        const [
          proposalThreshold,
          acceptanceThreshold,
          count,
          lockInterval,
          decayCurveType,
          decayCurveParameters,
        ] = await Promise.all([
          protocol.read.proposalThreshold(),
          protocol.read.acceptanceThreshold(),
          protocol.read.initiativeCount(),
          protocol.read.lockInterval(),
          protocol.read.decayCurveType(),
          protocol.read.decayCurveParameters([0n]),
        ])

        console.log('----- SIGNALS CONTEXT -----')
        console.log('proposalThreshold', proposalThreshold)
        console.log('acceptanceThreshold', acceptanceThreshold)
        console.log('count', count)
        console.log('lockInterval', lockInterval)
        console.log('decayCurveType', decayCurveType)
        console.log('decayCurveParameters', [decayCurveParameters])

        // Update state with fetched metadata
        setInitiativesCount(Number(count))
        setProposalThreshold(Number(proposalThreshold))
        setAcceptanceThreshold(Number(acceptanceThreshold))
        setLockInterval(Number(lockInterval))
        setDecayCurveType(Number(decayCurveType))
        // TODO: Fix this
        // TODO: Fix this
        // TODO: Fix this
        setDecayCurveParameters([Number(decayCurveParameters) / 1e18])
      } catch (error) {
        console.error('Error fetching contract metadata:', error)
      }
    }

    // Fetch contract metadata when the address changes
    fetchContractMetadata()
  }, [address])

  // Underlying token

  const formatter = (value?: number | null) => {
    if (!decimals || !value) return value
    return Math.ceil(value / 1e18)
  }

  // Provide contract data to children
  return (
    <SignalsContext.Provider
      value={{
        formatter: formatter as (value?: number | null) => number,
        board: {
          initiativesCount,
          proposalThreshold,
          acceptanceThreshold,
          meetsThreshold,
          lockInterval,
          decayCurveType,
          decayCurveParameters,
        },
      }}
    >
      {children}
    </SignalsContext.Provider>
  )
}
