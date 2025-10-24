import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { encodePacked, keccak256 } from 'viem';
import type { ParticipantRecord, MerkleTreeResult } from './types';

/**
 * Hash a participant ID to match Solidity's keccak256(abi.encodePacked(uint256))
 */
export function hashParticipantId(participantId: number | bigint): `0x${string}` {
  const id = BigInt(participantId);
  return keccak256(encodePacked(['uint256'], [id]));
}

/**
 * Build a Merkle tree from participant records using OpenZeppelin's StandardMerkleTree.
 * - Leaves derive from keccak256(abi.encodePacked(uint256(participantId))) equivalently by passing ['uint256'] values.
 * - Pairing is sorted to match on-chain verification.
 */
export function buildMerkleTree(participants: ParticipantRecord[]): MerkleTreeResult {
  if (participants.length === 0) {
    throw new Error('Cannot build Merkle tree with zero participants');
  }

  // Build tree using participants' uint256 IDs. StandardMerkleTree hashes entries with Solidity ABI rules.
  const entries = participants.map((p) => [BigInt(p.participantId)]);
  const tree = StandardMerkleTree.of(entries, ['uint256']);

  // Lookup map for fast membership/proof generation
  const participantMap = new Map(participants.map((p) => [p.participantId, true]));

  return {
    root: tree.root as `0x${string}`,

    getProof: (participantId: number): `0x${string}`[] => {
      if (!participantMap.get(participantId)) {
        throw new Error(`Participant ID ${participantId} not found in tree`);
      }
      const entry = [BigInt(participantId)];
      try {
        const proof = tree.getProof(entry);
        return proof as `0x${string}`[];
      } catch (error) {
        throw new Error(`Failed to generate proof for participant ${participantId}: ${error}`);
      }
    },

    verify: (participantId: number, proof: `0x${string}`[]): boolean => {
      if (!participantMap.get(participantId)) return false;
      const entry = [BigInt(participantId)];
      try {
        return StandardMerkleTree.verify(tree.root, ['uint256'], entry, proof);
      } catch {
        return false;
      }
    },

    getAllProofs: (): Record<string, `0x${string}`[]> => {
      const proofs: Record<string, `0x${string}`[]> = {};
      for (const participant of participants) {
        const participantIdStr = String(participant.participantId);
        try {
          proofs[participantIdStr] = tree.getProof([BigInt(participant.participantId)]) as `0x${string}`[];
        } catch (error) {
          // Non-fatal: continue collecting other proofs
          // eslint-disable-next-line no-console
          console.error(`Failed to generate proof for participant ${participantIdStr}:`, error);
        }
      }
      return proofs;
    },
  };
}

/**
 * Verify a Merkle proof against a root without rebuilding the tree.
 * Useful for validating loaded allowlist data.
 */
export function verifyProof(
  participantId: number,
  proof: `0x${string}`[],
  root: `0x${string}`
): boolean {
  const entry = [BigInt(participantId)];
  try {
    return StandardMerkleTree.verify(root, ['uint256'], entry, proof);
  } catch {
    return false;
  }
}