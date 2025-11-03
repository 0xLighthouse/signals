import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

type BoardSummary = {
  contractAddress: `0x${string}`
  owner?: `0x${string}`
  proposalThreshold?: string
  acceptanceThreshold?: string
  underlyingToken?: `0x${string}`
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
        chainId: number
        contractAddress: `0x${string}`
        owner: `0x${string}`
        proposalThreshold?: string
        acceptanceThreshold?: string
        underlyingToken?: `0x${string}`
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
        query BoardsByNetwork {
          boards(where: { chainId: ${chain.id} }) {
            items {
              ... on Board {
                chainId
                contractAddress
                owner
                proposalThreshold
                acceptanceThreshold
                underlyingToken
              }
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
        },
        body: JSON.stringify({ query }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.statusText}`)
      }

      const result: GraphQLResponse = await resp.json()

      if (result.data?.boards?.items) {
        const boards: BoardSummary[] = result.data.boards.items.map((item) => ({
          contractAddress: item.contractAddress.toLowerCase() as `0x${string}`,
          owner: item.owner.toLowerCase() as `0x${string}`,
          proposalThreshold: item.proposalThreshold,
          acceptanceThreshold: item.acceptanceThreshold,
          underlyingToken: item.underlyingToken?.toLowerCase() as `0x${string}` | undefined,
        }))
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

