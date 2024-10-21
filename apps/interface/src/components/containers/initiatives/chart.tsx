'use client'

import {
  CartesianGrid,
  Label,
  LabelList,
  Line,
  LineChart,
  ReferenceLine,
  XAxis,
  YAxis,
} from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { calculateWeight, InitiativeDetails, Lock, Weight } from '@/lib/curves'
import { DateTime } from 'luxon'

export const description = 'A line chart with a custom label'

const chartConfig = {
  weight: {
    label: 'Weight',
    color: 'hsl(var(--chart-2))',
  },
  other: {
    label: 'Other',
    color: 'hsl(var(--chart-5))',
  },
} satisfies ChartConfig

const normaliseWeights = (weights: Weight) => {
  return weights.map((w) => ({
    ...w,
    weight: Math.round(w.y),
    label: DateTime.fromSeconds(w.x).toRelative(),
  }))
}

export function Chart() {
  const DECAY_TYPE_LINEAR = 0
  const DECAY_RATE = 0.9
  const LOCK_INTERVAL = 60 * 60 // 1 hour

  const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')

  const initiative: InitiativeDetails = {
    createdAt: createdAt.toUnixInteger(),
    lockInterval: LOCK_INTERVAL,
    decayCurveType: DECAY_TYPE_LINEAR,
    decayCurveParameters: [DECAY_RATE],
  }

  const locks: Lock[] = []
  locks.push({
    tokenAmount: 30_000, // Lock 50,000 Gov tokens
    lockDuration: 10,
    createdAt: createdAt.plus({ hours: 1 }).toUnixInteger(),
    withdrawn: false,
  })
  locks.push({
    tokenAmount: 40_000, // Lock 50,000 Gov tokens
    lockDuration: 10,
    createdAt: createdAt.plus({ hours: 3 }).toUnixInteger(),
    withdrawn: false,
  })
  locks.push({
    tokenAmount: 50_000, // Lock 50,000 Gov tokens
    lockDuration: 10,
    createdAt: createdAt.plus({ hours: 7 }).toUnixInteger(),
    withdrawn: false,
  })

  const weights = calculateWeight(initiative, locks, LOCK_INTERVAL)

  const acceptanceThreshold = 200_000

  return (
    <ChartContainer config={chartConfig}>
      <LineChart
        accessibilityLayer
        data={normaliseWeights(weights)}
        margin={{
          top: 24,
          left: 24,
          right: 24,
        }}
      >
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="visitors" hideLabel />}
        />
        <ReferenceLine y={acceptanceThreshold} strokeDasharray="3 3" strokeWidth={2}>
          <Label
            position="insideBottomLeft"
            value="Acceptance threshold"
            offset={10}
            fill="hsl(var(--foreground))"
          />
          <Label
            position="insideTopLeft"
            value={acceptanceThreshold.toLocaleString()}
            className="text-lg"
            fill="hsl(var(--foreground))"
            offset={10}
            startOffset={100}
          />
        </ReferenceLine>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="label" />
        <YAxis />
        <Line
          dataKey="weight"
          type="natural"
          strokeWidth={2}
          dot={{
            fill: 'var(--color-weight)',
          }}
          activeDot={{
            r: 6,
          }}
        >
          <LabelList
            position="bottom"
            offset={12}
            className="fill-foreground"
            fontSize={12}
            dataKey="x"
            formatter={(value: keyof typeof chartConfig) => chartConfig[value]?.label}
          />
        </Line>
      </LineChart>
    </ChartContainer>
  )
}
