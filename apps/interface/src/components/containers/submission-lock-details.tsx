import { Label } from '@/components/ui/label'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Chart } from './initiatives/chart'
import { Alert, AlertTitle } from '../ui/alert'
import { CircleAlert } from 'lucide-react'
import { InitiativeDetails } from '@/lib/curves'
import { useUnderlying } from '@/contexts/ContractContext'
import { Lock } from '@/lib/curves'

interface Props {
  initiative: InitiativeDetails | undefined
  weight: number
  amount?: number | null
  duration?: number
  threshold?: number | null
  existingLocks: Lock[]
}

export const SubmissionLockDetails: React.FC<Props> = ({
  initiative,
  amount,
  duration,
  weight,
  threshold,
  existingLocks,
}) => {
  const { symbol } = useUnderlying()

  return (
    <Card className="dark:bg-neutral-800">
      <CardHeader>
        <CardTitle>Impact</CardTitle>

        <Alert className="bg-blue-50 dark:bg-neutral-800">
          <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
          <AlertTitle>
            You will be locking {amount} ({symbol}) for {duration} XXXXX.
          </AlertTitle>
        </Alert>
      </CardHeader>
      <CardContent>
        <div className="flex items-center">
          <Label className="w-1/5 flex items-center">Weight</Label>
          <div className="w-4/5 flex items-center">
            <p>{weight}</p>
          </div>
        </div>
        {threshold && threshold > 0 && (
          <div className="flex items-center">
            <Label className="w-1/5 flex items-center">
              Your contribution towards the acceptance threshold
            </Label>
            <div className="w-4/5 flex items-center">
              <p>{((weight / threshold) * 100).toFixed(2)}%</p>
            </div>
          </div>
        )}
        <Chart
          // @ts-ignore TODO: WILL FIX THIS SOON
          initiative={initiative}
          acceptanceThreshold={threshold}
          existingLocks={existingLocks}
          chartInterval={60 * 60}
          amountInput={amount}
          durationInput={duration}
        />
      </CardContent>
    </Card>
  )
}
