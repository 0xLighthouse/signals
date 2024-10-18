import { NextResponse } from 'next/server'

export interface NormalisedInitiative {
  initiativeId: number
  title: string
  description: string
  weight: number
  proposer: string
  supporters: string[]
  createdAtTimestamp: number
  status: 'active' | 'accepted' | 'archived'
}

/**
 * GET /api/initiatives
 */
export const GET = () => {
  const initiatives: NormalisedInitiative[] = [
    {
      initiativeId: 0,
      title: 'Initiative 1',
      description: 'Description 1',
      weight: 100,
      status: 'active',
      proposer: '0x1234567890123456789012345678901234567890',
      supporters: [
        '0x1E6b84cdD0ea0e4B26bdAC857C5EdFc47FC5627a',
        '0x4147bfbC809baa168fA9375ce7D48d84eB27146B',
        '0x1E6b84cdD0ea0e4B26bdAC857C5EdFc47FC5627a',
        '0x4147bfbC809baa168fA9375ce7D48d84eB27146B',
      ],
      createdAtTimestamp: 1714857600,
    },
    {
      initiativeId: 1,
      title: 'Initiative 1',
      description: 'Description 1',
      weight: 100,
      status: 'active',
      proposer: '0x1234567890123456789012345678901234567890',
      supporters: [
        '0x1E6b84cdD0ea0e4B26bdAC857C5EdFc47FC5627a',
        '0x4147bfbC809baa168fA9375ce7D48d84eB27146B',
        '0x1E6b84cdD0ea0e4B26bdAC857C5EdFc47FC5627a',
        '0x4147bfbC809baa168fA9375ce7D48d84eB27146B',
      ],
      createdAtTimestamp: 1714857600,
    },
  ]
  return NextResponse.json(initiatives)
}
