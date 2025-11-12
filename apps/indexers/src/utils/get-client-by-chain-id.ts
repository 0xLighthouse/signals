type PublicClient = {
  chain?: { id?: number }
  readContract: (args: unknown) => Promise<unknown>
}

/**
 * Finds a public client by chain ID from the publicClients object.
 * The publicClients object is keyed by chain names (e.g., 'baseSepolia'),
 * so we need to search through the values to find the client with matching chain.id
 */
export function getClientByChainId(publicClients: Record<string, PublicClient>, chainId: number): PublicClient | undefined {
  return Object.values(publicClients).find(
    (client) => client?.chain?.id === chainId
  )
}

