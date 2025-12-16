/**
 * Configuration for claim features
 * Each claim feature is associated with a specific underlying token address
 */

export const claimsConfig = {
  /**
   * Edge City Claim token address
   * The Edge City Claim feature is only available when the board's underlying token matches this address
   */
  edgeCityTokenAddress: '0x9265e5df98c2aa68ab89fbc68ab2404553dfa07b' as `0x${string}`,
} as const
