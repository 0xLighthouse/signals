'use client'

import {
  createContext,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { useParams, useRouter } from 'next/navigation'
import { getContract } from 'viem'

import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from './Web3Provider'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'
import { SignalsABI } from '../../../../packages/abis'
import { ZERO_ADDRESS, ERC20WithFaucetABI } from '@/config/web3'
import { NETWORKS } from '@/config/networks'
import { useNetworkStore } from '@/stores/useNetworkStore'

interface UnderlyingMetadata {
  address: `0x${string}` | null
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
}

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

export interface SignalsContextValue {
  network: SupportedNetworks | null
  boardAddress: `0x${string}` | null
  board: BoardMetadata
  underlyingAddress: `0x${string}` | null
  underlyingName: string | null
  underlyingSymbol: string | null
  underlyingDecimals: number | null
  underlyingTotalSupply: number | null
  underlyingBalance: number | null
  formatter: (value?: number | null | undefined) => number
  fetchBoardMetadata: () => Promise<void>
  fetchUnderlyingMetadata: () => Promise<void>
  navigateToBoard: (address: `0x${string}`) => void
}

const initialBoard: Omit<BoardMetadata, 'meetsThreshold'> = {
  name: null,
  symbol: null,
  initiativesCount: null,
  proposalThreshold: null,
  acceptanceThreshold: null,
  lockInterval: null,
  decayCurveType: null,
  decayCurveParameters: null,
}

const initialUnderlying: UnderlyingMetadata = {
  address: null,
  name: null,
  symbol: null,
  decimals: null,
  totalSupply: null,
  balance: null,
}

export const SignalsContext = createContext<SignalsContextValue | undefined>(undefined)

export const SignalsProvider = ({ children }: { children: ReactNode }) => {
  const params = useParams()
  const router = useRouter()
  const { publicClient } = useWeb3()
  const { address: walletAddress } = useAccount()

  const networkSlug = Array.isArray(params?.network)
    ? params?.network[0]
    : (params?.network as string | undefined)
  const boardAddressParam = Array.isArray(params?.boardAddress)
    ? params?.boardAddress[0]
    : (params?.boardAddress as string | undefined)

  const network = networkSlug ? getNetworkFromSlug(networkSlug) : null
  const boardAddress = boardAddressParam
    ? (boardAddressParam.toLowerCase() as `0x${string}`)
    : null

  const [boardState, setBoardState] = useState(initialBoard)
  const [underlying, setUnderlying] = useState<UnderlyingMetadata>(initialUnderlying)

  const formatter = useCallback(
    (value?: number | null | undefined) => {
      if (value == null || !underlying.decimals) return 0
      return Math.ceil(value / 10 ** underlying.decimals)
    },
    [underlying.decimals],
  )

  const fetchBoardMetadata = useCallback(async () => {
    if (!publicClient || !boardAddress) {
      setBoardState(initialBoard)
      return
    }

    try {
      const protocol = getContract({
        address: boardAddress,
        abi: SignalsABI,
        client: publicClient,
      })

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

      setBoardState({
        name: name ? String(name) : null,
        symbol: symbol ? String(symbol) : null,
        initiativesCount: initiativesCount != null ? Number(initiativesCount) : null,
        proposalThreshold: proposalThreshold ? Number(proposalThreshold) : null,
        acceptanceThreshold: acceptanceThreshold ? Number(acceptanceThreshold) : null,
        lockInterval: lockInterval != null ? Number(lockInterval) : null,
        decayCurveType: decayCurveType != null ? Number(decayCurveType) : null,
        decayCurveParameters:
          decayCurveParametersRaw != null
            ? Array.isArray(decayCurveParametersRaw)
              ? decayCurveParametersRaw.map((value: bigint | number | string) => Number(value))
              : [Number(decayCurveParametersRaw)]
            : null,
        meetsThreshold: false,
      })
    } catch (error) {
      console.error('Error fetching Signals board metadata:', error)
      setBoardState(initialBoard)
    }
  }, [publicClient, boardAddress])

  const fetchUnderlyingMetadata = useCallback(async () => {
    if (!publicClient || !boardAddress) {
      setUnderlying(initialUnderlying)
      return
    }

    try {
      const protocol = getContract({
        address: boardAddress,
        abi: SignalsABI,
        client: publicClient,
      })

      const underlyingAddress = (await protocol.read.underlyingToken()) as `0x${string}`
      if (!underlyingAddress) {
        setUnderlying(initialUnderlying)
        return
      }

      const token = getContract({
        address: underlyingAddress,
        abi: ERC20WithFaucetABI,
        client: publicClient,
      })

      const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
        token.read.name(),
        token.read.symbol(),
        token.read.decimals(),
        token.read.totalSupply(),
        walletAddress ? token.read.balanceOf([walletAddress]) : 0n,
      ])

      const decimalsNum = Number(decimals ?? 18)

      setUnderlying({
        address: underlyingAddress.toLowerCase() as `0x${string}`,
        name: name ? String(name) : null,
        symbol: symbol ? String(symbol) : null,
        decimals: decimalsNum,
        totalSupply: Number(totalSupply ?? 0n),
        balance: Number(balance ?? 0n),
      })

      if (network) {
        const baseConfig = NETWORKS[network]
        if (baseConfig) {
          useNetworkStore.setState({
            selected: network,
            config: {
              ...baseConfig,
              contracts: {
                ...baseConfig.contracts,
                SignalsProtocol: {
                  ...baseConfig.contracts.SignalsProtocol,
                  address: boardAddress,
                  abi: SignalsABI,
                  label: baseConfig.contracts.SignalsProtocol?.label ?? 'Signals Protocol',
                },
                BoardUnderlyingToken: {
                  address: underlyingAddress ?? ZERO_ADDRESS,
                  abi: baseConfig.contracts.BoardUnderlyingToken?.abi ?? ERC20WithFaucetABI,
                  label: baseConfig.contracts.BoardUnderlyingToken?.label ?? 'Signals Token',
                  decimals: decimalsNum,
                },
              },
            },
          })
        }
      }
    } catch (error) {
      console.error('Error fetching underlying token metadata:', error)
      setUnderlying(initialUnderlying)
    }
  }, [publicClient, boardAddress, walletAddress, network])

  useEffect(() => {
    void fetchBoardMetadata()
  }, [fetchBoardMetadata])

  useEffect(() => {
    void fetchUnderlyingMetadata()
  }, [fetchUnderlyingMetadata])

  const navigateToBoard = useCallback(
    (address: `0x${string}`) => {
      if (!network) return
      router.push(getBoardUrl(network, address))
    },
    [router, network],
  )

  const boardWithThreshold = useMemo<BoardMetadata>(() => {
    const meetsThreshold =
      boardState.proposalThreshold != null &&
      underlying.balance != null &&
      underlying.balance >= boardState.proposalThreshold
    return {
      ...boardState,
      meetsThreshold,
    }
  }, [boardState, underlying.balance])

  const contextValue = useMemo<SignalsContextValue>(
    () => ({
      network,
      boardAddress,
      board: boardWithThreshold,
      underlyingAddress: underlying.address,
      underlyingName: underlying.name,
      underlyingSymbol: underlying.symbol,
      underlyingDecimals: underlying.decimals,
      underlyingTotalSupply: underlying.totalSupply,
      underlyingBalance: underlying.balance,
      formatter,
      fetchBoardMetadata,
      fetchUnderlyingMetadata,
      navigateToBoard,
    }),
    [
      network,
      boardAddress,
      boardWithThreshold,
      underlying.address,
      underlying.name,
      underlying.symbol,
      underlying.decimals,
      underlying.totalSupply,
      underlying.balance,
      formatter,
      fetchBoardMetadata,
      fetchUnderlyingMetadata,
      navigateToBoard,
    ],
  )

  return <SignalsContext.Provider value={contextValue}>{children}</SignalsContext.Provider>
}
