import { Pool } from '@/indexers/api/types'

const resolveOutputTokens = (pool: Pool) => {
  const outputTokens: OutputToken[] = []
  outputTokens.push({
    key: 'currency0',
    label: `${pool.currency0.symbol}`,
  })
  outputTokens.push({
    key: 'currency1',
    label: `${pool.currency1.symbol}`,
  })
  outputTokens.push({
    key: 'mixed',
    label: `Mixed (50% ${pool.currency0.symbol}/${pool.currency1.symbol})`,
  })
  return outputTokens
}

type OutputTokenKey = 'mixed' | 'currency0' | 'currency1'

interface OutputToken {
  key: OutputTokenKey
  label: string
}

export { resolveOutputTokens, type OutputToken, type OutputTokenKey }
