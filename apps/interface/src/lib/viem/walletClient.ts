// lib/viem/walletClient.ts
'use client'

import { createWalletClient, custom } from 'viem'
import { CHAINS, type ChainKey } from '../chains'

export function getWalletClient(chainKey: ChainKey) {
  const ethereum = (globalThis as any).ethereum
  if (!ethereum) throw new Error('No injected wallet found')

  return createWalletClient({
    chain: CHAINS[chainKey],
    transport: custom(ethereum),
  })
}
