import { NormalisedInitiative } from '@/app/api/initiatives/route'
import React, { use } from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, resolveAvatar, shortAddress } from '@/lib/utils'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'
import { AddSupportDrawer } from '@/components/drawers/add-support-drawer'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { resolveName } from '@/lib/resolveName'
import { useAsyncProp } from '@/lib/useAsyncProp'

interface Props {
  initiative: NormalisedInitiative
  index: number
  isFirst: boolean
  isLast: boolean
}

const InitiativeCard: React.FC<Props> = ({ initiative, isFirst, isLast }) => {
  const proposerName = useAsyncProp(
    resolveName(initiative.proposer),
    shortAddress(initiative.proposer),
  )
  return (
    <Card
      className={cn(
        'flex',
        isFirst
          ? 'rounded-t-lg rounded-b-none border-b-0 '
          : isLast
            ? 'rounded-b-lg rounded-t-none'
            : 'rounded-none border-b-0',
      )}
    >
      <CardHeader className="w-3/5 p-6">
        <CardTitle>{initiative.title}</CardTitle>
        <CardDescription className="flex items-center">
          Proposed by
          <Avatar className="ml-2 mr-1">
            <AvatarImage src={resolveAvatar(initiative.proposer)} alt={initiative.proposer} />
          </Avatar>
          {proposerName}
        </CardDescription>
        <div>{initiative.description}</div>
      </CardHeader>
      <div className="w-2/5 p-6 flex justify-end gap-1">
        <IncentiveDrawer initiative={initiative} />
        <AddSupportDrawer initiative={initiative} />
      </div>
    </Card>
  )
}

export default InitiativeCard
