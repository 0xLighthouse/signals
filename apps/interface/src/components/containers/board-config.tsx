'use client'

import React, { useState } from 'react'

import { useSignals } from '@/hooks/use-signals'
import { useAccount } from '@/hooks/useAccount'
import { shortAddress } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'
import { Settings, ExternalLink } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { BoardSettingsDialog } from '@/components/dialogs/board-settings-dialog'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'

export const BoardConfig = () => {
  const { board, boardAddress, network, underlyingBalance } = useSignals()
  const { isConnected } = useAccount()
  const { config: networkConfig } = useNetworkConfig()
  const [isSettingsOpen, setIsSettingsOpen] = useState(false)

  const boardTitle = board.name ?? 'Untitled board'
  const addressLabel = boardAddress ? shortAddress(boardAddress) : 'Deploying soon (stub)'
  const networkLabel = network ? (NETWORKS[network]?.chain.name ?? network) : 'Unknown network'

  // Build explorer URL for the board contract
  const getExplorerUrl = (address: `0x${string}`) => {
    const explorerUrl = networkConfig.explorerUrl
    if (!explorerUrl) return null
    return `${explorerUrl}/address/${address}`
  }

  const explorerUrl = boardAddress ? getExplorerUrl(boardAddress) : null

  // Determine status badge - only show user-specific status if connected
  let statusLabel: string | null = null
  let statusStyles = ''

  if (isConnected && underlyingBalance != null && board.proposalThreshold != null) {
    // User is connected - show their ability to propose
    if (board.meetsThreshold) {
      statusLabel = 'You can propose'
      statusStyles = 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300'
    } else {
      statusLabel = 'You need more tokens'
      statusStyles = 'bg-amber-100 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300'
    }
  } else if (boardAddress) {
    // No user connected or balance unknown - show board-level status
    statusLabel = 'Active'
    statusStyles = 'bg-blue-100 text-blue-700 dark:bg-blue-500/10 dark:text-blue-300'
  }

  return (
    <section className="rounded-2xl bg-white text-neutral-900 dark:bg-neutral-950 dark:text-white">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <div>
            <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
              Board overview
            </p>
            <h2 className="text-2xl font-semibold">{boardTitle}</h2>
            <div className="flex items-center gap-2 text-sm text-neutral-500 dark:text-neutral-400">
              <span>Contract</span>
              {explorerUrl && boardAddress ? (
                <a
                  href={explorerUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-neutral-900 dark:text-white hover:underline"
                >
                  {addressLabel}
                  <ExternalLink className="h-3 w-3" />
                </a>
              ) : (
                <span>{addressLabel}</span>
              )}
              <span>•</span>
              <span>{networkLabel}</span>
            </div>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setIsSettingsOpen(true)}
            className="h-8 w-8"
            aria-label="Board settings"
          >
            <Settings className="h-4 w-4" />
          </Button>
        </div>
        {statusLabel && (
          <span className={`w-fit rounded-full px-3 py-1 text-xs font-medium ${statusStyles}`}>
            {statusLabel}
          </span>
        )}
      </div>
      <BoardSettingsDialog open={isSettingsOpen} onOpenChange={setIsSettingsOpen} />
    </section>
  )
}
