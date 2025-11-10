'use client'

import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { getContract } from 'viem'

import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from './Web3Provider'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { useBoard } from './BoardContext'

export interface BoardMetadata {
  name: string | null
  symbol: string | null
  initiativesCount: number | null
  proposalThreshold: number | null
  acceptanceThreshold: number | null
  meetsThreshold: boolean
  lockInterval: number | null
  decayCurveType: number | null
  decayCurveParameters: number[] | null
}

type ISignalsContext = {
  board: BoardMetadata
  formatter: (value?: number | null | undefined) => number
  refresh: () => Promise<void>
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

export const SignalsProvider = ({ children }: Props): JSX.Element => {
  const { address: walletAddress } = useAccount()
  // Subscribe to only the specific config fields we need
  const signalsContractAddress = useNetworkStore(
    (state) => state.config.contracts.SignalsProtocol?.address,
  )
  const signalsContractAbi = useNetworkStore(
    (state) => state.config.contracts.SignalsProtocol?.abi,
  )
  const { publicClient } = useWeb3()
  const { formatter, boardAddress } = useBoard()

  // Board metadata state
  const [board, setBoard] = useState<BoardMetadata>({
    name: null,
    symbol: null,
    initiativesCount: null,
    proposalThreshold: null,
    acceptanceThreshold: null,
    meetsThreshold: false,
    lockInterval: null,
    decayCurveType: null,
    decayCurveParameters: null,
  })

  const fetchBoardMetadata = useCallback(async () => {
    if (!publicClient || !signalsContractAddress || !signalsContractAbi) {
      // If there is no configured board, reset to defaults
      setBoard({
        name: null,
        symbol: null,
        initiativesCount: null,
        proposalThreshold: null,
        acceptanceThreshold: null,
        meetsThreshold: false,
        lockInterval: null,
        decayCurveType: null,
        decayCurveParameters: null,
      })
      return
    }

    try {
      const protocol = getContract({
        address: signalsContractAddress,
        abi: signalsContractAbi,
        client: publicClient,
      })

      // Attempt to read thresholds with compatibility for older ABI variants.
      let proposalThreshold: bigint | null = null
      try {
        // @ts-ignore
        proposalThreshold = await protocol.read.proposalThreshold()
      } catch {
        try {
          // @ts-ignore
          proposalThreshold = await protocol.read.proposalCap()
        } catch {
          proposalThreshold = null
        }
      }

      let acceptanceThreshold: bigint | null = null
      try {
        // @ts-ignore
        acceptanceThreshold = await protocol.read.acceptanceThreshold()
      } catch {
        try {
          // @ts-ignore
          acceptanceThreshold = await protocol.read.getAcceptanceThreshold()
        } catch {
          acceptanceThreshold = null
        }
      }

      // Fetch remaining metadata (best-effort)
      const [
        initiativesCount,
        lockInterval,
        decayCurveType,
        decayCurveParametersRaw,
        name,
        symbol,
      ] = await Promise.all([
        // @ts-ignore
        protocol.read
          .initiativeCount?.()
          .catch(() => null),
        // @ts-ignore
        protocol.read
          .lockInterval?.()
          .catch(() => null),
        // @ts-ignore
        protocol.read
          .decayCurveType?.()
          .catch(() => null),
        // Some ABIs expect an index; use 0n as a safe default if required
        // @ts-ignore
        protocol.read
          .decayCurveParameters?.([0n])
          .catch(() => null),
        // @ts-ignore
        protocol.read
          .name?.()
          .catch(() => null),
        // @ts-ignore
        protocol.read
          .symbol?.()
          .catch(() => null),
      ])

      const pt = proposalThreshold ? Number(proposalThreshold) : null
      const at = acceptanceThreshold ? Number(acceptanceThreshold) : null

      // meetsThreshold uses raw units; formatter handles UI conversion
      const meetsThreshold = pt != null && pt > 0 && walletAddress != null

      setBoard({
        name: name ? String(name) : null,
        symbol: symbol ? String(symbol) : null,
        initiativesCount: initiativesCount != null ? Number(initiativesCount) : null,
        proposalThreshold: pt,
        acceptanceThreshold: at,
        meetsThreshold,
        lockInterval: lockInterval != null ? Number(lockInterval) : null,
        decayCurveType: decayCurveType != null ? Number(decayCurveType) : null,
        decayCurveParameters:
          decayCurveParametersRaw != null
            ? Array.isArray(decayCurveParametersRaw)
              ? decayCurveParametersRaw.map((x: bigint | number | string) => Number(x))
              : [Number(decayCurveParametersRaw)]
            : null,
      })
    } catch (error) {
      console.error('Error fetching Signals board metadata:', error)
      // Keep existing state to avoid UI flicker on transient errors
    }
  }, [publicClient, signalsContractAddress, signalsContractAbi, walletAddress])

  // Refresh board metadata when board address changes
  useEffect(() => {
    void fetchBoardMetadata()
  }, [fetchBoardMetadata, boardAddress])

  return (
    <SignalsContext.Provider
      value={{
        board,
        formatter,
        refresh: fetchBoardMetadata,
      }}
    >
      {children}
    </SignalsContext.Provider>
  )
}
