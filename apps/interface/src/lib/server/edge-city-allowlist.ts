import path from 'path'
import { promises as fs } from 'fs'

type EdgeCityAllowlist = {
  root: `0x${string}`
  proofs: Record<string, `0x${string}`[]>
}

let cachedAllowlist: EdgeCityAllowlist | null = null

const resolveAllowlist = async (): Promise<EdgeCityAllowlist> => {
  if (cachedAllowlist) {
    return cachedAllowlist
  }

  const inlineJson = process.env.EDGE_CITY_ALLOWLIST_JSON
  if (inlineJson) {
    cachedAllowlist = JSON.parse(inlineJson) as EdgeCityAllowlist
    return cachedAllowlist!
  }

  const filePath = process.env.EDGE_CITY_ALLOWLIST_PATH
  if (!filePath) {
    throw new Error('Edge City allowlist data is not configured')
  }

  const absolutePath = path.isAbsolute(filePath) ? filePath : path.join(process.cwd(), filePath)
  const fileContents = await fs.readFile(absolutePath, 'utf-8')

  cachedAllowlist = JSON.parse(fileContents) as EdgeCityAllowlist
  return cachedAllowlist!
}

export const getAllowlistProof = async (participantId: number) => {
  const allowlist = await resolveAllowlist()
  const proof = allowlist.proofs[String(participantId)]
  return {
    merkleRoot: allowlist.root,
    proof: proof ?? null,
  }
}
