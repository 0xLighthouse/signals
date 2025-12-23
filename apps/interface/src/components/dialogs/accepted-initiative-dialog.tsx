'use client'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, shortAddress, timeAgoWords, resolveAvatar } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'
import type { Initiative } from '@/indexers/api/types'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { AvatarGroup } from '@/components/ui/avatar-group'
import { ExternalLink, Paperclip, CheckCircle } from 'lucide-react'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'

interface AcceptedInitiativeDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initiative: Initiative
}

export function AcceptedInitiativeDialog({
  open,
  onOpenChange,
  initiative,
}: AcceptedInitiativeDialogProps) {
  const { board, boardAddress, network, underlyingSymbol, formatter } = useSignals()

  const boardTitle = board.name ?? 'Untitled board'
  const addressLabel = boardAddress ? shortAddress(boardAddress) : 'Deploying soon'
  const networkLabel = network ? (NETWORKS[network]?.chain.name ?? network) : 'Unknown network'
  const supportPercentage = Number.parseFloat(String(initiative.support * 100))
  const hasAttachments = initiative.attachments && initiative.attachments.length > 0

  const proposerName = useAsyncProp(
    resolveName(initiative.proposer),
    shortAddress(initiative.proposer),
  )

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

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <CheckCircle className="h-5 w-5 text-green-600 dark:text-green-400" />
            <DialogTitle>Accepted Initiative</DialogTitle>
          </div>
          <DialogDescription>
            This initiative has been officially accepted and is now in development.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-6">
          {/* Initiative Details */}
          <section className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h3 className="text-sm font-medium mb-3">Initiative details</h3>
            <div className="space-y-3 text-sm">
              <div>
                <p className="text-neutral-500 dark:text-neutral-400 mb-1">Title</p>
                <p className="font-medium text-neutral-900 dark:text-white text-base">
                  {initiative.title}
                </p>
              </div>
              <div>
                <p className="text-neutral-500 dark:text-neutral-400 mb-1">Description</p>
                <p className="text-neutral-900 dark:text-white whitespace-pre-wrap break-words">
                  {initiative.description}
                </p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-1">Final support</p>
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
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-1">Proposed by</p>
                  <div className="flex items-center gap-2">
                    <Avatar className="h-5 w-5">
                      <AvatarImage
                        src={resolveAvatar(initiative.proposer)}
                        alt={initiative.proposer}
                      />
                    </Avatar>
                    <p className="font-medium text-neutral-900 dark:text-white">{proposerName}</p>
                  </div>
                </div>
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-1">Created</p>
                  <p className="font-medium text-neutral-900 dark:text-white">
                    {timeAgoWords(initiative.createdAtTimestamp)}
                  </p>
                </div>
              </div>
              {hasAttachments && (
                <div>
                  <p className="text-neutral-500 dark:text-neutral-400 mb-2">Attachments</p>
                  <ul className="space-y-2">
                    {initiative.attachments.map((attachment, index) => {
                      const label = attachment.description || attachment.uri
                      return (
                        <li key={`${attachment.uri}-${index}`} className="text-sm">
                          <a
                            href={attachment.uri}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center gap-2 text-primary hover:underline"
                          >
                            <Paperclip size={14} />
                            <span className="truncate max-w-[300px]">{label}</span>
                            <ExternalLink size={14} />
                          </a>
                          {attachment.mimeType && (
                            <span className="ml-2 text-xs uppercase text-muted-foreground">
                              {attachment.mimeType}
                            </span>
                          )}
                        </li>
                      )
                    })}
                  </ul>
                </div>
              )}
            </div>
          </section>

          {/* Supporters */}
          {initiative.supporters.length > 0 && (
            <section className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
              <h3 className="text-sm font-medium mb-3">
                Supporters ({initiative.supporters.length})
              </h3>
              <AvatarGroup
                avatars={initiative.supporters.map((address) => resolveAvatar(address) as string)}
              />
            </section>
          )}

          {/* Board Information */}
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

          {/* Status Badge */}
          <div className="rounded-lg border border-green-200 bg-green-50 p-3 dark:border-green-800 dark:bg-green-950/20">
            <p className="text-sm text-green-900 dark:text-green-200">
              <strong>Status:</strong> This initiative has been accepted and is now in development.
              Supporters can redeem their locked tokens after any release timelock period.
            </p>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
