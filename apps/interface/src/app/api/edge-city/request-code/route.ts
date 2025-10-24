import { NextResponse } from 'next/server'
import { EdgeOSClient } from '@/lib/server/edgeos-client'

export async function POST(request: Request) {
  try {
    const { email } = await request.json()

    if (!email) {
      return NextResponse.json({ error: 'Email is required' }, { status: 400 })
    }

    const client = new EdgeOSClient()
    await client.requestCode(email)

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error(error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error requesting code' },
      { status: 500 },
    )
  }
}
