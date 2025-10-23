export type ParticipantRecord = {
  participantId: number
  weight?: number
  label?: string
}

export type AllowlistOutput = {
  root: `0x${string}`
  proofs: Record<string, `0x${string}`[]>
  meta?: Array<{
    participantId: string
    label?: string
    weight?: number
  }>
}

export type MerkleTreeResult = {
  root: `0x${string}`
  getProof: (participantId: number) => `0x${string}`[]
  verify: (participantId: number, proof: `0x${string}`[]) => boolean
  getAllProofs: () => Record<string, `0x${string}`[]>
}