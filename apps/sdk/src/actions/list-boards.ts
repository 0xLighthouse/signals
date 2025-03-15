import { gql } from 'graphql-request'
import { getGraphQLClient } from '../clients'
import type { Query } from '../types/graphql'

const QUERY_BOARDS_BY_CHAIN_ID = gql`
query BoardsByChainId($chainId: Int) {
  factoryCreatedEvents(where: { chainId: $chainId}) {
    items {
      chainId
      newSignals
      owner
      transactionHash
      blockTimestamp
    }
  }
}`

export const listBoards = async (chainId: number) => {
  const client = getGraphQLClient()
  const { items } = await client.request<Query['factoryCreatedEvents']>(QUERY_BOARDS_BY_CHAIN_ID, {
    chainId,
  })
  return items
}
