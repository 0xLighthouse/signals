import { createPublicClient, http, type PublicClient } from 'viem'
import { CHAINS, RPCS, type ChainKey } from '../chains'

const cache = new Map<ChainKey, PublicClient>()

export function getPublicClient(chainKey: ChainKey): PublicClient {
  const hit = cache.get(chainKey)
  if (hit) return hit

  const rpcUrl = RPCS[chainKey]
  if (!rpcUrl) throw new Error(`Missing RPC for ${chainKey}`)

  const client = createPublicClient({
    chain: CHAINS[chainKey],
    transport: http(rpcUrl),
    batch: { multicall: true },
  })

  const typed = client as PublicClient
  cache.set(chainKey, typed)

  return typed
}
