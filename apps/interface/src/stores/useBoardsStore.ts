import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

type Requirements = {
  eligibilityType: number
  minBalance: string
  minHoldingDuration: string
  minLockAmount: string
}

export type BoardSummary = {
  contractAddress: `0x${string}`
  owner?: `0x${string}`
  title: string
  body: string
  proposerRequirements: Requirements
  participantRequirements: Requirements
  acceptanceThreshold: string
  underlyingToken?: `0x${string}`
  createdAtTimestamp?: number
  updatedAt?: number
}

interface BoardsState {
  boards: BoardSummary[]
  isFetching: boolean
  isInitialized: boolean
  fetchBoards: () => Promise<void>
  reset: () => void
}

interface GraphQLResponse {
  data: {
    boards: {
      items: Array<{
        id: string
        chainId: number
        contractAddress: `0x${string}`
        owner: `0x${string}`
        title: string
        body: string
        proposerRequirements: Requirements
        participantRequirements: Requirements
        acceptanceThreshold: string
        underlyingToken?: `0x${string}`
        blockTimestamp: string
        transactionHash: string
      }>
      totalCount: number
      pageInfo: {
        startCursor: string | null
        endCursor: string | null
      }
    }
  }
}

export const useBoardsStore = create<BoardsState>((set) => ({
  boards: [],
  isFetching: false,
  isInitialized: false,
  fetchBoards: async () => {
    try {
      set({ isFetching: true })

      const { chain, indexerGraphQLEndpoint } = useNetworkStore.getState().config

      const query = `
        query BoardsByNetwork($chainId: Int!) {
          boards(where: { chainId: $chainId }) {
            items {
              id
              chainId
              contractAddress
              owner
              title
              body
              proposerRequirements
              participantRequirements
              acceptanceThreshold
              underlyingToken
              blockTimestamp
              transactionHash
            }
            totalCount
            pageInfo {
              startCursor
              endCursor
            }
          }
        }
      `

      const resp = await fetch(indexerGraphQLEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ query, variables: { chainId: chain.id } }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.status} ${resp.statusText}`)
      }

      const result: GraphQLResponse = await resp.json()

      if (result?.data?.boards?.items) {
        const boards: BoardSummary[] = result.data.boards.items.map((item) => {
          const createdAtSec = Number(item.blockTimestamp)
          const createdAtTimestamp = Number.isFinite(createdAtSec) ? createdAtSec : 0

          return {
            contractAddress: item.contractAddress.toLowerCase() as `0x${string}`,
            owner: item.owner?.toLowerCase() as `0x${string}`,
            title: item.title,
            body: item.body,
            proposerRequirements: item.proposerRequirements,
            participantRequirements: item.participantRequirements,
            acceptanceThreshold: item.acceptanceThreshold,
            underlyingToken: item.underlyingToken
              ? (item.underlyingToken.toLowerCase() as `0x${string}`)
              : undefined,
            createdAtTimestamp,
            updatedAt: createdAtTimestamp,
          }
        })

        set({ boards })
      } else {
        console.warn('GraphQL response missing expected data structure')
        set({ boards: [] })
      }
    } catch (error) {
      console.error('Error fetching boards from indexer:', error)
      set({ boards: [] })
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
  reset: () => set({ boards: [], isFetching: false, isInitialized: false }),
}))
