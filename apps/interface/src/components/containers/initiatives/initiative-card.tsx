import { NormalisedInitiative } from '@/app/api/initiatives/route'
import React from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn, shortAddress } from '@/lib/utils'
import { IncentiveDrawer } from '@/components/drawers/incentive-drawer'
import { AddSupportDrawer } from '@/components/drawers/add-support-drawer'

interface Props {
  initiative: NormalisedInitiative
  index: number
  isFirst: boolean
  isLast: boolean
}

const InitiativeCard: React.FC<Props> = ({ initiative, isFirst, isLast }) => {
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
        <CardDescription>Proposed by (AVATAR) {shortAddress(initiative.proposer)}</CardDescription>
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
