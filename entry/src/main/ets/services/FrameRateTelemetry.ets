/**
 * One display's frame-chain reading. Core ticks already contain window rates;
 * Viewer snapshots contain cumulative counters and native monotonic elapsedMs.
 * Neither requested FPS nor the panel refresh rate is a measurement here.
 */

export type FrameRateReadingKind = 'measured' | 'decoder_failed' | 'engine_viewer' | 'unavailable';

export class FrameRateSnapshot {
  /** `measured` carries rates; a Viewer baseline still carries its other facts. */
  kind: FrameRateReadingKind = 'unavailable';
  source: string = '';
  /** The actual display the engine names, not the display requested by the poll. */
  display: number = 0;
  /** Core connection round; unused by the Viewer producer. */
  round: string = '';
  /** Core decoder generation, or the Viewer's dial identity, as a decimal string. */
  generation: string = '';
  /** Viewer dial identity, also published as generation; unused by Core ticks. */
  intentRevision: string = '';
  /** The Viewer's real engine phase. Only streaming samples form rate windows. */
  status: string = '';
  /** Encoding format only, not a decoder vendor or hardware/software identity. */
  codec: string = '';
  /** Last positive peer-reported TestDelay.last_delay; null means unknown. */
  networkRttMs: number | null = null;
  /**
   * The socket's own smoothed round trip in milliseconds, or null when the
   * platform reported none. A sub-millisecond LAN reading is a real 0 here,
   * where the peer's integer field uses null for "no measurement".
   */
  tcpRttMs: number | null = null;
  /** Native monotonic duration since this dial began. */
  elapsedMs: number | null = null;
  /** Cumulative compressed access units, despite the producer's legacy name. */
  receivedPackets: number | null = null;
  /** Cumulative successful render submissions, not physical scanout. */
  submittedFrames: number | null = null;
  /** Compressed access units received per second; null is unknown, not zero. */
  receivedFps: number | null = null;
  /** Successful submissions per second, not physical scanout. */
  submittedFps: number | null = null;
  /** Units currently waiting for the decoder, independent of the FPS window. */
  queuedUnits: number | null = null;

  measured(): boolean {
    return this.kind === 'measured';
  }
}

/** Preserve the existing once-per-second polling cadence. */
const READ_INTERVAL_MS = 1000;

/** An absent, malformed or unsafe counter is unknown; an explicit 0 stays 0. */
function decimalCount(value: string | number | null | undefined): number | null {
  if (typeof value === 'number') {
    return Number.isSafeInteger(value) && value >= 0 ? value : null;
  }
  if (typeof value !== 'string' || !/^(0|[1-9][0-9]*)$/.test(value)) {
    return null;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : null;
}

/** An unreadable identity cannot be compared with the previous pipeline. */
function decimalIdentity(value: string | number | null | undefined): string | undefined {
  if (typeof value === 'number') {
    return Number.isSafeInteger(value) && value >= 0 ? String(value) : undefined;
  }
  if (typeof value !== 'string' || !/^(0|[1-9][0-9]*)$/.test(value)) {
    return undefined;
  }
  return Number.isSafeInteger(Number(value)) ? value : undefined;
}

/** Only fields consumed from the two real snapshot producers. */
interface FrameRateWire {
  available?: boolean;
  source?: string;
  display?: number;
  round?: string | number;
  generation?: string | number;
  intentRevision?: string | number;
  codec?: string;
  failed?: boolean;
  status?: string;
  elapsedMs?: number;
  receivedPackets?: number;
  submittedFrames?: number;
  networkRttMs?: number | null;
  tcpRttMs?: number | null;
  receivedFps?: string | number | null;
  submittedFps?: string | number | null;
  queuedUnits?: string | number | null;
}

/**
 * Parse facts, not a synthetic FPS sample. A Viewer snapshot stays a baseline
 * until the sampler has two adjacent streaming readings of the same pipeline.
 */
export function parseFrameRateSnapshot(raw: string): FrameRateSnapshot | undefined {
  let wire: FrameRateWire | undefined;
  try {
    wire = JSON.parse(raw) as FrameRateWire;
  } catch (_error) {
    console.error('tlm_parse_reject reason=invalid-json');
    return undefined;
  }
  if (!wire || typeof wire.available !== 'boolean') {
    console.error('tlm_parse_reject reason=shape');
    return undefined;
  }
  const result = new FrameRateSnapshot();
  if (!wire.available) {
    return result;
  }
  const source: string = wire.source ?? '';
  result.source = source;
  if (source === 'engine_viewer_snapshot') {
    const display = wire.display;
    const generation = decimalIdentity(wire.generation);
    const intentRevision = decimalIdentity(wire.intentRevision);
    if (typeof display !== 'number' || !Number.isSafeInteger(display) || display < 0
      || generation === undefined || intentRevision === undefined || typeof wire.status !== 'string') {
      console.error('tlm_parse_reject reason=identity');
      return undefined;
    }
    result.kind = 'engine_viewer';
    result.display = display;
    result.generation = generation;
    result.intentRevision = intentRevision;
    result.status = wire.status;
    result.elapsedMs = decimalCount(wire.elapsedMs);
    result.receivedPackets = decimalCount(wire.receivedPackets);
    result.submittedFrames = decimalCount(wire.submittedFrames);
    result.codec = typeof wire.codec === 'string' ? wire.codec : '';
    result.queuedUnits = decimalCount(wire.queuedUnits);
    const rtt = wire.networkRttMs;
    result.networkRttMs = typeof rtt === 'number' && Number.isSafeInteger(rtt) && rtt > 0 ? rtt : null;
    const tcpRtt = wire.tcpRttMs;
    // A kernel estimate can be under a millisecond, so 0 is a reading here.
    result.tcpRttMs = typeof tcpRtt === 'number' && Number.isFinite(tcpRtt) && tcpRtt >= 0 ? tcpRtt : null;
    return result;
  }
  if (source !== 'core_status_tick') {
    console.error('tlm_parse_reject reason=source');
    return undefined;
  }
  const display = wire.display;
  const round = decimalIdentity(wire.round);
  const generation = decimalIdentity(wire.generation);
  if (typeof display !== 'number' || !Number.isSafeInteger(display) || display < 0
    || round === undefined || generation === undefined || typeof wire.failed !== 'boolean') {
    console.error('tlm_parse_reject reason=identity');
    return undefined;
  }
  result.kind = wire.failed ? 'decoder_failed' : 'measured';
  result.display = display;
  result.round = round;
  result.generation = generation;
  result.codec = typeof wire.codec === 'string' ? wire.codec : '';
  result.receivedFps = decimalCount(wire.receivedFps);
  result.submittedFps = decimalCount(wire.submittedFps);
  result.queuedUnits = decimalCount(wire.queuedUnits);
  return result;
}

/**
 * Reads at most once a second. The caller binds session + lifecycle; this class
 * additionally fences the producer, dial/decoder identities and real display.
 */
export class FrameRateTelemetry {
  private binding: string = '';
  private lastReadAt: number = -1;
  private hasReading: boolean = false;
  private source: string = '';
  private display: number = -1;
  private round: string = '';
  private generation: string = '';
  private intentRevision: string = '';
  private viewerBaseline: FrameRateSnapshot | undefined = undefined;
  private frameReset: boolean = false;

  reset(): void {
    this.binding = '';
    this.lastReadAt = -1;
    this.forgetReading();
    this.frameReset = false;
  }

  /** One-shot notice to clear frame rows that describe an invalidated pipeline. */
  consumeFrameReset(): boolean {
    const crossed = this.frameReset;
    this.frameReset = false;
    return crossed;
  }

  shouldRead(binding: string, now: number): boolean {
    if (binding.length === 0 || !Number.isFinite(now) || now < 0) {
      this.reset();
      return false;
    }
    if (binding !== this.binding) {
      // Keep the one-shot invalidation even if the new binding has no readable
      // snapshot yet. Explicit reset() still drops all state for a closed UI.
      this.forgetReading();
      this.binding = binding;
      this.lastReadAt = -1;
    }
    if (this.lastReadAt >= 0 && now < this.lastReadAt) {
      // Re-anchor the polling clock. Rate windows use native elapsedMs instead.
      this.lastReadAt = now;
      return false;
    }
    if (this.lastReadAt >= 0 && now - this.lastReadAt < READ_INTERVAL_MS) {
      return false;
    }
    this.lastReadAt = now;
    return true;
  }

  /**
   * Returns facts for this display, even before a Viewer FPS window exists.
   * Unreadable/unavailable/other-display samples and failed Core ticks instead
   * invalidate the previous reading. Core's already-computed rates are unchanged.
   */
  sample(raw: string, display: number): FrameRateSnapshot | undefined {
    if (this.binding.length === 0) {
      this.forgetReading();
      return undefined;
    }
    const current = parseFrameRateSnapshot(raw);
    if (current === undefined || current.display !== display) {
      this.forgetReading();
      return undefined;
    }
    if (current.kind === 'engine_viewer') {
      return this.sampleViewer(current, display);
    }
    if (!current.measured()) {
      this.forgetReading();
      return undefined;
    }
    if (this.hasReading && !this.samePipeline(current, display)) {
      this.forgetReading();
      this.remember(current, display);
      return undefined;
    }
    this.remember(current, display);
    return current;
  }

  private sampleViewer(current: FrameRateSnapshot, display: number): FrameRateSnapshot {
    const previous = this.viewerBaseline;
    if (this.hasReading && !this.samePipeline(current, display)) {
      this.forgetReading();
    }
    if (current.status !== 'streaming') {
      this.forgetReading();
      return current;
    }
    if (this.hasReading && previous !== undefined) {
      const elapsed = current.elapsedMs;
      const beforeElapsed = previous.elapsedMs;
      const received = current.receivedPackets;
      const beforeReceived = previous.receivedPackets;
      const submitted = current.submittedFrames;
      const beforeSubmitted = previous.submittedFrames;
      if (elapsed !== null && beforeElapsed !== null && elapsed > beforeElapsed
        && received !== null && beforeReceived !== null && received >= beforeReceived
        && submitted !== null && beforeSubmitted !== null && submitted >= beforeSubmitted) {
        const windowMs = elapsed - beforeElapsed;
        current.receivedFps = (received - beforeReceived) * 1000 / windowMs;
        current.submittedFps = (submitted - beforeSubmitted) * 1000 / windowMs;
        current.kind = 'measured';
      } else {
        // No forward interval, a missing counter or a reset is not a measured
        // zero. Rebuild from this sample rather than crossing the discontinuity.
        this.forgetReading();
      }
    }
    this.remember(current, display);
    return current;
  }

  private samePipeline(current: FrameRateSnapshot, display: number): boolean {
    return current.source === this.source && display === this.display && current.round === this.round
      && current.generation === this.generation && current.intentRevision === this.intentRevision;
  }

  private remember(current: FrameRateSnapshot, display: number): void {
    this.hasReading = true;
    this.source = current.source;
    this.display = display;
    this.round = current.round;
    this.generation = current.generation;
    this.intentRevision = current.intentRevision;
    this.viewerBaseline = current.source === 'engine_viewer_snapshot' ? current : undefined;
  }

  private forgetReading(): void {
    if (this.hasReading) {
      this.frameReset = true;
    }
    this.hasReading = false;
    this.source = '';
    this.display = -1;
    this.round = '';
    this.generation = '';
    this.intentRevision = '';
    this.viewerBaseline = undefined;
  }
}
