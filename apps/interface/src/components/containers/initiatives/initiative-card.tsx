import React from 'react'
import { ChevronUp } from 'lucide-react'
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

import type { Initiative } from 'indexers/src/api/types'

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
                  {initiative.attachments.map((attachment, index) => {
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
                  })}
                </ul>
              </div>
            )}
          </div>
        </CardHeader>
        <div className="md:w-2/5 p-6 pb-0 flex justify-end items-center">
          <div className="flex gap-1 h-[80px]">
            <IncentiveDrawer initiative={initiative} />
            <Button
              variant="outline"
              full
              size="md"
              onClick={handleSupportClick}
              className="flex flex-col items-center min-w-[80px]"
            >
              <ChevronUp className="h-6 w-6 -mt-1" />
              <span className="text-xs">
                {Number.parseFloat(String(initiative.support * 100)).toFixed(2)}%
              </span>
            </Button>
          </div>
        </div>
      </div>
      <div className="flex justify-between p-6">
        <AvatarGroup
          avatars={
            initiative.supporters.length > 0
              ? initiative.supporters.map((address) => resolveAvatar(address) as string)
              : undefined
          }
        />
        <CardDescription className="text-xs">
          Last activity, {timeAgoWords(initiative.updatedAtTimestamp)}
        </CardDescription>
      </div>
    </Card>
  )
}
