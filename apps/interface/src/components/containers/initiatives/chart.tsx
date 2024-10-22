'use client'

import { CartesianGrid, Label, AreaChart, ReferenceLine, XAxis, YAxis, Area } from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { InitiativeDetails, Lock } from '@/lib/curves'
import { ChartTick, generateTicks } from '@/lib/chart'
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

interface Props {
  initiative?: InitiativeDetails
  existingLocks: Lock[]
  chartInterval: number
  acceptanceThreshold?: number | null
  amountInput?: number | null
  durationInput?: number
}

export const Chart: React.FC<Props> = ({
  initiative,
  existingLocks,
  chartInterval,
  acceptanceThreshold,
  amountInput,
  durationInput,
}) => {
  const [data, setData] = useState<ChartTick[]>([])

  useEffect(() => {
    if (!initiative || !acceptanceThreshold) return

    console.log('() RENDER')

    const options = { initiative, acceptanceThreshold, chartInterval }

    console.log('options', options)
    console.log('locks', existingLocks)

    // Update chart if input data is provided
    const chartData =
      amountInput && durationInput
        ? generateTicks(existingLocks, options, [
            {
              tokenAmount: amountInput,
              lockDuration: durationInput,
              createdAt: DateTime.now().toUnixInteger(),
              isWithdrawn: false,
            },
          ])
        : generateTicks(existingLocks, options)
    setData(chartData)
  }, [initiative, existingLocks, amountInput, durationInput, acceptanceThreshold, chartInterval])

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
