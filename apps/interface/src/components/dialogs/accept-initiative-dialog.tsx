'use client'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, shortAddress } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'
import type { Initiative } from 'indexers/src/api/types'

interface AcceptInitiativeDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initiative: Initiative
  onAccept: () => Promise<void>
  isAccepting: boolean
}

export function AcceptInitiativeDialog({
  open,
  onOpenChange,
  initiative,
  onAccept,
  isAccepting,
}: AcceptInitiativeDialogProps) {
  const { board, boardAddress, network, underlyingSymbol, formatter } = useSignals()

  const boardTitle = board.name ?? 'Untitled board'
  const addressLabel = boardAddress ? shortAddress(boardAddress) : 'Deploying soon'
  const networkLabel = network ? (NETWORKS[network]?.chain.name ?? network) : 'Unknown network'
  const supportPercentage = Number.parseFloat(String(initiative.support * 100))

  const formatTokenAmount = (value?: number | null) => {
    if (value == null) return '—'
    const adjusted = formatter(value)
    if (!Number.isFinite(adjusted)) return '—'
    if (adjusted === 0) return '0'
    if (adjusted >= 1000) return normaliseNumber(adjusted)
    return adjusted.toLocaleString('en-US')
  }

  const acceptanceThresholdValue = board.acceptanceCriteria?.minThreshold
    ? Number(board.acceptanceCriteria.minThreshold)
    : board.acceptanceThreshold
  const acceptanceThreshold = acceptanceThresholdValue
    ? formatTokenAmount(acceptanceThresholdValue)
    : '—'
  const thresholdWithSymbol =
    acceptanceThreshold !== '—' && underlyingSymbol
      ? `${acceptanceThreshold} ${underlyingSymbol}`
      : acceptanceThreshold

  const handleAccept = async () => {
    await onAccept()
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Accept initiative</DialogTitle>
          <DialogDescription>
            This initiative has reached the acceptance threshold and can be officially accepted.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-6">
          <section className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h3 className="text-sm font-medium mb-3">Initiative details</h3>
            <div className="space-y-3 text-sm">
              <div>
                <p className="text-neutral-500 dark:text-neutral-400 mb-1">Title</p>
                <p className="font-medium text-neutral-900 dark:text-white">{initiative.title}</p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-1">Current support</p>
                  <p className="font-medium text-neutral-900 dark:text-white">
                    {supportPercentage.toFixed(2)}%
                  </p>
                </div>
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-1">
                    Acceptance threshold
                  </p>
                  <p className="font-medium text-neutral-900 dark:text-white">
                    {thresholdWithSymbol}
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h3 className="text-sm font-medium mb-2">Board information</h3>
            <div className="grid grid-cols-1 gap-3 text-sm">
              <div>
                <p className="text-neutral-500 dark:text-neutral-400">Board</p>
                <p className="font-medium text-neutral-900 dark:text-white">{boardTitle}</p>
              </div>
              <div className="flex items-center gap-2">
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400">Network</p>
                  <p className="font-medium text-neutral-900 dark:text-white">{networkLabel}</p>
                </div>
                <span className="text-neutral-400">•</span>
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400">Contract</p>
                  <p className="font-mono text-neutral-900 dark:text-white">{addressLabel}</p>
                </div>
              </div>
            </div>
          </section>

          <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 dark:border-amber-800 dark:bg-amber-950/20">
            <p className="text-sm text-amber-900 dark:text-amber-200">
              <strong>Note:</strong> Accepting an initiative is permanent and cannot be undone. Once
              accepted, supporters can redeem their locked tokens after any release timelock period.
            </p>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={isAccepting}>
            Cancel
          </Button>
          <Button onClick={handleAccept} disabled={isAccepting}>
            {isAccepting ? 'Accepting...' : 'Accept initiative'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
