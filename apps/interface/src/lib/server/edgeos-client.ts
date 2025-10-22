const DEFAULT_BASE_URL = 'https://api-citizen-portal.simplefi.tech'

export class EdgeOSClient {
  private baseUrl: string
  private apiKey: string

  constructor(options?: { baseUrl?: string; apiKey?: string }) {
    this.baseUrl = options?.baseUrl ?? process.env.EDGE_OS_BASE_URL ?? DEFAULT_BASE_URL
    this.apiKey = options?.apiKey ?? process.env.EDGE_OS_API_KEY ?? ''

    if (!this.apiKey) {
      throw new Error('EDGE_OS_API_KEY environment variable is not set')
    }
  }

  async requestCode(email: string) {
    const response = await fetch(`${this.baseUrl}/citizens/authenticate-third-party`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': this.apiKey,
      },
      body: JSON.stringify({ email }),
      cache: 'no-store',
    })

    if (!response.ok) {
      const payload = await response.text()
      throw new Error(`Request code failed (${response.status}): ${payload}`)
    }

    return response.json()
  }

  async login(email: string, code: string) {
    const url = new URL(`${this.baseUrl}/citizens/login`)
    url.searchParams.set('email', email)
    url.searchParams.set('code', code)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey,
      },
      cache: 'no-store',
    })

    if (!response.ok) {
      const payload = await response.text()
      throw new Error(`Login failed (${response.status}): ${payload}`)
    }

    return response.json()
  }

  async getProfile(token: string) {
    const response = await fetch(`${this.baseUrl}/citizens/profile`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-API-Key': this.apiKey,
      },
      cache: 'no-store',
    })

    if (!response.ok) {
      const payload = await response.text()
      throw new Error(`Get profile failed (${response.status}): ${payload}`)
    }

    return response.json()
  }
}
