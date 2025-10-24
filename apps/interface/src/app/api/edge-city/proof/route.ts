import { NextResponse } from 'next/server'
import { getAllowlistProof } from '@/lib/server/edge-city-allowlist'

type ProofRequest = {
  participantId?: number | string
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as ProofRequest
    const participantId = body.participantId !== undefined ? Number(body.participantId) : NaN

    if (!Number.isInteger(participantId) || participantId < 0) {
      return NextResponse.json({ error: 'participantId is required' }, { status: 400 })
    }

    const { merkleRoot, proof } = await getAllowlistProof(participantId)

    if (!proof || proof.length === 0) {
      return NextResponse.json({ error: 'Participant not included in allowlist' }, { status: 404 })
    }

    return NextResponse.json({ merkleRoot, proof })
  } catch (error) {
    console.error(error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error fetching proof' },
      { status: 500 },
    )
  }
}
