import { Label } from '@/components/ui/label'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Chart } from './initiatives/chart'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { CircleAlert } from 'lucide-react'
import { InitiativeDetails } from '@/lib/curves'

interface Props {
  initiative?: InitiativeDetails
  weight: number
  amount?: number
  duration?: number
  threshold?: number | null
}

export const SubmissionLockDetails: React.FC<Props> = ({
  initiative,
  amount,
  duration,
  weight,
  threshold,
}) => {
  return (
    <Card className="dark:bg-neutral-800">
      <CardHeader>
        <CardTitle>Impact</CardTitle>

        <Alert className="bg-blue-50 dark:bg-neutral-800">
          <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
          <AlertTitle>You will be locking XXXXX SGNK for XXX days.</AlertTitle>
          <AlertDescription>
            This will impact your ability to submit new initiatives.
          </AlertDescription>
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
          <>
            <div className="flex items-center">
              <Label className="w-1/5 flex items-center">Acceptance threshold</Label>
              <div className="w-4/5 flex items-center">
                <p>{threshold}</p>
              </div>
            </div>
            <div className="flex items-center">
              <Label className="w-1/5 flex items-center">Percentage</Label>
              <div className="w-4/5 flex items-center">
                <p>{((weight / threshold) * 100).toFixed(2)}%</p>
              </div>
            </div>
          </>
        )}
        <Chart
          initiative={initiative}
          acceptanceThreshold={threshold}
          locks={[]}
          chartInterval={1}
          amountInput={amount}
          durationInput={duration}
        />
      </CardContent>
    </Card>
  )
}
