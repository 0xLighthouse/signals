// app/use-wallet-client.ts
'use client'

import { useEffect, useMemo, useState } from 'react'
import { createWalletClient, custom, type WalletClient, type Hex } from 'viem'
import { CHAINS } from '@/lib/chains'
import { useChain } from '@/contexts/ChainProvider'
import { useWallets } from '@privy-io/react-auth'
import type { ConnectedWallet } from '@privy-io/react-auth'

export function pickActiveWallet(wallets: ConnectedWallet[]) {
  // Heuristic: prefer embedded, else first connected.
  // Adjust to your preference (external first, last used, etc).
  return wallets.find((w) => w.walletClientType === 'privy') ?? wallets[0] ?? null
}

export function useWalletClient() {
  const { chainKey } = useChain()
  const { wallets } = useWallets()

  const [walletClient, setWalletClient] = useState<WalletClient | null>(null)
  const activeWallet = useMemo(() => pickActiveWallet(wallets), [wallets])

  useEffect(() => {
    let alive = true

    async function init() {
      if (!activeWallet) return setWalletClient(null)

      const provider = await activeWallet.getEthereumProvider() // EIP-1193  [oai_citation:1‡docs.privy.io](https://docs.privy.io/wallets/connectors/ethereum/integrations/viem?utm_source=chatgpt.com)
      const client = createWalletClient({
        account: activeWallet.address as Hex,
        chain: CHAINS[chainKey],
        transport: custom(provider),
      })

      if (alive) setWalletClient(client)
    }

    init()
    return () => {
      alive = false
    }
  }, [activeWallet, chainKey])

  return walletClient
}
