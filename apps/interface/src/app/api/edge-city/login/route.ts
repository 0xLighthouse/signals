import { NextResponse } from 'next/server'
import { EdgeOSClient } from '@/lib/server/edgeos-client'
import { EdgeCityLoginResponse, EdgeCityProfile } from '@/config/edge-city'

type LoginRequest = {
  email: string
  code: string
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as LoginRequest
    const { email, code } = body

    if (!email || !code) {
      return NextResponse.json({ error: 'Email and verification code are required' }, { status: 400 })
    }

    const client = new EdgeOSClient()
    const loginResponse = (await client.login(email, code)) as EdgeCityLoginResponse
    const profile = (await client.getProfile(loginResponse.access_token)) as EdgeCityProfile

    return NextResponse.json({
      accessToken: loginResponse.access_token,
      profile,
    })
  } catch (error) {
    console.error(error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error completing login' },
      { status: 500 },
    )
  }
}
