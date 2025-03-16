import { GraphQLClient } from 'graphql-request'
import { createPublicClient, getContract, http } from 'viem'
import * as chains from 'viem/chains'
import { ContractAddresses, Network, type ContractInstance, type ContractType } from './constants'

const getChain = (chainId: number): chains.Chain => {
  const chain = Object.values(chains).find((chain) => chain.id === chainId)
  if (!chain) {
    throw new Error(`Chain ${chainId} not supported`)
  }
  return chain
}

const getRPC = (chainId: number) => {
  const key = `CUSTOM_RPC_${chainId}`
  const rpcUrl = process.env[key]

  if (!rpcUrl || rpcUrl === '') {
    return undefined
  }
  return rpcUrl
}

export const getReadClient = (chainId: number) => {
  return createPublicClient({
    chain: getChain(chainId),
    transport: http(getRPC(chainId)),
  })
}

export const getContractInstance = <T extends ContractType>(chainId: Network, contractType: T) => {
  const client = getReadClient(chainId)
  const { address, abi } = ContractAddresses[chainId][contractType]
  return getContract({
    address,
    abi,
    client: client,
  })
}

export const getGraphQLClient = () => {
  console.log('TODO: Move to env')
  const INDEXER_URL = 'http://localhost:42069/graphql'
  return new GraphQLClient(INDEXER_URL)
}
