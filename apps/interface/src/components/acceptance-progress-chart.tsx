import { Label } from '@/components/ui/label'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Chart } from './containers/initiatives/chart'
import { Alert, AlertTitle } from './ui/alert'
import { CircleAlert } from 'lucide-react'
import { InitiativeDetails } from '@/lib/curves'
import { useSignals } from '@/hooks/use-signals'

import { AvatarGroup } from './ui/avatar-group'
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

export const AcceptanceProgressChart: React.FC<Props> = ({
  initiative,
  amount,
  duration,
  threshold,
  existingLocks,
  supporters = [],
  proposeNewInitiative = false,
  supportInitiative = false,
}) => {
  const { underlyingSymbol: symbol, underlyingDecimals: decimals } = useSignals()

  return (
    <Card className="dark:bg-stone-800 border-0 shadow-none">
      <CardHeader className="px-0">
        <CardTitle>Preview</CardTitle>
      </CardHeader>
      {supportInitiative && (
        <CardContent className="px-0">
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
