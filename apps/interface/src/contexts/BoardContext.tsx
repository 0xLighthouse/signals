'use client'

import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { getContract } from 'viem'

import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from './Web3Provider'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { ZERO_ADDRESS, ERC20WithFaucetABI } from '@/config/web3'
import { SignalsABI } from '../../../../packages/abis'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'

interface BoardContextType {
  boardAddress: `0x${string}` | null
  network: SupportedNetworks | null
  navigateToBoard: (boardAddress: `0x${string}`) => void
}

export const BoardContext = createContext<BoardContextType | undefined>(undefined)

export const useBoard = () => {
  const context = useContext(BoardContext)
  if (!context) {
    throw new Error('useBoard must be used within a BoardProvider')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const BoardProvider: React.FC<Props> = ({ children }) => {
  const { address: walletAddress } = useAccount()
  const { publicClient } = useWeb3()
  const router = useRouter()
  const params = useParams()

  // Extract board and network from URL params
  // Handle both array params (from Next.js 13+) and string params
  const networkSlug = Array.isArray(params?.network)
    ? params?.network[0]
    : (params?.network as string | undefined)
  const boardAddressParam = Array.isArray(params?.boardAddress)
    ? params?.boardAddress[0]
    : (params?.boardAddress as string | undefined)

  const network = networkSlug ? getNetworkFromSlug(networkSlug) : null
  const boardAddress = boardAddressParam ? (boardAddressParam as `0x${string}`) : null

  // Navigate to a different board
  const navigateToBoard = useCallback(
    (newBoardAddress: `0x${string}`) => {
      if (network) {
        router.push(getBoardUrl(network, newBoardAddress))
      }
    },
    [network, router],
  )

  return (
    <BoardContext.Provider
      value={{
        boardAddress,
        network,
        navigateToBoard,
      }}
    >
      {children}
    </BoardContext.Provider>
  )
}
