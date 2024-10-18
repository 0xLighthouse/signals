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

export const description = 'A line chart with a custom label'

const chartData = [
  { browser: 'chrome', visitors: 275, fill: 'var(--color-chrome)' },
  { browser: 'safari', visitors: 200, fill: 'var(--color-safari)' },
  { browser: 'firefox', visitors: 187, fill: 'var(--color-firefox)' },
  { browser: 'edge', visitors: 173, fill: 'var(--color-edge)' },
  { browser: 'other', visitors: 90, fill: 'var(--color-other)' },
]

const chartConfig = {
  visitors: {
    label: 'Visitors',
    color: 'hsl(var(--chart-2))',
  },
  chrome: {
    label: 'Chrome',
    color: 'hsl(var(--chart-1))',
  },
  safari: {
    label: 'Safari',
    color: 'hsl(var(--chart-2))',
  },
  firefox: {
    label: 'Firefox',
    color: 'hsl(var(--chart-3))',
  },
  edge: {
    label: 'Edge',
    color: 'hsl(var(--chart-4))',
  },
  other: {
    label: 'Other',
    color: 'hsl(var(--chart-5))',
  },
} satisfies ChartConfig

export function Chart() {
  return (
    <ChartContainer config={chartConfig}>
      <LineChart
        accessibilityLayer
        data={chartData}
        margin={{
          top: 24,
          left: 24,
          right: 24,
        }}
      >
        {/* <CartesianGrid vertical={false} /> */}
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="visitors" hideLabel />}
        />
        <ReferenceLine
          y={200}
          //   stroke="hsl(var(--muted-foreground))"
          strokeDasharray="3 3"
          strokeWidth={1}
        >
          <Label
            position="insideBottomLeft"
            value="Acceptance threshold"
            offset={10}
            fill="hsl(var(--foreground))"
          />
          <Label
            position="insideTopLeft"
            value="12,343"
            className="text-lg"
            fill="hsl(var(--foreground))"
            offset={10}
            startOffset={100}
          />
        </ReferenceLine>

        <Line
          dataKey="visitors"
          type="natural"
          //   stroke="var(--color-visitors)"
          strokeWidth={2}
          dot={{
            fill: 'var(--color-visitors)',
          }}
          activeDot={{
            r: 6,
          }}
        >
          {/* <LabelList
            position="top"
            offset={12}
            className="fill-foreground"
            fontSize={12}
            dataKey="browser"
            formatter={(value: keyof typeof chartConfig) => chartConfig[value]?.label}
          /> */}
        </Line>
      </LineChart>
    </ChartContainer>
  )
}
