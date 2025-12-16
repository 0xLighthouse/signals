'use client'

import { createContext, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useParams, useRouter } from 'next/navigation'

import { useWeb3 } from './WalletProvider'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { useRouteStore } from '@/stores/useRouteStore'

type BoardRequirement = {
  minBalance: string
  minHoldingDuration: string
  minLockAmount: string
}

type BoardByAddressQueryItem = {
  chainId: number | string
  blockTimestamp: string | number
  transactionHash: string
  contractAddress: string
  owner: string
  title: string
  body: string
  opensAt: string | number
  closesAt: string | number
  proposerRequirements: BoardRequirement
  participantRequirements: BoardRequirement
  acceptanceThreshold: string | number
  underlyingToken: string
  underlyingTokenSymbol: string
  underlyingTokenDecimals: number
  underlyingTokenName: string
  lockInterval: string | number
  maxLockIntervals: string | number
  decayCurveType: string | number
  decayCurveParameters: Array<string | number>
}

type BoardByAddressQueryResponse = {
  data?: {
    boards?: {
      items?: BoardByAddressQueryItem[]
    }
  }
}

export interface IndexedBoardMetadata {
  chainId: number | null
  blockTimestamp: number | null
  transactionHash: string | null
  contractAddress: `0x${string}` | null
  owner: `0x${string}` | null
  name: string | null
  body: string | null
  opensAt: number | null
  closesAt: number | null
  symbol: string | null
  initiativesCount: number | null
  proposalThreshold: number | null
  acceptanceThreshold: number | null
  lockInterval: number | null
  maxLockIntervals: number | null
  decayCurveType: number | null
  decayCurveParameters: number[] | null
  proposerRequirements: BoardRequirement | null
  participantRequirements: BoardRequirement | null
  underlyingToken: `0x${string}` | undefined
  underlyingTokenSymbol: string | null
  underlyingTokenDecimals: number | null
  underlyingTokenName: string | null
}

export interface SignalsContextValue {
  network: SupportedNetworks | null
  boardAddress: `0x${string}` | null
  board: IndexedBoardMetadata
  underlyingAddress: `0x${string}` | undefined
  underlyingName: string | null
  underlyingSymbol: string | null
  underlyingDecimals: number | null
  underlyingTotalSupply: number | null
  underlyingBalance: number | null
  formatter: (value?: number | null | undefined) => number
  fetchBoardMetadata: () => Promise<void>
  meetsProposalThreshold: (balance: number) => boolean
  navigateToBoard: (address: `0x${string}`) => void
}

const initialBoard: IndexedBoardMetadata = {
  chainId: null,
  blockTimestamp: null,
  transactionHash: null,
  contractAddress: null,
  owner: null,
  name: null,
  body: null,
  opensAt: null,
  closesAt: null,
  symbol: null,
  initiativesCount: null,
  proposalThreshold: null,
  acceptanceThreshold: null,
  lockInterval: null,
  maxLockIntervals: null,
  decayCurveType: null,
  decayCurveParameters: null,
  proposerRequirements: null,
  participantRequirements: null,
  underlyingToken: undefined,
  underlyingTokenSymbol: null,
  underlyingTokenDecimals: null,
  underlyingTokenName: null,
}

interface BoardBalances {
  // Wallet balance of the underlying token
  walletBalance: number | null
  // Total supply of the underlying token
  totalSupply: number | null
}

export const SignalsContext = createContext<SignalsContextValue | undefined>(undefined)

export const SignalsProvider = ({ children }: { children: ReactNode }) => {
  const params = useParams()
  const router = useRouter()
  const { isInitialized } = useWeb3()

  const [balances, setBalances] = useState<BoardBalances>({
    walletBalance: null,
    totalSupply: null,
  })

  // Get network config at top level
  const { network: resolvedNetwork, config: networkConfig } = useNetworkConfig()
  const routeBoardAddress = useRouteStore((state) => state.boardAddress)
  const routeNetwork = useRouteStore((state) => state.network)

  const networkSlug = Array.isArray(params?.network)
    ? params?.network[0]
    : (params?.network as string | undefined)
  const boardAddressParam = Array.isArray(params?.boardAddress)
    ? params?.boardAddress[0]
    : (params?.boardAddress as string | undefined)

  const network =
    routeNetwork ?? (networkSlug ? getNetworkFromSlug(networkSlug) : (resolvedNetwork ?? null))
  const boardAddress = routeBoardAddress
    ? routeBoardAddress
    : boardAddressParam
      ? (boardAddressParam.toLowerCase() as `0x${string}`)
      : null

  const [boardState, setBoardState] = useState(initialBoard)

  const formatter = useCallback(
    (value?: number | null | undefined) => {
      if (value == null || !boardState.underlyingTokenDecimals) return 0
      return Math.ceil(value / 10 ** boardState.underlyingTokenDecimals)
    },
    [boardState.underlyingTokenDecimals],
  )

  const fetchBoardMetadata = useCallback(async () => {
    if (!boardAddress || !networkConfig) {
      setBoardState(initialBoard)
      return
    }

    if (!networkConfig.indexerGraphQLEndpoint) {
      console.warn('Missing indexer configuration')
      setBoardState(initialBoard)
      return
    }

    const toNumber = (value?: string | number | null): number | null => {
      if (value == null) return null
      try {
        return Number(BigInt(value))
      } catch {
        return null
      }
    }

    const toNumberArray = (values?: Array<string | number | null> | null): number[] | null => {
      if (!values || values.length === 0) return null

      const parsed = values
        .map((value) => {
          if (value == null) return null
          try {
            return Number(BigInt(value))
          } catch {
            const asNumber = Number(value)
            return Number.isNaN(asNumber) ? null : asNumber
          }
        })
        .filter((value): value is number => value != null)

      return parsed.length > 0 ? parsed : null
    }

    try {
      const query = `
        query BoardByAddress($chainId: Int!, $contractAddress: String!) {
          boards(where: { chainId: $chainId, contractAddress: $contractAddress }) {
            items {
              chainId
              blockTimestamp
              transactionHash
              contractAddress
              owner
              title
              opensAt
              closesAt
              proposerRequirements
              participantRequirements
              acceptanceThreshold
              lockInterval
              maxLockIntervals
              underlyingToken
              underlyingTokenSymbol
              underlyingTokenDecimals
              underlyingTokenName
              body
              decayCurveType
              decayCurveParameters
            }
          }
        }
      `

      const resp = await fetch(networkConfig.indexerGraphQLEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          query,
          variables: {
            chainId: networkConfig.chain.id,
            contractAddress: boardAddress,
          },
        }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.status} ${resp.statusText}`)
      }

      const result: BoardByAddressQueryResponse = await resp.json()

      const indexedBoard = result.data?.boards?.items?.[0]

      if (!indexedBoard) {
        setBoardState(initialBoard)
        return
      }

      setBoardState({
        chainId: toNumber(indexedBoard.chainId),
        blockTimestamp: toNumber(indexedBoard.blockTimestamp),
        transactionHash: indexedBoard.transactionHash ?? null,
        contractAddress: indexedBoard.contractAddress
          ? (indexedBoard.contractAddress.toLowerCase() as `0x${string}`)
          : null,
        owner: indexedBoard.owner ? (indexedBoard.owner.toLowerCase() as `0x${string}`) : null,
        name: indexedBoard.title ?? null,
        body: indexedBoard.body ?? null,
        opensAt: toNumber(indexedBoard.opensAt),
        closesAt: toNumber(indexedBoard.closesAt),
        symbol: null,
        initiativesCount: null,
        proposalThreshold: toNumber(indexedBoard.proposerRequirements.minBalance),
        acceptanceThreshold: toNumber(indexedBoard.acceptanceThreshold),
        lockInterval: toNumber(indexedBoard.lockInterval),
        maxLockIntervals: toNumber(indexedBoard.maxLockIntervals),
        decayCurveType: toNumber(indexedBoard.decayCurveType),
        decayCurveParameters: toNumberArray(indexedBoard.decayCurveParameters),
        proposerRequirements: indexedBoard.proposerRequirements,
        participantRequirements: indexedBoard.participantRequirements,
        underlyingToken: indexedBoard.underlyingToken
          ? (indexedBoard.underlyingToken.toLowerCase() as `0x${string}`)
          : undefined,
        underlyingTokenSymbol: indexedBoard.underlyingTokenSymbol ?? null,
        underlyingTokenDecimals: indexedBoard.underlyingTokenDecimals ?? null,
        underlyingTokenName: indexedBoard.underlyingTokenName ?? null,
      })
    } catch (error) {
      console.error('Error fetching board metadata from indexer:', error)
      setBoardState(initialBoard)
    }
  }, [boardAddress, networkConfig])

  useEffect(() => {
    void fetchBoardMetadata()
  }, [fetchBoardMetadata])

  useEffect(() => {
    if (!isInitialized || !boardAddress || !networkConfig) {
      console.info(
        'Fetching balances for board...',
        boardAddress,
        'on network...',
        networkConfig.chain.name,
      )
      setBalances({ walletBalance: 69, totalSupply: 420420 })
      return
    }
  }, [isInitialized, boardAddress, networkConfig])

  const navigateToBoard = useCallback(
    (address: `0x${string}`) => {
      if (!network) return
      router.push(getBoardUrl(network, address))
    },
    [router, network],
  )

  const contextValue = useMemo<SignalsContextValue>(
    () => ({
      network,
      boardAddress,
      board: boardState,
      /**
       * Checks if the wallet balance meets the proposal threshold
       *
       * @param walletBalance - The wallet balance of the underlying token
       * @returns Whether the wallet balance meets the proposal threshold
       */
      meetsProposalThreshold: (walletBalance: number) => {
        const meetsThreshold =
          walletBalance != null && walletBalance > 0 && boardState.proposalThreshold != null
            ? walletBalance >= boardState.proposalThreshold
            : null
        return meetsThreshold ?? false
      },
      underlyingAddress: boardState.underlyingToken ?? undefined,
      underlyingName: boardState.underlyingTokenName,
      underlyingSymbol: boardState.underlyingTokenSymbol,
      underlyingDecimals: boardState.underlyingTokenDecimals,
      underlyingTotalSupply: balances.totalSupply ?? null,
      underlyingBalance: balances.walletBalance ?? null,
      formatter,
      fetchBoardMetadata,
      navigateToBoard,
    }),
    [
      network,
      boardAddress,
      boardState,
      boardState.underlyingToken,
      boardState.underlyingTokenName,
      boardState.underlyingTokenSymbol,
      boardState.underlyingTokenDecimals,
      balances.totalSupply,
      balances.walletBalance,
      formatter,
      fetchBoardMetadata,
      navigateToBoard,
    ],
  )

  return <SignalsContext.Provider value={contextValue}>{children}</SignalsContext.Provider>
}
