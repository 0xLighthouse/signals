import React, { useState } from 'react'
import { ChevronUp, CheckCircle, Eye } from 'lucide-react'
import { cn, resolveAvatar, shortAddress, timeAgoWords } from '@/lib/utils'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'
import { Avatar, AvatarImage } from '@/components/ui/avatar'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'
import { AvatarGroup } from '@/components/ui/avatar-group'
import { ExternalLink, Paperclip } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useSupportDrawerStore } from '@/stores/useSupportDrawerStore'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { toast } from 'sonner'
import { useSignals } from '@/hooks/use-signals'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import { SignalsABI } from '../../../../../../packages/abis'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { AcceptInitiativeDialog } from '@/components/dialogs/accept-initiative-dialog'
import { AcceptedInitiativeDialog } from '@/components/dialogs/accepted-initiative-dialog'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'

import type { Initiative } from '@/indexers/api/types'

interface Props {
  initiative: Initiative
}

export const InitiativeCard: React.FC<Props> = ({ initiative }) => {
  const proposerName = useAsyncProp(
    resolveName(initiative.proposer),
    shortAddress(initiative.proposer),
  )
  const hasAttachments = initiative.attachments && initiative.attachments.length > 0

  const openDrawer = useSupportDrawerStore((state) => state.openDrawer)
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const { boardAddress } = useSignals()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)
  const [isAccepting, setIsAccepting] = useState(false)
  const [isAcceptDialogOpen, setIsAcceptDialogOpen] = useState(false)
  const [isAcceptedDialogOpen, setIsAcceptedDialogOpen] = useState(false)

  const supportPercentage = Number.parseFloat(String(initiative.support * 100))
  const canAccept = supportPercentage > 100 && initiative.status === 'active'
  const isAccepted = initiative.status === 'accepted'
  const isCancelled = initiative.status === 'archived'

  // Determine if proposer is showing a hex address (no ENS)
  const isHexProposer = proposerName === shortAddress(initiative.proposer)
  const displayName = isHexProposer ? 'Community Member' : proposerName

  const handleSupportClick = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    openDrawer(initiative)
  }

  const handleAcceptClick = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    setIsAcceptDialogOpen(true)
  }

  const handleAcceptConfirm = async () => {
    if (!boardAddress || !publicClient || !walletClient || !address) {
      toast('Web3 is not initialized')
      return
    }

    try {
      setIsAccepting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      const { request } = await publicClient.simulateContract({
        account: address,
        address: boardAddress as `0x${string}`,
        abi: SignalsABI,
        functionName: 'acceptInitiative',
        nonce,
        args: [BigInt(initiative.initiativeId)],
      })

      const hash = await walletClient.writeContract(request)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      toast('Initiative accepted!')
      if (boardAddress) {
        fetchInitiatives(boardAddress)
      }
    } catch (error) {
      console.error(error)
      if ((error as Error)?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error accepting initiative :(')
      }
    } finally {
      setIsAccepting(false)
    }
  }

  const handleAcceptedClick = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    ev.stopPropagation()
    setIsAcceptedDialogOpen(true)
  }

  // Status-based outer shell colour
  const statusShell = isAccepted
    ? 'bg-emerald-100 dark:bg-emerald-950/40'
    : isCancelled
      ? 'bg-stone-100 dark:bg-stone-900'
      : 'bg-indigo-100 dark:bg-indigo-950/40'

  const statusTimestamp = isAccepted
    ? 'text-emerald-500/70 dark:text-emerald-400/50'
    : isCancelled
      ? 'text-stone-400/70 dark:text-stone-500/50'
      : 'text-indigo-400/70 dark:text-indigo-300/50'

  return (
    <div className={cn('rounded-2xl p-2.5 pb-0', statusShell)}>
      {/* Inner white card */}
      <div className="flex flex-col gap-4 rounded-xl bg-white p-6 dark:bg-stone-950">
        {/* Proposer avatar + name */}
        <div className="flex items-center gap-2">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="inline-flex items-center gap-1.5">
                  <Avatar className="ring-2 ring-white dark:ring-stone-950">
                    <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
                  </Avatar>
                  <span className="text-xs text-muted-foreground">{displayName}</span>
                </span>
              </TooltipTrigger>
              {isHexProposer && (
                <TooltipContent>
                  <p>{shortAddress(initiative.proposer)}</p>
                </TooltipContent>
              )}
            </Tooltip>
          </TooltipProvider>
        </div>

        {/* Title — large and bold */}
        <h3 className="text-xl font-bold leading-snug">{initiative.title}</h3>

        {/* Description */}
        <p className="text-base text-muted-foreground line-clamp-3 break-words">{initiative.description}</p>

        {hasAttachments && (
          <div className="space-y-2">
            <p className="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
              Attachments
            </p>
            <ul className="space-y-1">
              {initiative.attachments.map(
                (
                  attachment: { description?: string; uri: string; mimeType?: string },
                  index: number,
                ) => {
                  const label = attachment.description || attachment.uri
                  return (
                    <li key={`${attachment.uri}-${index}`} className="text-xs">
                      <a
                        href={attachment.uri}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-primary hover:underline"
                      >
                        <Paperclip size={12} />
                        <span className="truncate max-w-[180px] sm:max-w-[220px]">{label}</span>
                        <ExternalLink size={12} />
                      </a>
                      {attachment.mimeType && (
                        <span className="ml-5 text-[10px] uppercase text-muted-foreground">
                          {attachment.mimeType}
                        </span>
                      )}
                    </li>
                  )
                },
              )}
            </ul>
          </div>
        )}

        {/* Progress Bar */}
        {!isAccepted && !isCancelled && (
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>{supportPercentage.toFixed(1)}% support</span>
              <span>100% to pass</span>
            </div>
            <div className="h-1.5 rounded-full bg-stone-100 dark:bg-stone-800 overflow-hidden">
              <div
                className={cn(
                  'h-full rounded-full bg-gradient-to-r from-indigo-500 to-violet-500 transition-all duration-500',
                  supportPercentage > 100 && 'animate-[progress-pulse_2s_ease-in-out_infinite]',
                )}
                style={{ width: `${Math.min(supportPercentage, 100)}%` }}
              />
            </div>
          </div>
        )}

        {/* Footer: avatars, incentive, actions */}
        <div className="flex items-center justify-between pt-1">
          <div className="flex items-center gap-3">
            <AvatarGroup
              avatars={
                initiative.supporters.length > 0
                  ? initiative.supporters.map((address: string) => resolveAvatar(address) as string)
                  : undefined
              }
            />
            <IncentiveDrawer initiative={initiative} />
          </div>

          <div className="flex items-center gap-2">
            {isAccepted ? (
              <Button
                variant="outline"
                size="sm"
                onClick={handleAcceptedClick}
                className="gap-1.5 border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950/20"
                aria-label="View accepted initiative details"
              >
                <Eye className="h-3.5 w-3.5 text-green-600 dark:text-green-400" />
                <span className="text-green-900 dark:text-green-200">View</span>
              </Button>
            ) : canAccept ? (
              <Button
                variant="outline"
                size="sm"
                onClick={handleAcceptClick}
                disabled={isAccepting}
                className="gap-1.5"
                aria-label="Accept initiative"
              >
                <CheckCircle className="h-3.5 w-3.5" />
                Accept
              </Button>
            ) : (
              <Button
                variant="outline"
                size="sm"
                onClick={handleSupportClick}
                className="gap-1.5"
              >
                <ChevronUp className="h-3.5 w-3.5" />
                Support
              </Button>
            )}
          </div>
        </div>
      </div>

      {/* Coloured bottom strip — timestamp visible in the shell */}
      <div className="flex items-center justify-center py-2">
        <span className={cn('text-[10px] font-semibold uppercase tracking-wider', statusTimestamp)}>
          {timeAgoWords(initiative.updatedAtTimestamp)}
        </span>
      </div>

      <AcceptInitiativeDialog
        open={isAcceptDialogOpen}
        onOpenChange={setIsAcceptDialogOpen}
        initiative={initiative}
        onAccept={handleAcceptConfirm}
        isAccepting={isAccepting}
      />
      {isAccepted && (
        <AcceptedInitiativeDialog
          open={isAcceptedDialogOpen}
          onOpenChange={setIsAcceptedDialogOpen}
          initiative={initiative}
        />
      )}
    </div>
  )
}
