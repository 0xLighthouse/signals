import path from 'path';
import { promises as fs } from 'fs';
import type { AllowlistOutput } from 'shared';
import { verifyProof, hashParticipantId } from 'shared';

type EdgeCityAllowlist = AllowlistOutput;

let cachedAllowlist: EdgeCityAllowlist | null = null;

const resolveAllowlist = async (): Promise<EdgeCityAllowlist> => {
  if (cachedAllowlist) {
    return cachedAllowlist;
  }

  const inlineJson = process.env.EDGE_CITY_ALLOWLIST_JSON;
  if (inlineJson) {
    cachedAllowlist = JSON.parse(inlineJson) as EdgeCityAllowlist;
    validateAllowlist(cachedAllowlist);
    return cachedAllowlist!;
  }

  const filePath = process.env.EDGE_CITY_ALLOWLIST_PATH;
  if (!filePath) {
    throw new Error('Edge City allowlist data is not configured');
  }

  const absolutePath = path.isAbsolute(filePath) ? filePath : path.join(process.cwd(), filePath);
  const fileContents = await fs.readFile(absolutePath, 'utf-8');

  cachedAllowlist = JSON.parse(fileContents) as EdgeCityAllowlist;
  validateAllowlist(cachedAllowlist);
  return cachedAllowlist!;
};

/**
 * Validate allowlist structure and optionally verify a sample proof
 */
function validateAllowlist(allowlist: EdgeCityAllowlist): void {
  if (!allowlist.root || !allowlist.proofs) {
    throw new Error('Invalid allowlist format: missing root or proofs');
  }

  // Verify a sample proof if any exist (helps catch format issues early)
  const sampleId = Object.keys(allowlist.proofs)[0];
  if (sampleId) {
    const participantId = Number(sampleId);
    const proof = allowlist.proofs[sampleId];

    if (!Number.isInteger(participantId) || participantId < 0) {
      console.warn(`Allowlist contains non-numeric participant ID: ${sampleId}`);
    }

    try {
      const isValid = verifyProof(participantId, proof, allowlist.root);
      if (!isValid) {
        console.warn(`Sample proof verification failed for participant ${sampleId}`);
      } else {
        console.log(`✓ Allowlist loaded and verified (root: ${allowlist.root.slice(0, 10)}...)`);
      }
    } catch (error) {
      console.warn('Could not verify sample proof:', error);
    }
  }
}

export const getAllowlistProof = async (participantId: number) => {
  const allowlist = await resolveAllowlist();

  // Preferred: decimal string keys (new format)
  const participantIdStr = String(participantId);
  let proof = allowlist.proofs[participantIdStr];

  // Legacy fallback: leaf-hash key equals keccak256(abi.encodePacked(uint256(participantId)))
  if (!proof) {
    const leafKey = hashParticipantId(participantId);
    proof = allowlist.proofs[leafKey];
    if (proof) {
      console.warn(`Found proof using legacy leaf-hash key format for participant ${participantId}`);
    }
  }

  // Extra fallback: hex-encoded uint256 (rare legacy shape)
  if (!proof) {
    const hexKey = `0x${BigInt(participantId).toString(16).padStart(64, '0')}`;
    proof = allowlist.proofs[hexKey];
    if (proof) {
      console.warn(`Found proof using legacy hex-uint256 key format for participant ${participantId}`);
    }
  }

  return {
    merkleRoot: allowlist.root,
    proof: proof ?? null,
  };
};
