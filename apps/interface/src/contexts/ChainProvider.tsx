'use client'

import { createContext, useContext, useMemo, useState, type ReactNode } from 'react'

import type { ChainKey } from '@/lib/chains'
import { getPublicClient } from '@/lib/viem/publicClient'

type ChainContextValue = {
  chainKey: ChainKey
  setChainKey: (key: ChainKey) => void
}

const ChainContext = createContext<ChainContextValue | null>(null)

export function ChainProvider({
  initialChainKey,
  children,
}: {
  initialChainKey: ChainKey
  children: ReactNode
}) {
  const [chainKey, setChainKey] = useState<ChainKey>(initialChainKey)
  const value = useMemo(() => ({ chainKey, setChainKey }), [chainKey])

  return <ChainContext.Provider value={value}>{children}</ChainContext.Provider>
}

export function useChain() {
  const ctx = useContext(ChainContext)
  if (!ctx) throw new Error('useChain must be used within ChainProvider')
  return ctx
}

export function usePublicClient(chainKeyOverride?: ChainKey) {
  const { chainKey } = useChain()
  const key = chainKeyOverride ?? chainKey
  return useMemo(() => getPublicClient(key), [key])
}
