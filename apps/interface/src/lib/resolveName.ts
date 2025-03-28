import { shortAddress } from './utils'

interface QueryResponse {
  Domains: {
    Domain:
      | [
          {
            dappName: string
            name: string
            isPrimary: boolean
          },
        ]
      | null
  }
}

const THIRTY_MINUTES = 30 * 60

const applyNextReqCacheOpts = (options: object) => ({
  ...options,
  next: {
    // https://nextjs.org/docs/app/api-reference/functions/fetch#optionsnextrevalidate
    revalidate: THIRTY_MINUTES,
  },
})

export const resolveName = async (address: string) => {
  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: process.env.NEXT_PUBLIC_AIRSTACK_API_KEY,
    },
    body: JSON.stringify({
      query: `
        query GetENS {
          Domains(
            input: {filter: {owner: {_in: ["${address}"]}}, blockchain: ethereum}
          ) {
            Domain {
              name
              isPrimary
            }
          }
        }
      `,
      operationName: 'GetENS',
    }),
  }
  const { data, errors } = await fetch(
    'https://api.airstack.xyz/gql',
    applyNextReqCacheOpts(options),
  ).then((res) => res.json())

  if (errors) {
    console.log('resolveName() ERROR', errors)
  }
  if (!data) {
    throw new Error('Error fetching ENS metadata')
  }

  const { Domains } = data as QueryResponse

  const ens =
    Domains?.Domain && Domains.Domain.length > 1
      ? Domains.Domain?.find((domain) => domain.isPrimary)
      : Domains?.Domain?.[0]

  return ens ? ens.name : shortAddress(address)
}
