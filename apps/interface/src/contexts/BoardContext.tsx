'use client'

import { createContext, useContext, useEffect, useState, useCallback, useMemo } from 'react'
import { getContract } from 'viem'

import { useNetwork } from '@/hooks/useNetwork'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from './Web3Provider'
import { useBoardsStore } from '@/stores/useBoardsStore'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useBondsStore } from '@/stores/useBondsStore'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { useRewardsStore } from '@/stores/useRewardsStore'
import { ZERO_ADDRESS, ERC20WithFaucetABI } from '@/config/web3'
import { SignalsABI } from '../../../../packages/abis'

type BoardSummary = {
  contractAddress: `0x${string}`
  owner?: `0x${string}`
}

interface BoardContextType {
  // Boards and selection
  boards: BoardSummary[]
  isBoardsLoading: boolean
  selectedBoard: `0x${string}` | null
  setActiveBoard: (boardAddress: `0x${string}`) => Promise<void>
  refreshBoards: () => Promise<void>
  // Underlying token (of the selected board)
  underlyingAddress: `0x${string}`
  underlyingName: string | null
  underlyingSymbol: string | null
  underlyingDecimals: number | null
  underlyingTotalSupply: number | null
  underlyingBalance: number | null
  fetchUnderlyingMetadata: () => Promise<void>
  formatter: (value?: number | null | undefined) => number
}

// Default values for the context
export const BoardContext = createContext<BoardContextType | undefined>(undefined)

// Hook for consuming the context
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

const resetStoresForChange = () => {
  useInitiativesStore.getState().reset()
  useBondsStore.getState().reset()
  usePoolsStore.getState().reset()
  useRewardsStore.getState().reset()
}

export const BoardProvider: React.FC<Props> = ({ children }) => {
  const { address: walletAddress } = useAccount()
  const { config } = useNetwork()
  const { publicClient } = useWeb3()

  // Underlying token metadata state
  const [underlyingName, setUnderlyingName] = useState<string | null>(null)
  const [underlyingSymbol, setUnderlyingSymbol] = useState<string | null>(null)
  const [underlyingDecimals, setUnderlyingDecimals] = useState<number | null>(null)
  const [underlyingTotalSupply, setUnderlyingTotalSupply] = useState<number>(0)
  const [underlyingBalance, setUnderlyingBalance] = useState<number>(0)

  // Boards state
  const { boards: boardsFromStore, isFetching: isBoardsLoading } = useBoardsStore()
  const [selectedBoard, setSelectedBoard] = useState<`0x${string}` | null>(
    config.contracts.SignalsProtocol?.address
      ? (config.contracts.SignalsProtocol.address.toLowerCase() as `0x${string}`)
      : null,
  )

  // Fetch underlying token metadata for UI (name, symbol, decimals, totalSupply, balance)
  const fetchUnderlyingMetadata = useCallback(async () => {
    const underlyingContract = useNetworkStore.getState().config.contracts.BoardUnderlyingToken
    if (
      !publicClient ||
      !underlyingContract?.address ||
      underlyingContract.address === ZERO_ADDRESS
    ) {
      setUnderlyingName(null)
      setUnderlyingSymbol(null)
      setUnderlyingDecimals(null)
      setUnderlyingTotalSupply(0)
      setUnderlyingBalance(0)
      return
    }

    try {
      const token = getContract({
        address: underlyingContract.address,
        abi: underlyingContract.abi,
        client: publicClient,
      })

      const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
        token.read.name(),
        token.read.symbol(),
        token.read.decimals(),
        token.read.totalSupply(),
        walletAddress ? token.read.balanceOf([walletAddress]) : 0n,
      ])

      setUnderlyingName(String(name))
      setUnderlyingSymbol(String(symbol))
      setUnderlyingDecimals(Number(decimals))
      setUnderlyingTotalSupply(Number(totalSupply ?? 0))
      setUnderlyingBalance(Number(balance ?? 0))
    } catch (error) {
      console.error('Error fetching underlying token metadata:', error)
    }
  }, [publicClient, walletAddress])

  // Update useNetworkStore config when switching boards and patch underlying token config
  const setActiveBoard = useCallback(
    async (boardAddress: `0x${string}`) => {
      if (!publicClient) return
      const nextBoard = (boardAddress.toLowerCase() as `0x${string}`) ?? null
      if (!nextBoard) return
      if (selectedBoard && nextBoard === selectedBoard) return

      try {
        // Resolve underlying token for the selected board
        const protocol = getContract({
          address: nextBoard,
          abi: SignalsABI,
          client: publicClient,
        })

        const underlyingToken = (await protocol.read.underlyingToken()) as `0x${string}`

        // Resolve token decimals for config convenience
        const token = getContract({
          address: underlyingToken,
          abi: ERC20WithFaucetABI,
          client: publicClient,
        })
        const decimals = Number(await token.read.decimals())

        // Update global network config with the selected board & underlying token
        useNetworkStore.setState((state) => ({
          config: {
            ...state.config,
            contracts: {
              ...state.config.contracts,
              SignalsProtocol: {
                address: nextBoard,
                abi: SignalsABI,
                label: 'Signals Protocol',
              },
              BoardUnderlyingToken: {
                address: (underlyingToken.toLowerCase() as `0x${string}`) ?? ZERO_ADDRESS,
                abi: ERC20WithFaucetABI,
                label: 'Signals Token',
                decimals,
              },
            },
          },
        }))

        // Persist local selected state and reset dependent stores
        setSelectedBoard(nextBoard)
        resetStoresForChange()

        // Refresh underlying metadata after config patch
        await fetchUnderlyingMetadata()
      } catch (error) {
        console.error('Failed to activate board:', error)
      }
    },
    [publicClient, selectedBoard, fetchUnderlyingMetadata],
  )

  // Refresh boards from store
  const refreshBoards = useCallback(async () => {
    await useBoardsStore.getState().fetchBoards()
    // Auto-select first board if no board is selected and boards are available
    const boards = useBoardsStore.getState().boards
    if (!selectedBoard && boards.length > 0) {
      const configured = config.contracts.SignalsProtocol?.address as `0x${string}` | undefined
      const next =
        (configured && (configured.toLowerCase() as `0x${string}`)) ||
        (boards.length > 0 ? boards[0]!.contractAddress : null)
      if (next) {
        await setActiveBoard(next)
      }
    }
  }, [config.contracts.SignalsProtocol?.address, selectedBoard, setActiveBoard])

  // Underlying token formatter utility
  const formatUnderlying = useCallback(
    (value?: number | null | undefined) => {
      const effectiveDecimals =
        underlyingDecimals ??
        useNetworkStore.getState().config.contracts.BoardUnderlyingToken?.decimals
      if (!effectiveDecimals || !value) return 0
      const exp = 10 ** effectiveDecimals
      return Math.ceil(value / exp)
    },
    [underlyingDecimals],
  )

  const underlyingAddress = useMemo(
    () =>
      (useNetworkStore.getState().config.contracts.BoardUnderlyingToken?.address ??
        ZERO_ADDRESS) as `0x${string}`,
    [config.contracts.BoardUnderlyingToken?.address],
  )

  // Initialize boards when provider mounts or network changes
  useEffect(() => {
    void refreshBoards()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [config.chain.id]) // Only on mount and network change

  // Refresh underlying token metadata on wallet or config changes
  useEffect(() => {
    void fetchUnderlyingMetadata()
  }, [fetchUnderlyingMetadata, walletAddress, selectedBoard])

  return (
    <BoardContext.Provider
      value={{
        boards: boardsFromStore,
        isBoardsLoading,
        selectedBoard,
        setActiveBoard,
        refreshBoards,
        underlyingAddress: underlyingAddress.toLowerCase() as `0x${string}`,
        underlyingName,
        underlyingSymbol,
        underlyingDecimals,
        underlyingTotalSupply,
        underlyingBalance,
        fetchUnderlyingMetadata,
        formatter: formatUnderlying,
      }}
    >
      {children}
    </BoardContext.Provider>
  )
}
