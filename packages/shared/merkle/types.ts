export type ParticipantRecord = {
  participantId: bigint | number
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
  getProof: (participantId: number | bigint) => `0x${string}`[]
  verify: (participantId: number | bigint, proof: `0x${string}`[]) => boolean
  getAllProofs: () => Record<string, `0x${string}`[]>
}
