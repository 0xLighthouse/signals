const ENABLE_CONTRIBUTIONS =
  (process.env.NEXT_PUBLIC_FEATURE_ENABLE_CONTRIBUTIONS ??
    process.env.FEATURE_ENABLE_CONTRIBUTIONS)?.toLowerCase() === 'true'

export const features = {
  enableContributions: ENABLE_CONTRIBUTIONS,
} as const

