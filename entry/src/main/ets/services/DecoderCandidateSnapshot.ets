export interface DecoderCandidate {
  codec: string;
  recommendedAvailable: boolean;
  recommendedIsHardware: boolean;
  hardwareAvailable: boolean;
}

export interface DecoderCandidateSnapshot {
  state: string;
  scope: string;
  surfaceBindingVerified: boolean;
  zeroCopyProven: boolean;
  candidates: DecoderCandidate[];
}

interface DecoderCapabilityResponse {
  capabilities: DecoderCandidate[];
}

export function unavailableDecoderCandidateSnapshot(): DecoderCandidateSnapshot {
  return {
    state: 'unavailable',
    scope: 'runtime_capability_only',
    surfaceBindingVerified: false,
    zeroCopyProven: false,
    candidates: []
  };
}

/** Project untrusted metadata only; capability discovery is not Surface or zero-copy evidence. */
export function projectDecoderCandidateSnapshot(json: string): DecoderCandidateSnapshot {
  const result: DecoderCandidateSnapshot = unavailableDecoderCandidateSnapshot();
  if (typeof json !== 'string' || json.length > 65536) {
    return result;
  }
  try {
    const source = JSON.parse(json) as DecoderCapabilityResponse | null;
    if (source === null || typeof source !== 'object' || Array.isArray(source) ||
      !Array.isArray(source.capabilities) || source.capabilities.length > 16) {
      return result;
    }
    let h264: DecoderCandidate | undefined = undefined;
    let h265: DecoderCandidate | undefined = undefined;
    for (let i = 0; i < source.capabilities.length; i++) {
      const row: DecoderCandidate | null = source.capabilities[i];
      if (row === null || typeof row !== 'object' || Array.isArray(row)) {
        return result;
      }
      if (row.codec !== 'H264' && row.codec !== 'H265') {
        continue;
      }
      if (typeof row.recommendedAvailable !== 'boolean' || typeof row.recommendedIsHardware !== 'boolean' ||
        typeof row.hardwareAvailable !== 'boolean' || (!row.recommendedAvailable && row.recommendedIsHardware)) {
        return result;
      }
      const candidate: DecoderCandidate = {
        codec: row.codec,
        recommendedAvailable: row.recommendedAvailable,
        recommendedIsHardware: row.recommendedIsHardware,
        hardwareAvailable: row.hardwareAvailable
      };
      if (row.codec === 'H264') {
        if (h264 !== undefined) {
          return result;
        }
        h264 = candidate;
      } else {
        if (h265 !== undefined) {
          return result;
        }
        h265 = candidate;
      }
    }
    if (h264 !== undefined && h265 !== undefined) {
      result.state = 'observed';
      result.candidates = [h264, h265];
    }
  } catch (_) {
    // Never return source JSON or exception contents.
  }
  return result;
}
