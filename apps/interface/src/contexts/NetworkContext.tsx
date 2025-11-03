'use client'

import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { getContract } from 'viem'

import { useAccount } from '@/hooks/useAccount'
import { useNetwork } from '@/hooks/useNetwork'
import { useWeb3 } from './Web3Provider'
import { ZERO_ADDRESS, ERC20WithFaucetABI } from '@/config/web3'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { SignalsABI, SignalsFactoryABI } from '../../../../packages/abis'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useBondsStore } from '@/stores/useBondsStore'
import { useRewardsStore } from '@/stores/useRewardsStore'

type BoardSummary = {
  contractAddress: `0x${string}`
  owner?: `0x${string}`
}

interface NetworkContextType {
  // Underlying token (of the selected board)
  address: `0x${string}`
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
  formatter: (value?: number | null | undefined) => number
  fetchContractMetadata: () => Promise<void>

  // Boards and selection
  boards: BoardSummary[]
  isBoardsLoading: boolean
  selectedBoard: `0x${string}` | null
  setActiveBoard: (boardAddress: `0x${string}`) => Promise<void>
  refreshBoards: () => Promise<void>
}

// Default values for the context
export const NetworkContext = createContext<NetworkContextType | undefined>(undefined)

// Hook for consuming the context
export const useUnderlying = () => {
  const context = useContext(NetworkContext)
  if (!context) {
    throw new Error('useUnderlying must be used within a NetworkContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

const resetStoresForChange = () => {
  useInitiativesStore.getState().reset()
  useBondsStore.getState().reset()
  useRewardsStore.getState().reset()
}

export const NetworkProvider: React.FC<Props> = ({ children }) => {
  const { address: walletAddress } = useAccount()
  const { publicClient } = useWeb3()
  const { config } = useNetwork()

  // Underlying token metadata
  const [underlyingName, setUnderlyingName] = useState<string | null>(null)
  const [underlyingSymbol, setUnderlyingSymbol] = useState<string | null>(null)
  const [underlyingDecimals, setUnderlyingDecimals] = useState<number | null>(null)
  const [underlyingTotalSupply, setUnderlyingTotalSupply] = useState<number>(0)
  const [underlyingBalance, setUnderlyingBalance] = useState<number>(0)

  // Boards state
  const [boards, setBoards] = useState<BoardSummary[]>([])
  const [isBoardsLoading, setIsBoardsLoading] = useState(false)
  const [selectedBoard, setSelectedBoard] = useState<`0x${string}` | null>(
    config.contracts.SignalsProtocol?.address
      ? (config.contracts.SignalsProtocol.address.toLowerCase() as `0x${string}`)
      : null,
  )

  const factoryAddress = config.contracts.SignalsFactory.address

  // Fetch boards for the active network by scanning factory events
  const refreshBoards = useCallback(async () => {
    if (!publicClient || !factoryAddress || factoryAddress === ZERO_ADDRESS) {
      setBoards([])
      return
    }

    setIsBoardsLoading(true)
    try {
      const factory = getContract({
        address: factoryAddress,
        abi: SignalsFactoryABI,
        client: publicClient,
      })
      // Fetch past BoardCreated events
      const events = await factory.getEvents.BoardCreated({
        fromBlock: 0n,
        toBlock: 'latest',
      })

      // Normalise and deduplicate boards
      const uniq = new Map<string, BoardSummary>()
      for (const ev of events) {
        const board = (ev.args.board as `0x${string}`).toLowerCase() as `0x${string}`
        const owner = (ev.args.owner as `0x${string}`).toLowerCase() as `0x${string}`
        if (!uniq.has(board)) {
          uniq.set(board, { contractAddress: board, owner })
        }
      }
      const list = Array.from(uniq.values())
      setBoards(list)

      // If we don't yet have a selected board, try to use config or first discovered
      if (!selectedBoard) {
        const configured = config.contracts.SignalsProtocol?.address as `0x${string}` | undefined
        const next =
          (configured && (configured.toLowerCase() as `0x${string}`)) ||
          (list.length > 0 ? list[0]!.contractAddress : null)
        if (next) {
          await setActiveBoard(next)
        }
      }
    } catch (err) {
      console.error('Error fetching boards from factory:', err)
      setBoards([])
    } finally {
      setIsBoardsLoading(false)
    }
  }, [publicClient, factoryAddress, selectedBoard, config.contracts.SignalsProtocol?.address])

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
        await fetchContractMetadata()
      } catch (error) {
        console.error('Failed to activate board:', error)
      }
    },
    [publicClient, selectedBoard],
  )

  // Fetch underlying token metadata for UI (name, symbol, decimals, totalSupply, balance)
  const fetchContractMetadata = useCallback(async () => {
    const underlyingContract = useNetworkStore.getState().config.contracts.BoardUnderlyingToken
    if (!publicClient || !underlyingContract) return

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

  // Keep boards list up-to-date on network/factory changes
  useEffect(() => {
    void refreshBoards()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [factoryAddress, publicClient])

  // Refresh underlying token metadata on wallet or config changes
  useEffect(() => {
    void fetchContractMetadata()
  }, [fetchContractMetadata, walletAddress, selectedBoard])

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

  return (
    <NetworkContext.Provider
      value={{
        address: underlyingAddress.toLowerCase() as `0x${string}`,
        name: underlyingName,
        symbol: underlyingSymbol,
        decimals: underlyingDecimals,
        totalSupply: underlyingTotalSupply,
        balance: underlyingBalance,
        formatter: (value) => formatUnderlying(value),
        fetchContractMetadata,
        boards,
        isBoardsLoading,
        selectedBoard,
        setActiveBoard,
        refreshBoards,
      }}
    >
      {children}
    </NetworkContext.Provider>
  )
}
