import { Card } from '@/components/ui/card'

type ImpactMetricsProps = {
  weightContributed: number
  progressDelta: number | null
  coordinationPeers: number | null
}

export function ImpactMetrics({
  weightContributed,
  progressDelta,
  coordinationPeers,
}: ImpactMetricsProps) {
  return (
    <section className="space-y-3">
      <h3 className="text-lg font-semibold">Your Impact</h3>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3">
        <Card className="p-4">
          <p className="text-sm text-muted-foreground">Weight contributed</p>
          <p className="text-xl font-semibold">{weightContributed.toLocaleString()}</p>
        </Card>
        <Card className="p-4">
          <p className="text-sm text-muted-foreground">Progress toward acceptance</p>
          <p className="text-xl font-semibold">
            {progressDelta ? `+${progressDelta.toFixed(1)}%` : '—'}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-sm text-muted-foreground">Coordination hint</p>
          <p className="text-sm">
            {weightContributed > 0 && coordinationPeers != null
              ? coordinationPeers <= 0
                ? 'This commitment alone reaches acceptance.'
                : `If ${coordinationPeers} other${coordinationPeers === 1 ? '' : 's'} commit at this level, this initiative will reach acceptance.`
              : 'Set an amount to see coordination impact.'}
          </p>
        </Card>
      </div>
    </section>
  )
}
