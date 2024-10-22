'use client'

import { CartesianGrid, Label, AreaChart, ReferenceLine, XAxis, YAxis, Area } from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { calculateWeight, getDefaultEnd, InitiativeDetails, Lock, Weight } from '@/lib/curves'
import { DateTime } from 'luxon'
import { useEffect, useState } from 'react'
import { normaliseNumber } from '@/lib/utils'

export const description = 'A line chart with a custom label'

const chartConfig = {
  existingBase: {
    label: 'Current Weight',
    color: 'hsl(var(--chart-1))',
  },
  existingThreshold: {
    label: 'Weight Exceeding Threshold',
    color: 'hsl(var(--chart-2))',
  },
  inputBase: {
    label: 'New Weight',
    color: 'hsl(var(--chart-3))',
  },
  inputThreshold: {
    label: 'New Weight Exceeding Threshold',
    color: 'hsl(var(--chart-4))',
  },
} satisfies ChartConfig

const normaliseWeights = (weights: Weight) => {
  return weights.map((w) => ({
    ...w,
    weight: Math.round(w.y),
    label: DateTime.fromSeconds(w.x).toRelative(),
  }))
}

interface SignalsTickItem {
  label: string
  existingBase: number
  existingThreshold?: number
  inputBase?: number
  inputThreshold?: number
}

interface Props {
  initiative?: InitiativeDetails
  locks: Lock[]
  chartInterval: number
  acceptanceThreshold?: number | null
  amountInput?: number | null
  durationInput?: number
}

const generateTicks = (
  existingData: Lock[],
  {
    initiative,
    acceptanceThreshold,
    chartInterval,
  }: { initiative: InitiativeDetails; acceptanceThreshold: number; chartInterval: number },
  newLock: Lock[] = [],
): SignalsTickItem[] => {
  const startTime: number = DateTime.now().toUnixInteger() - chartInterval * 2
  const endTime: number = Math.max(
    getDefaultEnd(existingData, initiative.lockInterval),
    getDefaultEnd(newLock, initiative.lockInterval),
  )

  const normalisedExistingData = normaliseWeights(
    calculateWeight(initiative, existingData, chartInterval, startTime, endTime),
  )
  const normalisedInputData = normaliseWeights(
    calculateWeight(initiative, newLock, chartInterval, startTime, endTime),
  )

  const ticks: SignalsTickItem[] = []

  for (let i = 0; i < normalisedExistingData.length; i++) {
    const existingWeight = normalisedExistingData[i].y
    const inputWeight = normalisedInputData[i].y

    const tick: SignalsTickItem = {
      label: normalisedExistingData[i].label,
      existingBase: 0,
    }

    // If the existing weight is above the acceptance threshold, we need to split it
    if (existingWeight > acceptanceThreshold) {
      tick.existingBase = acceptanceThreshold
      tick.existingThreshold = existingWeight - acceptanceThreshold

      // If there is input weight, it must all be above the threshold
      if (inputWeight > 0) {
        tick.inputThreshold = inputWeight
      }
    } else {
      // Otherwise, all existing weight is below the threshold
      tick.existingBase = existingWeight

      // If there is input weight, we need to split it
      if (inputWeight > 0) {
        if (existingWeight + inputWeight > acceptanceThreshold) {
          tick.inputBase = acceptanceThreshold - existingWeight
          tick.inputThreshold = existingWeight + inputWeight - acceptanceThreshold - tick.inputBase
        } else {
          tick.inputBase = inputWeight
        }
      }
    }

    ticks.push(tick)
  }

  return ticks
}

export const Chart: React.FC<Props> = ({
  initiative,
  locks,
  chartInterval,
  acceptanceThreshold,
  amountInput,
  durationInput,
}) => {
  const [data, setData] = useState<SignalsTickItem[]>([])

  useEffect(() => {
    if (!initiative || !acceptanceThreshold) return

    const options = { initiative, acceptanceThreshold, chartInterval }

    // Update chart if input data is provided
    const chartData =
      amountInput && durationInput
        ? generateTicks(locks, options, [
            {
              tokenAmount: amountInput,
              lockDuration: durationInput,
              createdAt: DateTime.now().toUnixInteger(),
              withdrawn: false,
            },
          ])
        : generateTicks(locks, options)

    setData(chartData)
  }, [initiative, locks, amountInput, durationInput, acceptanceThreshold, chartInterval])

  return (
    <ChartContainer config={chartConfig}>
      <AreaChart accessibilityLayer data={data}>
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="visitors" hideLabel />}
        />
        <ReferenceLine y={acceptanceThreshold || 0} strokeWidth={3} strokeDasharray="3 3">
          <Label
            position={'left'}
            value={acceptanceThreshold || 0}
            fill="green"
            // offset={10}
            // startOffset={100}
          />
        </ReferenceLine>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="label" />
        <YAxis tickFormatter={normaliseNumber} />
        <Area
          dataKey="existingBase"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        />
        <Area
          dataKey="existingThreshold"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        />
        <Area
          dataKey="inputBase"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        />
        <Area
          dataKey="inputThreshold"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        />
      </AreaChart>
    </ChartContainer>
  )
}
