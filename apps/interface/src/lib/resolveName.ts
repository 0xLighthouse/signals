import { shortAddress } from './utils'

// TODO: Resolve ENS name
export const resolveName = async (address: string) => {
  return shortAddress(address)
}
