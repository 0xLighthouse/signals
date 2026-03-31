'use client'

import { useState, useCallback } from 'react'
import { parseUnits } from 'viem'
import { toast } from 'sonner'
import { useRouter } from 'next/navigation'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { useAccount } from '@/hooks/useAccount'
import { getSlugFromNetwork } from '@/lib/routing'
import { ensureWalletNetwork } from '@/lib/wallet-network'
import { SignalsFactoryABI } from '../../../../packages/abis'

export const BOARD_DEFAULTS = {
  lockInterval: 86400,
  maxLockIntervals: 7,
  releaseLockDuration: 0,
  inactivityTimeout: 259200,
  decayCurveType: 1 as 0 | 1,
  decayParam: 0.92,
  thresholdPercent: 0,
  minThreshold: 1_000_000,
  permissions: 0 as 0 | 1,
  thresholdOverride: 1 as 0 | 1,
  proposerMinBalance: 20_000,
  proposerMinLock: 20_000,
  proposerMinHoldingDuration: 0,
  supporterMinBalance: 10_000,
  supporterMinLock: 5_000,
  supporterMinHoldingDuration: 0,
}

export type CreateBoardParams = {
  title: string
  body: string
  owner: `0x${string}`
  underlyingToken: `0x${string}`
  opensAt: number
  closesAt: number
  permissions: 0 | 1
  thresholdOverride: 0 | 1
  thresholdPercentTotalSupplyWAD: bigint
  minThreshold: bigint
  proposerMinBalance: bigint
  proposerMinHoldingDuration: bigint
  proposerMinLock: bigint
  supporterMinBalance: bigint
  supporterMinHoldingDuration: bigint
  supporterMinLock: bigint
  lockInterval: bigint
  maxLockIntervals: bigint
  releaseLockDuration: bigint
  inactivityTimeout: bigint
  decayCurveType: 0 | 1
  decayParams: bigint[]
}

export function buildBoardConfig(params: CreateBoardParams, version: string) {
  return {
    version,
    owner: params.owner,
    underlyingToken: params.underlyingToken,
    opensAt: BigInt(params.opensAt),
    closesAt: BigInt(params.closesAt),
    boardMetadata: {
      title: params.title,
      body: params.body,
      attachments: [],
    },
    acceptanceCriteria: {
      permissions: params.permissions,
      thresholdOverride: params.thresholdOverride,
      thresholdPercentTotalSupplyWAD: params.thresholdPercentTotalSupplyWAD,
      minThreshold: params.minThreshold,
    },
    proposerRequirements: {
      token: params.underlyingToken,
      minBalance: params.proposerMinBalance,
      minHoldingDuration: params.proposerMinHoldingDuration,
      minLockAmount: params.proposerMinLock,
    },
    supporterRequirements: {
      token: params.underlyingToken,
      minBalance: params.supporterMinBalance,
      minHoldingDuration: params.supporterMinHoldingDuration,
      minLockAmount: params.supporterMinLock,
    },
    lockingConfig: {
      lockInterval: params.lockInterval,
      maxLockIntervals: params.maxLockIntervals,
      releaseLockDuration: params.releaseLockDuration,
      inactivityTimeout: params.inactivityTimeout,
    },
    decayConfig: {
      curveType: params.decayCurveType,
      params: params.decayParams,
    },
  }
}

/** Convert a human-readable token amount to wei (18 decimals) */
export function toWei(amount: number, decimals = 18): bigint {
  return parseUnits(String(amount), decimals)
}

/** Convert a percentage (e.g. 10 for 10%) to WAD format */
export function percentToWAD(percent: number): bigint {
  return parseUnits(String(percent / 100), 18)
}

export function useCreateBoard() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const { config, network } = useNetworkConfig()
  const { address } = useAccount()
  const router = useRouter()

  const createBoard = useCallback(
    async (params: CreateBoardParams) => {
      if (!publicClient || !walletClient || !address) {
        toast('Wallet not connected')
        return null
      }

      const factoryAddress = config.contracts.SignalsFactory?.address
      if (!factoryAddress || factoryAddress === '0x0000000000000000000000000000000000000000') {
        toast('Factory not configured for this network')
        return null
      }

      try {
        setIsSubmitting(true)

        // Ensure wallet is on the correct chain
        const networkResult = await ensureWalletNetwork({
          walletClient,
          network: config,
        })
        if (!networkResult.success) {
          toast('Please switch to the correct network')
          return null
        }

        // Read factory version
        const version = await publicClient.readContract({
          address: factoryAddress as `0x${string}`,
          abi: SignalsFactoryABI,
          functionName: 'version',
        }) as string

        const boardConfig = buildBoardConfig(params, version)
        const nonce = await publicClient.getTransactionCount({ address })

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const { request } = await publicClient.simulateContract({
          account: address,
          address: factoryAddress as `0x${string}`,
          abi: SignalsFactoryABI,
          functionName: 'create',
          nonce,
          args: [boardConfig],
        } as any)

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const hash = await walletClient.writeContract(request as any)

        const receipt = await publicClient.waitForTransactionReceipt({
          hash,
          confirmations: 2,
          pollingInterval: 2000,
        })

        // Extract board address from BoardCreated event logs
        const boardCreatedLog = receipt.logs.find(
          (log) => log.topics[0] === '0x' + 'a7607d5a43237dd6925dd09a12e14aa04e325cca1d6c2a25bcbc3bcea0e5dfd3',
        )
        const boardAddress = boardCreatedLog?.topics[1]
          ? (`0x${boardCreatedLog.topics[1].slice(26)}` as `0x${string}`)
          : null

        toast('Board created successfully!')

        if (boardAddress) {
          const slug = getSlugFromNetwork(network)
          router.push(`/${slug}/${boardAddress.toLowerCase()}`)
        }

        return boardAddress
      } catch (error) {
        console.error('Error creating board:', error)
        if ((error as Error)?.message?.includes('User rejected the request')) {
          toast('Transaction rejected')
        } else {
          toast('Error creating board')
        }
        return null
      } finally {
        setIsSubmitting(false)
      }
    },
    [publicClient, walletClient, address, config, network, router],
  )

  return { createBoard, isSubmitting }
}
