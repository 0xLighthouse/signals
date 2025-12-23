import { Label } from '@/components/ui/label'
import { Slider } from '@/components/ui/slider'

type DurationSliderProps = {
  duration: number
  maxIntervals: number
  lockInterval?: number
  formatDurationLabel: (seconds: number) => string
  onDurationChange: (value: number) => void
}

export function DurationSlider({
  duration,
  maxIntervals,
  lockInterval,
  formatDurationLabel,
  onDurationChange,
}: DurationSliderProps) {
  return (
    <div className="flex items-center gap-4">
      <Label className="flex-shrink-0" htmlFor="duration">
        Duration
      </Label>
      <Slider
        value={[duration]}
        step={1}
        min={1}
        max={maxIntervals}
        onValueChange={(value) => onDurationChange(value[0])}
        className="flex-1"
      />
      <p className="flex-shrink-0 whitespace-nowrap text-sm">
        {`${duration} interval${duration !== 1 ? 's' : ''}`}
        {lockInterval ? ` (${formatDurationLabel(duration * lockInterval)})` : ''}
      </p>
    </div>
  )
}
