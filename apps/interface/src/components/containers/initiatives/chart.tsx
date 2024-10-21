'use client'

import {
  CartesianGrid,
  Label,
  LabelList,
  AreaChart,
  ReferenceLine,
  XAxis,
  YAxis,
  Area,
} from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { calculateWeight, InitiativeDetails, Lock, Weight } from '@/lib/curves'
import { DateTime } from 'luxon'
import { use, useEffect, useState } from 'react'

export const description = 'A line chart with a custom label'

const chartConfig = {
  weight: {
    label: 'Weight',
    color: 'hsl(var(--chart-2))',
  },
  lock: {
    label: 'Lock',
    color: 'hsl(var(--chart-5))',
  },
} satisfies ChartConfig

/**
 * Given a round number  eg. 1000000, 500000, 20000
 * Normalise to 1M, 500k, 20k, etc
 */
const normaliseNumber = (value: number) => {
  const suffixes = ['', 'k', 'M', 'B', 'T']
  const suffixIndex = Math.floor(Math.log10(value) / 3)
  const suffix = suffixes[suffixIndex]
  // biome-ignore lint/style/useExponentiationOperator: <explanation>
  const normalisedValue = value / Math.pow(10, suffixIndex * 3)
  if (!normalisedValue) return ''
  return `${normalisedValue}${suffix}`
}

const normaliseWeights = (weights: Weight) => {
  return weights.map((w) => ({
    ...w,
    weight: Math.round(w.y),
    label: DateTime.fromSeconds(w.x).toRelative(),
  }))
}

interface Props {
  acceptanceThreshold?: number | null
  amountInput?: number
  durationInput?: number
}

export const Chart: React.FC<Props> = ({ amountInput, durationInput, acceptanceThreshold }) => {
  console.log('[Chart] acceptanceThreshold:', acceptanceThreshold)
  const [data, setData] = useState<Weight>([])
  const DECAY_TYPE_LINEAR = 0
  const DECAY_RATE = 0.9
  const LOCK_INTERVAL = 60 * 60 // 1 hour
  const CHART_INTERVAL = 60 * 60

  const createdAt = DateTime.fromISO('2024-10-22T00:00:00.000Z')

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

  // Run on the first render
  useEffect(() => {
    // @ts-ignore
    setData(normaliseWeights(weights))
  }, [weights])

  useEffect(() => {
    const startTime = DateTime.now().toUnixInteger() - CHART_INTERVAL * 2

    let existingData: Weight = calculateWeight(initiative, locks, CHART_INTERVAL, startTime)
    let inputData: Weight = []

    if (amountInput && durationInput) {
      //   const newLock: Lock = {
      //     tokenAmount: amountInput,
      //     lockDuration: durationInput,
      //     createdAt: DateTime.now().toUnixInteger(),
      //     withdrawn: false,
      //   }
      //   let lockWeight: Weight = calculateWeight(initiative, [newLock], CHART_INTERVAL, startTime)
      //   if (newData.length > lockWeight.length) {
      //     lockWeight = calculateWeight(
      //       initiative,
      //       [newLock],
      //       CHART_INTERVAL,
      //       startTime,
      //       newData[newData.length - 1].x,
      //     )
      //   } else if (newData.length < lockWeight.length) {
      //     newData = calculateWeight(
      //       initiative,
      //       locks,
      //       CHART_INTERVAL,
      //       startTime,
      //       lockWeight[lockWeight.length - 1].x,
      //     )
      //   }
      // }
      //   let chartData: Array<{label: string, baseWeight: number, thresholdWeight?: number, inputBase?: number, inputThreshold?: number}> = []
      //   for (let i = 0; i < newData.length; i++) {
      //     newData[i].lock = lockWeight[i].y
      //   }
      //   // ---- comunte the new array
      // setData(normaliseWeights(weights))
    }
  }, [amountInput, durationInput])

  return (
    <ChartContainer config={chartConfig}>
      <AreaChart accessibilityLayer data={data}>
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="visitors" hideLabel />}
        />
        <ReferenceLine y={acceptanceThreshold} strokeDasharray="3 3" strokeWidth={2}>
          <Label
            position="insideTopLeft"
            value={acceptanceThreshold}
            fill="red"
            offset={10}
            startOffset={100}
          />
        </ReferenceLine>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="label" />
        <YAxis tickFormatter={normaliseNumber} />

        <Area
          dataKey="lock"
          type="natural"
          strokeWidth={2}
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
        </Area>
        <Area
          dataKey="weight"
          type="natural"
          strokeWidth={2}
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
        </Area>
      </AreaChart>
    </ChartContainer>
  )
}
