'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { useAccount } from '@/hooks/useAccount'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { useSignals } from '@/hooks/use-signals'
import { SignalsABI } from '../../../../../packages/abis'
import { toast } from 'sonner'
import { formatUnits } from 'viem'
import type { InitiativeLock } from '@/indexers/api/types'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

interface UserLocksDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function UserLocksDialog({ open, onOpenChange }: UserLocksDialogProps) {
  const { address } = useAccount()
  const { boardAddress, underlyingSymbol, underlyingDecimals, board } = useSignals()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const { chain, indexerEndpoint, explorerUrl } = useNetworkStore((state) => state.config)
  const chainId = chain?.id
  const initiatives = useInitiativesStore((state) => state.initiatives)
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)
  const initiativesInitialized = useInitiativesStore((state) => state.isInitialized)

  const [isLoading, setIsLoading] = useState(false)
  const [isRedeeming, setIsRedeeming] = useState<string | null>(null)
  const [userLocks, setUserLocks] = useState<InitiativeLock[]>([])
  const [selectedLockIds, setSelectedLockIds] = useState<Set<string>>(new Set())

  const fetchUserLocks = useCallback(async () => {
    if (!address || !boardAddress || !indexerEndpoint || !chainId) {
      setUserLocks([])
      return
    }

    setIsLoading(true)
    try {
      const resp = await fetch(
        `${indexerEndpoint}/locks/account/${chainId}/${boardAddress}/${address}`,
      )
      const { data } = await resp.json()
      const locks = Array.isArray(data) ? (data as InitiativeLock[]) : []
      setUserLocks(locks)
    } catch (error) {
      console.error('Error fetching locks:', error)
      toast('Error loading locks')
      setUserLocks([])
    } finally {
      setIsLoading(false)
    }
  }, [address, boardAddress, chainId, indexerEndpoint])

  useEffect(() => {
    if (!open || !boardAddress || initiativesInitialized) return
    void fetchInitiatives(boardAddress)
  }, [open, boardAddress, initiativesInitialized, fetchInitiatives])

  // Fetch user locks when dialog opens and user is connected
  useEffect(() => {
    if (!open) return
    if (!address) {
      setUserLocks([])
      return
    }

    void fetchUserLocks()
  }, [open, address, fetchUserLocks])

  const initiativeById = useMemo(() => {
    return new Map(
      initiatives.map((initiative) => [initiative.initiativeId.toString(), initiative]),
    )
  }, [initiatives])

  const getLockKey = useCallback((lock: InitiativeLock) => {
    return lock.tokenId?.toString() ?? ''
  }, [])

  // Filter redeemable locks from the indexer flag
  const redeemableLocks = useMemo(() => {
    return userLocks.filter((lock) => {
      if (lock.isRedeemed) return false
      return lock.isRedeemable === true
    })
  }, [userLocks])

  const redeemedLocks = useMemo(() => {
    return userLocks.filter((lock) => lock.isRedeemed)
  }, [userLocks])

  const lockedLocks = useMemo(() => {
    return userLocks.filter((lock) => !lock.isRedeemed && lock.isRedeemable !== true)
  }, [userLocks])

  const redeemableKeys = useMemo(() => {
    return new Set(redeemableLocks.map((lock) => getLockKey(lock)).filter(Boolean))
  }, [redeemableLocks, getLockKey])

  useEffect(() => {
    setSelectedLockIds((current) => {
      const next = new Set([...current].filter((key) => redeemableKeys.has(key)))
      if (next.size === current.size) return current
      return next
    })
  }, [redeemableKeys])

  const groupedRedeemableLocks = useMemo(() => {
    const groups = new Map<string, InitiativeLock[]>()
    redeemableLocks.forEach((lock) => {
      const key = lock.initiativeId.toString()
      const current = groups.get(key)
      if (current) {
        current.push(lock)
      } else {
        groups.set(key, [lock])
      }
    })
    return groups
  }, [redeemableLocks])

  const groupedRedeemedLocks = useMemo(() => {
    const groups = new Map<string, InitiativeLock[]>()
    redeemedLocks.forEach((lock) => {
      const key = lock.initiativeId.toString()
      const current = groups.get(key)
      if (current) {
        current.push(lock)
      } else {
        groups.set(key, [lock])
      }
    })
    return groups
  }, [redeemedLocks])

  const groupedLockedLocks = useMemo(() => {
    const groups = new Map<string, InitiativeLock[]>()
    lockedLocks.forEach((lock) => {
      const key = lock.initiativeId.toString()
      const current = groups.get(key)
      if (current) {
        current.push(lock)
      } else {
        groups.set(key, [lock])
      }
    })
    return groups
  }, [lockedLocks])

  const selectedLocks = useMemo(() => {
    if (selectedLockIds.size === 0) return []
    return redeemableLocks.filter((lock) => selectedLockIds.has(getLockKey(lock)))
  }, [redeemableLocks, selectedLockIds, getLockKey])

  const isBulkRedeeming = isRedeeming === 'bulk'
  const selectedCount = selectedLocks.length
  const redeemableCount = redeemableLocks.length
  const redeemedCount = redeemedLocks.length
  const lockedCount = lockedLocks.length
  const defaultTab =
    lockedCount > 0 ? 'locked' : redeemableCount > 0 ? 'redeemable' : 'redeemed'
  const totalSelectedAmount = useMemo(() => {
    return selectedLocks.reduce((sum, lock) => {
      try {
        return sum + BigInt(lock.nominalValue || 0)
      } catch {
        return sum
      }
    }, 0n)
  }, [selectedLocks])

  const handleRedeem = async (lock: InitiativeLock) => {
    if (!address || !walletClient || !publicClient || !boardAddress) {
      toast('Wallet not connected')
      return
    }

    const lockKey = getLockKey(lock)
    setIsRedeeming(lockKey)
    try {
      const { request } = await publicClient.simulateContract({
        account: address,
        address: boardAddress,
        abi: SignalsABI,
        functionName: 'redeemLock',
        args: [BigInt(lock.tokenId || 0)],
      })

      const hash = await walletClient.writeContract(request)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })

      console.log('Redeem receipt:', receipt)
      toast('Lock redeemed successfully!')

      // Refresh user locks after redeem
      await fetchUserLocks()
    } catch (error) {
      console.error('Error redeeming lock:', error)
      if (error instanceof Error && error.message.includes('User rejected')) {
        toast('Transaction cancelled')
      } else {
        toast('Error redeeming lock')
      }
    } finally {
      setIsRedeeming(null)
    }
  }

  const handleRedeemSelected = async () => {
    if (!address || !walletClient || !publicClient || !boardAddress) {
      toast('Wallet not connected')
      return
    }

    if (selectedLocks.length === 0) {
      toast('No locks selected')
      return
    }

    setIsRedeeming('bulk')
    try {
      const grouped = new Map<string, InitiativeLock[]>()
      selectedLocks.forEach((lock) => {
        const key = lock.initiativeId.toString()
        const current = grouped.get(key)
        if (current) {
          current.push(lock)
        } else {
          grouped.set(key, [lock])
        }
      })

      for (const [initiativeId, locks] of grouped.entries()) {
        const lockIds = locks.map((lock) => BigInt(lock.tokenId || 0))
        const { request } = await publicClient.simulateContract({
          account: address,
          address: boardAddress,
          abi: SignalsABI,
          functionName: 'redeemLocksForInitiative',
          args: [BigInt(initiativeId), lockIds],
        })

        const hash = await walletClient.writeContract(request)

        await publicClient.waitForTransactionReceipt({
          hash,
          confirmations: 2,
          pollingInterval: 2000,
        })
      }

      toast('Selected locks redeemed successfully!')
      setSelectedLockIds(new Set())
      await fetchUserLocks()
    } catch (error) {
      console.error('Error redeeming selected locks:', error)
      if (error instanceof Error && error.message.includes('User rejected')) {
        toast('Transaction cancelled')
      } else {
        toast('Error redeeming selected locks')
      }
    } finally {
      setIsRedeeming(null)
    }
  }

  const formatAmount = (lock: InitiativeLock) => {
    if (!lock.nominalValue) return '—'
    const decimals = underlyingDecimals || 18
    try {
      return Number(formatUnits(BigInt(lock.nominalValue), decimals)).toLocaleString(undefined, {
        maximumFractionDigits: 2,
      })
    } catch {
      return '—'
    }
  }

  const formatUnlockTime = (lock: InitiativeLock) => {
    const lockInterval = board?.lockInterval || 86400
    const createdAt = Number(lock.createdAt || 0)
    const durationAsIntervals = Number(lock.durationAsIntervals || 0)

    // Try direct unlockTime first, then calculate
    const directUnlockTime = lock.unlockTime ? Number(lock.unlockTime) : null
    const calculatedUnlockTime =
      createdAt > 0 && durationAsIntervals > 0
        ? createdAt + durationAsIntervals * lockInterval
        : null
    const unlockTime = directUnlockTime || calculatedUnlockTime

    if (!unlockTime || unlockTime === 0) return '—'

    const date = new Date(unlockTime * 1000)
    return date.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const getTxUrl = (hash?: string | null) => {
    if (!hash || !explorerUrl) return null
    const trimmed = explorerUrl.endsWith('/') ? explorerUrl.slice(0, -1) : explorerUrl
    return `${trimmed}/tx/${hash}`
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Your Locks</DialogTitle>
          <DialogDescription>View and redeem your locked tokens for this board</DialogDescription>
        </DialogHeader>

        {!address ? (
          <div className="text-center py-8">
            <p className="text-neutral-500 dark:text-neutral-400">
              Please connect your wallet to view your locks.
            </p>
          </div>
        ) : isLoading ? (
          <div className="flex justify-center py-8">
            <LoadingSpinner />
          </div>
        ) : redeemableLocks.length === 0 && redeemedLocks.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-neutral-500 dark:text-neutral-400">
              {userLocks.length === 0
                ? 'You have no locks for this board.'
                : 'You have no redeemable locks at this time.'}
            </p>
          </div>
        ) : (
          <Tabs defaultValue={defaultTab} className="space-y-4">
            <TabsList className="w-fit mx-auto">
              <TabsTrigger value="locked" className="gap-2">
                Locked
                <span className="text-xs text-neutral-500 dark:text-neutral-400">
                  {lockedCount}
                </span>
              </TabsTrigger>
              <TabsTrigger value="redeemable" className="gap-2">
                Redeemable
                <span className="text-xs text-neutral-500 dark:text-neutral-400">
                  {redeemableCount}
                </span>
              </TabsTrigger>
              <TabsTrigger value="redeemed" className="gap-2">
                Claimed
                <span className="text-xs text-neutral-500 dark:text-neutral-400">
                  {redeemedCount}
                </span>
              </TabsTrigger>
            </TabsList>

            <TabsContent value="redeemable" className="space-y-4">
              {redeemableCount === 0 ? (
                <div className="text-sm text-neutral-500 dark:text-neutral-400">
                  No redeemable locks yet.
                </div>
              ) : (
                <>
                  <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-neutral-500 dark:text-neutral-400">
                    <div className="flex items-center gap-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() =>
                          setSelectedLockIds(new Set(Array.from(redeemableKeys.values())))
                        }
                        disabled={redeemableKeys.size === 0}
                      >
                        Select all
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setSelectedLockIds(new Set())}
                        disabled={selectedLockIds.size === 0}
                      >
                        Clear
                      </Button>
                    </div>
                  </div>

                  {Array.from(groupedRedeemableLocks.entries()).map(([initiativeId, locks]) => {
                    const initiative = initiativeById.get(initiativeId)
                    const initiativeTitle = initiative?.title ?? 'Untitled initiative'
                    return (
                      <div
                        key={initiativeId}
                        className="border border-neutral-200 dark:border-neutral-800 rounded-lg p-4 space-y-3"
                      >
                        <div className="flex flex-col gap-1">
                          <div className="font-medium">
                            Initiative #{initiativeId} - {initiativeTitle}
                          </div>
                          <div className="text-xs text-neutral-500 dark:text-neutral-400">
                            {locks.length} redeemable lock{locks.length === 1 ? '' : 's'}
                          </div>
                        </div>
                        <div className="rounded-lg border border-neutral-200 dark:border-neutral-800 overflow-hidden">
                          <div className="grid grid-cols-[auto_1fr_1fr_auto] items-center gap-3 px-3 py-2 text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400 bg-neutral-50 dark:bg-neutral-900/40">
                            <div />
                            <div>Amount</div>
                            <div>Unlocked</div>
                            <div className="text-right">Action</div>
                          </div>
                          {locks.map((lock) => {
                            const lockKey = getLockKey(lock)
                            const isSelected = selectedLockIds.has(lockKey)
                            const isLockRedeeming = isRedeeming === lockKey
                            return (
                              <div
                                key={lockKey}
                                className="grid grid-cols-[auto_1fr_1fr_auto] items-center gap-3 px-3 py-2 text-sm border-t border-neutral-200 dark:border-neutral-800"
                              >
                                <input
                                  type="checkbox"
                                  className="h-4 w-4 accent-neutral-900 dark:accent-neutral-100"
                                  checked={isSelected}
                                  onChange={() => {
                                    setSelectedLockIds((current) => {
                                      const next = new Set(current)
                                      if (isSelected) {
                                        next.delete(lockKey)
                                      } else if (lockKey) {
                                        next.add(lockKey)
                                      }
                                      return next
                                    })
                                  }}
                                />
                                <div className="truncate">
                                  {formatAmount(lock)} {underlyingSymbol}
                                </div>
                                <div className="text-xs text-neutral-500 dark:text-neutral-400">
                                  {formatUnlockTime(lock)}
                                </div>
                                <div className="flex justify-end">
                                  <Button
                                    size="sm"
                                    onClick={() => void handleRedeem(lock)}
                                    disabled={isBulkRedeeming || isLockRedeeming}
                                    isLoading={isLockRedeeming}
                                  >
                                    {isLockRedeeming ? 'Redeeming...' : 'Redeem'}
                                  </Button>
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    )
                  })}

                  <div className="flex flex-wrap items-center justify-between gap-3 border border-neutral-200 dark:border-neutral-800 rounded-lg p-4 bg-neutral-50 dark:bg-neutral-900/40">
                    <div className="text-sm text-neutral-600 dark:text-neutral-300">
                      Selected {selectedCount} lock{selectedCount === 1 ? '' : 's'}
                      {selectedCount > 0 && (
                        <>
                          {' '}
                          • {formatUnits(totalSelectedAmount, underlyingDecimals || 18)}{' '}
                          {underlyingSymbol}
                        </>
                      )}
                    </div>
                    <Button
                      onClick={() => void handleRedeemSelected()}
                      disabled={selectedCount === 0 || isRedeeming !== null}
                      isLoading={isBulkRedeeming}
                    >
                      {isBulkRedeeming ? 'Redeeming selected...' : 'Redeem selected'}
                    </Button>
                  </div>
                </>
              )}
            </TabsContent>

            <TabsContent value="locked" className="space-y-4">
              {lockedCount === 0 ? (
                <div className="text-sm text-neutral-500 dark:text-neutral-400">
                  No locked positions right now.
                </div>
              ) : (
                Array.from(groupedLockedLocks.entries()).map(([initiativeId, locks]) => {
                  const initiative = initiativeById.get(initiativeId)
                  const initiativeTitle = initiative?.title ?? 'Untitled initiative'
                  return (
                    <div
                      key={initiativeId}
                      className="border border-neutral-200 dark:border-neutral-800 rounded-lg p-4 space-y-3"
                    >
                      <div className="flex flex-col gap-1">
                        <div className="font-medium">
                          Initiative #{initiativeId} - {initiativeTitle}
                        </div>
                        <div className="text-xs text-neutral-500 dark:text-neutral-400">
                          {locks.length} locked position{locks.length === 1 ? '' : 's'}
                        </div>
                      </div>
                      <div className="rounded-lg border border-neutral-200 dark:border-neutral-800 overflow-hidden">
                        <div className="grid grid-cols-[1fr_1fr_auto] items-center gap-3 px-3 py-2 text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400 bg-neutral-50 dark:bg-neutral-900/40">
                          <div>Amount</div>
                          <div>Unlocks</div>
                          <div className="text-right">Status</div>
                        </div>
                        {locks.map((lock) => {
                          const lockKey = getLockKey(lock)
                          return (
                            <div
                              key={lockKey}
                              className="grid grid-cols-[1fr_1fr_auto] items-center gap-3 px-3 py-2 text-sm border-t border-neutral-200 dark:border-neutral-800"
                            >
                              <div className="truncate">
                                {formatAmount(lock)} {underlyingSymbol}
                              </div>
                              <div className="text-xs text-neutral-500 dark:text-neutral-400">
                                {formatUnlockTime(lock)}
                              </div>
                              <div className="flex justify-end">
                                <Badge variant="secondary">Locked</Badge>
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>
                  )
                })
              )}
            </TabsContent>

            <TabsContent value="redeemed" className="space-y-4">
              {redeemedCount === 0 ? (
                <div className="text-sm text-neutral-500 dark:text-neutral-400">
                  No claimed locks yet.
                </div>
              ) : (
                Array.from(groupedRedeemedLocks.entries()).map(([initiativeId, locks]) => {
                  const initiative = initiativeById.get(initiativeId)
                  const initiativeTitle = initiative?.title ?? 'Untitled initiative'
                  return (
                    <div
                      key={initiativeId}
                      className="border border-neutral-200 dark:border-neutral-800 rounded-lg p-4 space-y-3"
                    >
                      <div className="flex flex-col gap-1">
                        <div className="font-medium">
                          Initiative #{initiativeId} - {initiativeTitle}
                        </div>
                        <div className="text-xs text-neutral-500 dark:text-neutral-400">
                          {locks.length} claimed lock{locks.length === 1 ? '' : 's'}
                        </div>
                      </div>
                      <div className="rounded-lg border border-neutral-200 dark:border-neutral-800 overflow-hidden">
                        <div className="grid grid-cols-[1fr_1fr_auto_auto] items-center gap-3 px-3 py-2 text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400 bg-neutral-50 dark:bg-neutral-900/40">
                          <div>Amount</div>
                          <div>Unlocked</div>
                          <div className="text-right">Status</div>
                          <div className="text-right">Tx</div>
                        </div>
                        {locks.map((lock) => {
                          const lockKey = getLockKey(lock)
                          const txUrl = getTxUrl(lock.redeemedTxnHash)
                          return (
                            <div
                              key={lockKey}
                              className="grid grid-cols-[1fr_1fr_auto_auto] items-center gap-3 px-3 py-2 text-sm border-t border-neutral-200 dark:border-neutral-800"
                            >
                              <div className="truncate">
                                {formatAmount(lock)} {underlyingSymbol}
                              </div>
                              <div className="text-xs text-neutral-500 dark:text-neutral-400">
                                {formatUnlockTime(lock)}
                              </div>
                              <div className="flex justify-end">
                                <Badge variant="secondary">Claimed</Badge>
                              </div>
                              <div className="flex justify-end">
                                {txUrl ? (
                                  <Button variant="ghost" size="sm" asChild>
                                    <a href={txUrl} target="_blank" rel="noreferrer">
                                      View
                                    </a>
                                  </Button>
                                ) : (
                                  <span className="text-xs text-neutral-400">—</span>
                                )}
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>
                  )
                })
              )}
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  )
}
