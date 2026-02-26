type PublicClientLike = {
  chain?: { id?: number }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  readContract: (...args: any[]) => Promise<any>
  [key: string]: unknown
}

/**
 * Finds a public client by chain ID from the publicClients object.
 * The publicClients object is keyed by chain names (e.g., 'baseSepolia'),
 * so we need to search through the values to find the client with matching chain.id
 */
export function getClientByChainId<T extends PublicClientLike>(publicClients: Record<string, T>, chainId: number): T | undefined {
  return Object.values(publicClients).find(
    (client) => client?.chain?.id === chainId
  )
}

