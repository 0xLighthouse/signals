import { Label } from '@/components/ui/label'
// Import Shadn UI card components
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Chart } from './initiatives/chart'

interface SubmissionLockDetailsProps {
  weight: number
  amount?: number
  duration?: number
  threshold?: number | null
}

export const SubmissionLockDetails: React.FC<SubmissionLockDetailsProps> = ({
  amount,
  duration,
  weight,
  threshold,
}) => {

  return (
    <Card className="dark:bg-neutral-800">
      <CardHeader>
        <CardTitle>Submission Lock Details</CardTitle>
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
              <Label className="w-1/5 flex items-center">Threshold</Label>
              <div className="w-4/5 flex items-center">
                <p>{threshold}</p>
              </div>
            </div>
            <div className="flex items-center">
              <Label className="w-1/5 flex items-center">Weight</Label>
              <div className="w-4/5 flex items-center">
                <p>{(weight / threshold).toFixed(2)}</p>
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
        <Chart amountInput={amount} durationInput={duration} acceptanceThreshold={threshold} />
      </CardContent>
    </Card>
  )
}
