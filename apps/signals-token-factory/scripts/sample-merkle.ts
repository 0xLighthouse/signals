/**
 * Sample Merkle tree generator for Edge City participants.
 *
 * Usage:
 *   pnpm dlx tsx apps/signals-token-factory/scripts/sample-merkle.ts
 *
 * The script:
 *   - hashes friendly identifiers into uint256 participant IDs
 *   - builds a sorted Merkle tree using keccak256 and abi.encodePacked semantics
 *   - verifies each proof locally
 *   - writes the resulting root + proof mapping to
 *       apps/signals-token-factory/allowlists/sample-edge-city.json
 */

import fs from 'node:fs/promises'
import path from 'node:path'
import { keccak256, encodePacked } from 'viem'
import { buildMerkleTree, type ParticipantRecord, type AllowlistOutput } from '../../../packages/shared'

type ParticipantInput = {
  label: string
  weight: number
}

const participants: ParticipantInput[] = [
  { label: 'some-hash-a', weight: 1 },
  { label: 'some-hash-b', weight: 1.5 },
  { label: 'some-hash-c', weight: 2 },
]

/**
 * Hash a string identifier to derive a deterministic participant ID.
 * This matches the convention used in the sample data.
 */
const hashIdentifier = (label: string): number => {
  const idHex = keccak256(encodePacked(['string'], [label]))
  // Convert to number - in production, you'd use actual Edge City participant IDs
  return Number(BigInt(idHex) % BigInt(1000000))
}

async function main() {
  // Convert participant inputs to records with derived IDs
  const records: ParticipantRecord[] = participants.map((entry) => ({
    participantId: hashIdentifier(entry.label),
    weight: entry.weight,
    label: entry.label,
  }))

  console.log('Building Merkle tree for participants:')
  console.table(records.map(r => ({
    label: r.label,
    participantId: r.participantId,
    weight: r.weight
  })))

  // Build tree using shared utilities
  const tree = buildMerkleTree(records)
  const root = tree.root

  console.log('\nMerkle root:', root)

  // Generate and verify all proofs
  const proofs: Record<string, `0x${string}`[]> = {}
  let allValid = true

  for (const record of records) {
    const participantIdStr = String(record.participantId)

    try {
      const proof = tree.getProof(record.participantId)
      const isValid = tree.verify(record.participantId, proof)

      if (!isValid) {
        console.error(`❌ Invalid proof generated for ${record.label} (ID: ${record.participantId})`)
        allValid = false
      } else {
        console.log(`✓ Valid proof for ${record.label} (ID: ${record.participantId}, depth: ${proof.length})`)
      }

      proofs[participantIdStr] = proof
    } catch (error) {
      console.error(`❌ Failed to generate proof for ${record.label}:`, error)
      allValid = false
    }
  }

  if (!allValid) {
    throw new Error('Some proofs failed verification')
  }

  // Prepare output with metadata
  const output: AllowlistOutput = {
    root,
    proofs,
    meta: records.map(r => ({
      participantId: String(r.participantId),
      label: r.label,
      weight: r.weight,
    })),
  }

  const outputPath = path.join(
    process.cwd(),
    'apps',
    'signals-token-factory',
    'allowlists',
    'sample-edge-city.json',
  )

  await fs.writeFile(outputPath, JSON.stringify(output, null, 2))

  console.log('\n✓ Allowlist written to:', path.relative(process.cwd(), outputPath))
  console.log('\nProof summary:')
  console.table(
    records.map(r => ({
      label: r.label,
      participantId: r.participantId,
      weight: r.weight,
      proofDepth: proofs[String(r.participantId)].length,
    })),
  )
}

main().catch((error) => {
  console.error('❌ Generation failed:', error)
  process.exit(1)
})
