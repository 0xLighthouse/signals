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

import type { Initiative } from '@/indexers/api/types'

interface Props {
  initiative: Initiative
  index: number
  isFirst: boolean
  isLast: boolean
}

export const InitiativeCard: React.FC<Props> = ({ initiative, isFirst, isLast }) => {
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

  return (
    <Card
      className={cn(
        'flex flex-col',
        isFirst && isLast
          ? 'rounded-lg'
          : isFirst
            ? 'rounded-t-lg rounded-b-none border-b-0'
            : isLast
              ? 'rounded-b-lg rounded-t-none'
              : 'rounded-none border-b-0',
      )}
      onClick={isAccepted ? undefined : handleCardClick}
    >
      <div className="flex flex-col md:flex-row w-full">
        <CardHeader className="md:w-3/5 p-6 pb-0">
          <CardTitle>{initiative.title}</CardTitle>
          <CardDescription className="flex items-center text-xs">
            <span className="hidden sm:block">Proposed by</span>
            <Avatar className="sm:ml-1 mr-1">
              <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
            </Avatar>
            {proposerName}, {timeAgoWords(initiative.createdAtTimestamp)}
          </CardDescription>
          <div>
            <p className="text-body line-clamp-4 break-words">{initiative.description}</p>
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
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-1 h-[80px]">
            <IncentiveDrawer initiative={initiative} />
            {isAccepted ? (
              <Button
                variant="outline"
                onClick={handleAcceptedClick}
                className="flex flex-col items-center min-w-[80px] h-full border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950/20 cursor-pointer"
                aria-label="View accepted initiative details"
              >
                <Eye className="h-6 w-6 -mt-1 text-green-600 dark:text-green-400" />
                <span className="text-xs text-green-900 dark:text-green-200">View details</span>
              </Button>
            ) : canAccept ? (
              <Button
                variant="outline"
                onClick={handleAcceptClick}
                disabled={isAccepting}
                className="flex flex-col items-center min-w-[80px] h-full"
                aria-label="Accept initiative"
              >
                <CheckCircle className="h-6 w-6 -mt-1" />
                <span className="text-xs">Accept</span>
              </Button>
            ) : (
              <Button
                variant="outline"
                onClick={handleSupportClick}
                className="flex flex-col items-center min-w-[80px] h-full"
              >
                <ChevronUp className="h-6 w-6 -mt-1" />
                <span className="text-xs">{supportPercentage.toFixed(2)}%</span>
              </Button>
            )}
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6">
        <AvatarGroup
          avatars={
            initiative.supporters.length > 0
              ? initiative.supporters.map((address: string) => resolveAvatar(address) as string)
              : undefined
          }
        />
        <CardDescription className="text-xs">
          Last activity, {timeAgoWords(initiative.updatedAtTimestamp)}
        </CardDescription>
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
