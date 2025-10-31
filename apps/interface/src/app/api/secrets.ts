export const EDGE_CITY_SIGNER_PRIVATE_KEY = process.env.EDGE_CITY_SIGNER_PRIVATE_KEY as `0x${string}`
export const EDGE_CITY_SIGNER_ADDRESS = process.env.EDGE_CITY_SIGNER_ADDRESS as `0x${string}`

if (!EDGE_CITY_SIGNER_PRIVATE_KEY) {
  throw new Error('EDGE_CITY_SIGNER_PRIVATE_KEY is not set')
}

if (!EDGE_CITY_SIGNER_ADDRESS) {
  throw new Error('EDGE_CITY_SIGNER_ADDRESS is not set')
}
