import { Label } from '@/components/ui/label'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Chart } from './initiatives/chart'
import { Alert, AlertTitle } from '../ui/alert'
import { CircleAlert } from 'lucide-react'
import { InitiativeDetails } from '@/lib/curves'
import { useUnderlying } from '@/contexts/ContractContext'

import { AvatarGroup } from '../ui/avatar-group'
import { resolveAvatar } from '@/lib/utils'
import { InitiativeLock } from '@/indexers/api/types'

interface Props {
  initiative: InitiativeDetails | undefined
  supporters?: string[]
  amount?: number | null
  duration?: number
  threshold?: number | null
  existingLocks: InitiativeLock[]
  proposeNewInitiative?: boolean
  supportInitiative?: boolean
}

export const SubmissionLockDetails: React.FC<Props> = ({
  initiative,
  amount,
  duration,
  threshold,
  existingLocks,
  supporters = [],
  proposeNewInitiative = false,
  supportInitiative = false,
}) => {
  const { symbol, decimals } = useUnderlying()

  const weight = amount ? amount * (duration || 1) : 0

  return (
    <Card className="dark:bg-neutral-800">
      <CardHeader>
        <CardTitle>Impact</CardTitle>
        {proposeNewInitiative && (
          <Alert className="bg-blue-50 dark:bg-neutral-800">
            <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
            <AlertTitle>You will add a new initative.</AlertTitle>
          </Alert>
        )}
        {supportInitiative && (
          <Alert className="bg-blue-50 dark:bg-neutral-800">
            <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
            <AlertTitle>
              You will lock {amount} ({symbol}) for {duration} day{duration !== 1 ? 's' : ''}.
            </AlertTitle>
          </Alert>
        )}
      </CardHeader>
      {supportInitiative && (
        <CardContent>
          {supporters?.length > 0 && (
            <div className="flex items-center mb-2">
              <Label className="w-3/4 flex items-center">Supporters:</Label>
              <div className="w-3/4 flex items-center">
                <AvatarGroup
                  avatars={
                    supporters?.length > 0
                      ? supporters.map((address) => resolveAvatar(address) as string)
                      : undefined
                  }
                />
              </div>
            </div>
          )}
          <div className="flex items-center mb-2">
            <Label className="w-3/4 flex items-center">Weight to contribute:</Label>
            <div className="w-3/4 flex items-center">
              <p>{weight}</p>
            </div>
          </div>
          <div className="flex items-center">
            <Label className="w-3/4 flex items-center">Progress towards acceptance:</Label>
            <div className="w-3/4 flex items-center">
              <p>+{((weight / (threshold || 1)) * 100).toFixed(2)}%</p>
            </div>
          </div>
          <Chart
            initiative={initiative}
            acceptanceThreshold={threshold}
            existingLocks={existingLocks}
            amountInput={amount}
            durationInput={duration}
            decimals={decimals || 1}
          />
        </CardContent>
      )}
    </Card>
  )
}
