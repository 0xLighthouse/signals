import React, { useState } from 'react'
import { ChevronUp, CheckCircle, Eye } from 'lucide-react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
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
  index: number
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
      console.log('Receipt:', receipt)
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

  const handleCardClick = (ev: React.MouseEvent<HTMLDivElement>) => {
    // Don't handle card clicks for accepted initiatives (button handles it)
    if (isAccepted) return

    // Don't open dialog if clicking on interactive elements
    const target = ev.target as HTMLElement
    if (
      target.closest('button') ||
      target.closest('a') ||
      target.closest('[role="button"]') ||
      target.closest('[data-slot="drawer-trigger"]')
    ) {
      return
    }
  }

  const handleAcceptedClick = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    ev.stopPropagation()
    setIsAcceptedDialogOpen(true)
  }

  // Status-based left border color
  const statusBorder = isAccepted
    ? 'border-l-4 border-l-emerald-500'
    : isCancelled
      ? 'border-l-4 border-l-stone-300 dark:border-l-stone-600'
      : 'border-l-4 border-l-indigo-500'

  return (
    <Card
      className={cn(
        'flex flex-col rounded-xl shadow-sm hover:shadow-md transition-shadow',
        statusBorder,
      )}
      onClick={isAccepted ? undefined : handleCardClick}
    >
      <CardHeader className="p-6 pb-0">
        {/* Proposer + timestamp */}
        <CardDescription className="flex items-center text-xs">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="inline-flex items-center">
                  <Avatar className="mr-1.5 ring-2 ring-indigo-200 dark:ring-indigo-800">
                    <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
                  </Avatar>
                  {displayName}
                </span>
              </TooltipTrigger>
              {isHexProposer && (
                <TooltipContent>
                  <p>{shortAddress(initiative.proposer)}</p>
                </TooltipContent>
              )}
            </Tooltip>
          </TooltipProvider>
          <span className="mx-1.5">·</span>
          {timeAgoWords(initiative.createdAtTimestamp)}
        </CardDescription>

        {/* Title */}
        <CardTitle>{initiative.title}</CardTitle>

        {/* Description */}
        <div>
          <p className="text-body line-clamp-3 break-words">{initiative.description}</p>
          {hasAttachments && (
            <div className="mt-3 space-y-2">
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
        </div>

        {/* Progress Bar */}
        {!isAccepted && !isCancelled && (
          <div className="space-y-1.5 mt-4">
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>{supportPercentage.toFixed(1)}% support</span>
              <span>100% to pass</span>
            </div>
            <div className="h-2 rounded-full bg-secondary overflow-hidden">
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
      </CardHeader>

      {/* Footer: avatars, incentive, actions */}
      <div className="flex items-center justify-between p-6">
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
          <CardDescription className="text-xs hidden sm:block">
            {timeAgoWords(initiative.updatedAtTimestamp)}
          </CardDescription>
          {isAccepted ? (
            <Button
              variant="outline"
              onClick={handleAcceptedClick}
              className="gap-1.5 border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950/20"
              aria-label="View accepted initiative details"
            >
              <Eye className="h-4 w-4 text-green-600 dark:text-green-400" />
              <span className="text-green-900 dark:text-green-200">View details</span>
            </Button>
          ) : canAccept ? (
            <Button
              variant="outline"
              onClick={handleAcceptClick}
              disabled={isAccepting}
              className="gap-1.5"
              aria-label="Accept initiative"
            >
              <CheckCircle className="h-4 w-4" />
              Accept
            </Button>
          ) : (
            <Button
              variant="outline"
              onClick={handleSupportClick}
              className="gap-1.5"
            >
              <ChevronUp className="h-4 w-4" />
              Support
            </Button>
          )}
        </div>
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
    </Card>
  )
}
