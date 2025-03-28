'use client'

type StatItemProps = {
  label: string
  value: string | number
}

export const StatItem = ({ label, value }: StatItemProps) => {
  return (
    <div className="bg-neutral-100 dark:bg-neutral-800 p-4 rounded-lg">
      <p className="text-sm text-neutral-500 dark:text-neutral-400">{label}</p>
      <p className="text-2xl font-bold">{value}</p>
    </div>
  )
}

type StatsDisplayProps = {
  stats: StatItemProps[]
  className?: string
}

export const StatsDisplay = ({ stats, className = '' }: StatsDisplayProps) => {
  return (
    <div className={`grid grid-cols-1 md:grid-cols-3 gap-4 ${className}`}>
      {stats.map((stat, index) => (
        <StatItem key={`stat-${index}`} label={stat.label} value={stat.value} />
      ))}
    </div>
  )
}
