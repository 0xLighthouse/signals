/**
 * Generates a Merkle tree for Signals Edge City Patagonia participants.
 *
 * Usage:
 *   pnpm dlx tsx apps/signals-token-factory/scripts-2/create-tree.ts
 */

import fs from 'node:fs/promises'
import path from 'node:path'
import { gzipSync } from 'node:zlib'
import { encodePacked, keccak256 } from 'viem'
import {
  type AllowlistOutput,
  type ParticipantRecord,
  buildMerkleTree,
} from '../../../packages/shared'

// Secret salt to prevent enumeration attacks - should be loaded from environment
const SECRET_SALT = process.env.EDGE_MERKLE_SECRET_SALT || 'CHANGE_THIS_IN_PRODUCTION'

if (SECRET_SALT === 'CHANGE_THIS_IN_PRODUCTION') {
  console.warn(
    '⚠️  WARNING: Using default salt. Set MERKLE_SECRET_SALT environment variable in production!',
  )
}

type ParticipantInput = {
  // A hash of the participant's profile identifer
  key: string
}

// Functional range generator
const range = (length: number) => Array.from({ length }, (_, i) => i)

// Configure for 25,000 participants
const PARTICIPANT_COUNT = 25_000

// Generate participants using functional programming style
const participants: ParticipantInput[] = range(PARTICIPANT_COUNT).map((i) => ({
  key: `participant-${i}`,
}))

/**
 * Hash a string identifier with secret salt to derive a deterministic participant ID.
 * The salt prevents enumeration attacks - without knowing the salt, attackers cannot
 * pre-compute valid participant IDs.
 */
const hashIdentifier = (key: string): bigint => {
  const idHex = keccak256(encodePacked(['string', 'string'], [key, SECRET_SALT]))
  return BigInt(idHex)
}

async function main() {
  // Convert participant inputs to records with derived IDs
  const records = participants.map((entry) => ({
    participantId: hashIdentifier(entry.key),
    key: entry.key,
  }))

  const uniqueCount = new Set(records.map((r) => r.participantId.toString())).size
  if (uniqueCount !== records.length) {
    throw new Error(
      `Detected ${records.length - uniqueCount} duplicate participant IDs. Adjust the identifier source or salt.`,
    )
  }

  console.log(`Building Merkle tree for ${records.length} participants…`)

  // Build tree using shared utilities
  const tree = buildMerkleTree(
    records.map<ParticipantRecord>((record) => ({
      participantId: record.participantId,
      label: record.key,
    })),
  )
  const root = tree.root

  console.log('\nMerkle root:', root)

  console.log('\nGenerating Merkle proofs…')
  const proofs = tree.getAllProofs()

  let invalidCount = 0
  for (const record of records) {
    const participantIdStr = record.participantId.toString()
    const proof = proofs[participantIdStr]
    if (!proof || !tree.verify(record.participantId, proof)) {
      invalidCount += 1
    }
  }

  if (invalidCount > 0) {
    throw new Error(`Failed to verify ${invalidCount} Merkle proofs`)
  }

  // Prepare output with metadata
  const output: AllowlistOutput = {
    root,
    proofs,
    meta: records.map((r) => ({
      participantId: r.participantId.toString(),
      label: r.key,
    })),
  }

  const outputPath = path.join(process.cwd(), '.generated', 'edge-proofs.json')

  // Ensure the .generated directory exists
  await fs.mkdir(path.dirname(outputPath), { recursive: true })
  const serialized = JSON.stringify(output, null, 2)
  await fs.writeFile(outputPath, serialized)

  const compressed = gzipSync(serialized, { level: 9 })
  const compressedPath = `${outputPath}.gz`
  await fs.writeFile(compressedPath, compressed)

  console.log('\n✓ Allowlist written to:', path.relative(process.cwd(), outputPath))
  console.log('✓ Compressed archive:', path.relative(process.cwd(), compressedPath))

  const proofDepths = Object.values(proofs).map((proof) => proof.length)
  const minDepth = Math.min(...proofDepths)
  const maxDepth = Math.max(...proofDepths)
  const avgDepth = proofDepths.reduce((sum, depth) => sum + depth, 0) / proofDepths.length

  console.log('\nProof depth overview:')
  console.table([
    { metric: 'participants', value: records.length },
    { metric: 'minDepth', value: minDepth },
    { metric: 'maxDepth', value: maxDepth },
    { metric: 'avgDepth', value: avgDepth.toFixed(2) },
  ])

  const sampleSize = Math.min(5, records.length)
  const sample = records.slice(0, sampleSize).map((r) => ({
    participantId: r.participantId.toString(),
    proofDepth: proofs[r.participantId.toString()].length,
  }))

  if (sample.length > 0) {
    console.log('\nSample proofs:')
    console.table(sample)
  }
}

main().catch((error) => {
  console.error('❌ Generation failed:', error)
  process.exit(1)
})
