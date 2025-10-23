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

type ParticipantInput = {
  label: string
  weight: number
}

type ParticipantNode = ParticipantInput & {
  participantId: bigint
  participantIdHex: `0x${string}`
  leaf: `0x${string}`
}

const participants: ParticipantInput[] = [
  { label: 'some-hash-a', weight: 1 },
  { label: 'some-hash-b', weight: 1.5 },
  { label: 'some-hash-c', weight: 2 },
]

const toUint256Hex = (value: bigint): `0x${string}` => {
  return `0x${value.toString(16).padStart(64, '0')}`
}

const hashIdentifier = (label: string): bigint => {
  const idHex = keccak256(encodePacked(['string'], [label]))
  return BigInt(idHex)
}

const hashLeaf = (participantId: bigint): `0x${string}` => {
  return keccak256(encodePacked(['uint256'], [participantId]))
}

const hashPair = (a: `0x${string}`, b: `0x${string}`): `0x${string}` => {
  if (a === b) return a
  const [left, right] = a.toLowerCase() < b.toLowerCase() ? [a, b] : [b, a]
  return keccak256(encodePacked(['bytes32', 'bytes32'], [left, right]))
}

const buildMerkleTree = (leaves: `0x${string}`[]): `0x${string}`[][] => {
  if (leaves.length === 0) {
    throw new Error('Cannot build a Merkle tree with zero leaves')
  }

  const tree: `0x${string}`[][] = [leaves]
  let current = leaves

  while (current.length > 1) {
    const nextLayer: `0x${string}`[] = []

    for (let i = 0; i < current.length; i += 2) {
      const left = current[i]
      const right = current[i + 1]

      if (right === undefined) {
        nextLayer.push(left)
      } else {
        nextLayer.push(hashPair(left, right))
      }
    }

    tree.push(nextLayer)
    current = nextLayer
  }

  return tree
}

const getProof = (tree: `0x${string}`[][], leafIndex: number): `0x${string}`[] => {
  const proof: `0x${string}`[] = []
  let index = leafIndex

  for (let level = 0; level < tree.length - 1; level++) {
    const layer = tree[level]
    const pairIndex = index ^ 1

    if (pairIndex < layer.length) {
      proof.push(layer[pairIndex])
    }

    index = Math.floor(index / 2)
  }

  return proof
}

const verifyProof = (leaf: `0x${string}`, proof: `0x${string}`[], root: `0x${string}`) => {
  let computed = leaf
  for (const sibling of proof) {
    computed = hashPair(computed, sibling)
  }
  return computed.toLowerCase() === root.toLowerCase()
}

async function main() {
  const nodes: ParticipantNode[] = participants.map((entry) => {
    const participantId = hashIdentifier(entry.label)
    return {
      ...entry,
      participantId,
      participantIdHex: toUint256Hex(participantId),
      leaf: hashLeaf(participantId),
    }
  })

  const leaves = nodes.map((node) => node.leaf)
  const tree = buildMerkleTree(leaves)
  const root = tree.at(-1)?.[0]

  if (!root) throw new Error('Failed to compute Merkle root')

  const proofs: Record<string, `0x${string}`[]> = {}

  nodes.forEach((node, index) => {
    const proof = getProof(tree, index)
    const isValid = verifyProof(node.leaf, proof, root)

    if (!isValid) {
      throw new Error(`Invalid proof generated for ${node.label}`)
    }

    proofs[node.participantIdHex] = proof
  })

  const outputPath = path.join(
    process.cwd(),
    'apps',
    'signals-token-factory',
    'allowlists',
    'sample-edge-city.json',
  )

  const output = {
    root,
    proofs,
    meta: nodes.map(({ label, weight, participantIdHex }) => ({
      label,
      weight,
      participantId: participantIdHex,
    })),
  }

  await fs.writeFile(outputPath, JSON.stringify(output, null, 2))

  console.log('Sample Merkle root:', root)
  console.log('Proofs written to:', path.relative(process.cwd(), outputPath))
  console.table(
    nodes.map(({ label, weight, participantIdHex }) => ({
      label,
      weight,
      participantId: participantIdHex,
      proofDepth: proofs[participantIdHex].length,
    })),
  )
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
