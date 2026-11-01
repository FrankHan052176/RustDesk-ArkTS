// Metadata only: this observer never requests, copies or schedules video frames.
export class SoftwarePresentSnapshot {
  route: string = 'native_window_software';
  generation: string = '';
  bound: boolean = false;
  state: string = 'unavailable';
  width: number = 0;
  height: number = 0;
  submittedFrames: number = 0;
  reason: string = 'metadata_unavailable';
  code: number | null = null;
  zeroCopyProven: boolean = false;
}

export function isSoftwarePresentCodec(codec: string): boolean {
  const label = codec.trim().toUpperCase();
  return label === 'VP8' || label === 'VP9' || label === 'AV1';
}

export function hasSoftwarePresentActivity(snapshot: SoftwarePresentSnapshot): boolean {
  return snapshot.bound && snapshot.generation.length > 0
    && ((snapshot.state === 'submitted' && snapshot.submittedFrames > 0)
      || (snapshot.state === 'failed' && snapshot.reason === 'target_failed'));
}

export function hasRetainedSoftwareSubmission(snapshot: SoftwarePresentSnapshot): boolean {
  return snapshot.bound && snapshot.generation.length > 0 && snapshot.submittedFrames > 0
    && snapshot.state === 'unavailable' && (snapshot.reason === 'busy' || snapshot.reason === 'no_buffer');
}

export function shouldSelectSoftwarePresent(codec: string, snapshot: SoftwarePresentSnapshot): boolean {
  const label = codec.trim().toUpperCase();
  // Software counters survive codec switches within one Surface generation.
  // Explicit current hardware telemetry must win over that historical snapshot.
  if (label === 'H264' || label === 'H265') {
    return false;
  }
  return isSoftwarePresentCodec(label)
    || (snapshot.state === 'submitted' && hasSoftwarePresentActivity(snapshot))
    || hasRetainedSoftwareSubmission(snapshot);
}

export function parseSoftwarePresentState(raw: string): SoftwarePresentSnapshot {
  try {
    const value = JSON.parse(raw) as SoftwarePresentSnapshot;
    if (!value || value.route !== 'native_window_software'
      || typeof value.generation !== 'string' || typeof value.bound !== 'boolean'
      || !['waiting', 'submitted', 'unavailable', 'closing', 'closed', 'failed'].includes(value.state)
      || !Number.isSafeInteger(value.width) || value.width < 0
      || !Number.isSafeInteger(value.height) || value.height < 0
      || !Number.isSafeInteger(value.submittedFrames) || value.submittedFrames < 0
      || typeof value.reason !== 'string' || !/^[a-z0-9_]{0,96}$/.test(value.reason)
      || (value.code !== null && !Number.isSafeInteger(value.code))
      || value.zeroCopyProven !== false
      || (value.bound && value.generation.length === 0)
      || (!value.bound && (value.generation !== '' || value.state !== 'unavailable'
        || value.width !== 0 || value.height !== 0 || value.submittedFrames !== 0))
      || (value.state === 'submitted'
        && (!value.bound || value.submittedFrames <= 0 || value.width <= 0 || value.height <= 0))) {
      return new SoftwarePresentSnapshot();
    }
    return value;
  } catch (_) {
    return new SoftwarePresentSnapshot();
  }
}

export class SoftwarePresentObserver {
  private binding: string = '';
  private epoch: number = 0;
  private lastPollAt: number = -1;
  private generation: string = '';
  private submittedFrames: number = 0;

  selectBinding(binding: string): boolean {
    if (this.binding === binding) {
      return false;
    }
    this.binding = binding;
    this.epoch += 1;
    this.lastPollAt = -1;
    this.generation = '';
    this.submittedFrames = 0;
    return true;
  }

  token(): number {
    return this.epoch;
  }

  shouldPoll(now: number): boolean {
    if (this.binding.length === 0 || (this.lastPollAt >= 0 && now - this.lastPollAt < 100)) {
      return false;
    }
    this.lastPollAt = now;
    return true;
  }

  accept(raw: string, token: number): SoftwarePresentSnapshot | undefined {
    if (this.binding.length === 0 || token !== this.epoch) {
      return undefined;
    }
    const snapshot = parseSoftwarePresentState(raw);
    if (!snapshot.bound) {
      return snapshot;
    }
    // HAR guarantees one generation per successful local binding. Observing
    // its initial generation does not mean a software frame was submitted.
    if (this.generation.length > 0 && snapshot.generation !== this.generation) {
      return new SoftwarePresentSnapshot();
    }
    if (this.generation.length === 0) {
      this.generation = snapshot.generation;
    }
    if (snapshot.state === 'submitted' && snapshot.submittedFrames < this.submittedFrames) {
      return new SoftwarePresentSnapshot();
    }
    this.submittedFrames = Math.max(this.submittedFrames, snapshot.submittedFrames);
    return snapshot;
  }
}
