'use client'

import { numberToHex, type WalletClient } from 'viem'

import type { NetworkConfig } from '@/config/network-types'

type WalletAddEthereumChainParameter = {
  chainId: `0x${string}`
  chainName: string
  nativeCurrency: {
    name: string
    symbol: string
    decimals: number
  }
  rpcUrls: readonly string[]
  blockExplorerUrls?: readonly string[]
}

export type EnsureWalletNetworkStatus = 'already-on-target' | 'switched' | 'added'

export type EnsureWalletNetworkResult =
  | { success: true; status: EnsureWalletNetworkStatus }
  | { success: false; error: Error }

export interface EnsureWalletNetworkOptions {
  walletClient: WalletClient | null
  network: NetworkConfig
  rpcUrlOverride?: string
  addIfMissing?: boolean
}

const buildAddChainParams = (
  network: NetworkConfig,
  rpcUrlOverride?: string,
): WalletAddEthereumChainParameter => {
  const { chain, explorerUrl, rpcUrl } = network
  const rpcCandidates = rpcUrlOverride ? [rpcUrlOverride] : chain.rpcUrls?.default?.http ?? []
  const rpcUrls = rpcCandidates.length > 0 ? rpcCandidates : [rpcUrl]
  const blockExplorerUrl = explorerUrl ?? chain.blockExplorers?.default?.url

  if (!rpcUrls.length) {
    throw new Error(`No RPC URLs configured for ${chain.name}`)
  }

  return {
    chainId: numberToHex(chain.id) as `0x${string}`,
    chainName: chain.name,
    nativeCurrency: chain.nativeCurrency,
    rpcUrls,
    blockExplorerUrls: blockExplorerUrl ? [blockExplorerUrl] : undefined,
  }
}

export const addNetworkToWallet = async (
  walletClient: WalletClient,
  network: NetworkConfig,
  rpcUrlOverride?: string,
) => {
  const params = buildAddChainParams(network, rpcUrlOverride)
  await walletClient.request({
    method: 'wallet_addEthereumChain',
    params: [params],
  })
}

export const ensureWalletNetwork = async ({
  walletClient,
  network,
  rpcUrlOverride,
  addIfMissing = true,
}: EnsureWalletNetworkOptions): Promise<EnsureWalletNetworkResult> => {
  if (!walletClient) {
    return { success: false, error: new Error('Wallet client is not available') }
  }

  const targetChainId = network.chain.id

  try {
    const currentChainId = await walletClient.getChainId()
    if (currentChainId === targetChainId) {
      return { success: true, status: 'already-on-target' }
    }
  } catch (error) {
    console.warn('Failed to read wallet chain id before switching', error)
  }

  try {
    await walletClient.switchChain({ id: targetChainId })
    return { success: true, status: 'switched' }
  } catch (switchError) {
    if (!addIfMissing) {
      return {
        success: false,
        error:
          switchError instanceof Error
            ? switchError
            : new Error('Failed to switch to the required network'),
      }
    }

    try {
      await addNetworkToWallet(walletClient, network, rpcUrlOverride)
      await walletClient.switchChain({ id: targetChainId })
      return { success: true, status: 'added' }
    } catch (addError) {
      return {
        success: false,
        error: addError instanceof Error ? addError : new Error('Failed to add network to wallet'),
      }
    }
  }
}

