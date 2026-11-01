/**
 * One display's frame-chain reading, as the engine published it.
 *
 * Every rate here is the engine's own: the Core computes its per-second rates
 * over its own one-second status tick, so this file never differences a counter,
 * invents a window, or substitutes the requested or the panel rate for a
 * measurement. The engine also says when it measures nothing at all, and that is
 * not the same as measuring zero.
 */

/** Which producer answered, and whether it counts frames at all. */
export type FrameRateReadingKind = 'measured' | 'decoder_failed' | 'engine_viewer' | 'unavailable';

export class FrameRateSnapshot {
  /**
   * `measured` is the only kind that carries frame counters.
   *
   * Both producers can measure: a Core status tick, and a direct VNC/RDP wire
   * once it reports `framesAvailable` while streaming. `engine_viewer` is that
   * same direct wire for a read that measured nothing (not streaming yet, or no
   * sample published); `unavailable` is the Core with nothing published to read
   * (no status tick yet, or no admission); `decoder_failed` is a Core reading
   * whose generation failed, whose rates do not describe the session's picture.
   */
  kind: FrameRateReadingKind = 'unavailable';
  /** The display this reading belongs to. */
  display: number = 0;
  /**
   * The connection round, decimal string; a new round is a new pipeline.
   *
   * Only a Core reading has one. A direct wire names no round or generation, so
   * both stay empty there and the reading is bound to its session and display
   * alone.
   */
  round: string = '';
  /** The decoder generation inside that round, decimal string; empty on a direct wire. */
  generation: string = '';
  /** The codec the engine named for this display; empty when it named none. */
  codec: string = '';
  /**
   * Compressed units that arrived per second.
   *
   * On a Core reading this is the engine's own arrival rate; on a direct wire it
   * is the decoded framebuffer update rate, which is not a scanout rate. `null`
   * is "not measured", never 0: the engine writes a measured zero as the string
   * "0", and the two must not read the same.
   */
  receivedFps: number | null = null;
  /**
   * Successful submissions per second, not physical scanout.
   *
   * A Core reading counts decoder submissions; a direct wire counts successful
   * non-empty Surface submissions. Both are what the pipeline really handed on,
   * not what a display showed.
   */
  submittedFps: number | null = null;
  /** Units waiting for the decoder right now; never claimed on a direct wire. */
  queuedUnits: number | null = null;

  /** Whether this reading carries frame counters the panel may show. */
  measured(): boolean {
    return this.kind === 'measured';
  }
}

/** The engine publishes one status tick a second, so a faster poll re-reads it. */
const READ_INTERVAL_MS = 1000;

/**
 * A counter the engine writes as a decimal string.
 *
 * A missing, non-decimal or unsafe value is `null` -- not measured -- and never
 * 0. The engine's own "0" stays 0, because a decoder that counted nothing is a
 * measurement, not an absence.
 */
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

/**
 * An identity the engine writes as a decimal string.
 *
 * Identities are compared, not measured, so an unreadable one invalidates the
 * whole reading: a reading whose generation cannot be named cannot be told
 * apart from the previous pipeline's.
 */
function decimalIdentity(value: string | number | null | undefined): string | undefined {
  if (typeof value === 'number') {
    return Number.isSafeInteger(value) && value >= 0 ? String(value) : undefined;
  }
  if (typeof value !== 'string' || !/^(0|[1-9][0-9]*)$/.test(value)) {
    return undefined;
  }
  return Number.isSafeInteger(Number(value)) ? value : undefined;
}

/**
 * The engine's own JSON, as the wire spells it.
 *
 * Deliberately separate from `FrameRateSnapshot`: this is what the engine
 * sends -- counters as decimal strings, identities as strings, and whatever a
 * given source does not report simply absent -- while the class below is what
 * this app publishes. The two must not be mixed, so a wire field can never
 * leak into the published reading, and the counters accept either spelling the
 * producer may use.
 *
 * Fields this build does not read (geometry, the direct wire's protocol and
 * authentication fields, `nativePaintedFps`, the engine's unavailable `reason`)
 * are not declared here: nothing reads them, so nothing retains them.
 */
interface FrameRateWire {
  available?: boolean;
  source?: string;
  display?: number;
  round?: string | number;
  generation?: string | number;
  codec?: string;
  failed?: boolean;
  /** The direct wire's phase; only `streaming` may carry a frame-rate sample. */
  status?: string;
  /** The direct wire's own admission that it has a real frame-rate sample. */
  framesAvailable?: boolean;
  receivedFps?: string | number | null;
  submittedFps?: string | number | null;
  queuedUnits?: string | number | null;
}

/**
 * Classify one raw snapshot without keeping anything the engine did not say.
 *
 * `undefined` is a packet this build cannot read at all (not JSON, or a shape
 * that is neither the Core's status tick nor the direct wire's own snapshot).
 * Every other answer is a real state of the session, including a direct wire
 * read that carries no counters, so a VNC/RDP session and a Core session that
 * has not ticked yet are classified rather than rejected.
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
    // The engine's own reason is not retained: it names its admission state,
    // which the panel does not show.
    return result;
  }
  const source: string = wire.source ?? '';
  if (source === 'engine_viewer_snapshot') {
    // A direct VNC/RDP wire carries no decoder round or generation, so it is
    // bound to its session and display alone. It only measures once the engine
    // admits it has a real sample (`framesAvailable`) while the wire is really
    // `streaming`: a wire still opening, or one that failed, measured nothing,
    // and its absent counters must not read as a decoder that produced zero.
    if (wire.framesAvailable === true && wire.status === 'streaming') {
      const directDisplay = wire.display;
      // The display is validated exactly as the Core's is: the new contract
      // always names it, so a missing or malformed one is an unreadable packet,
      // not a display to relabel. A declared other display is retained as
      // declared, so a reading that belongs to it is never consumed by a poll
      // for display 0.
      if (typeof directDisplay !== 'number' || !Number.isSafeInteger(directDisplay) || directDisplay < 0) {
        console.error('tlm_parse_reject reason=identity');
        return undefined;
      }
      result.kind = 'measured';
      result.display = directDisplay;
      result.codec = typeof wire.codec === 'string' ? wire.codec : '';
      result.receivedFps = decimalCount(wire.receivedFps);
      result.submittedFps = decimalCount(wire.submittedFps);
      result.queuedUnits = decimalCount(wire.queuedUnits);
      return result;
    }
    // This read measured nothing. Its null counters are never read, so none of
    // them can read as a decoder that produced nothing.
    result.kind = 'engine_viewer';
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
 * Reads one session's frame snapshot at most once a second and keeps the
 * readings apart by session, display, round and generation.
 *
 * A direct wire names no round or generation, so there its reading is bound to
 * the session and display alone; the binding still keeps one session's rates
 * from being reused by another.
 */
export class FrameRateTelemetry {
  private binding: string = '';
  private lastReadAt: number = -1;
  private hasReading: boolean = false;
  private display: number = -1;
  private round: string = '';
  private generation: string = '';
  private frameReset: boolean = false;

  /** Drops every binding and reading, as a session that has just ended. */
  reset(): void {
    this.binding = '';
    this.lastReadAt = -1;
    this.forgetReading();
    this.frameReset = false;
  }

  /**
   * Consume the one-shot notice that the frame rows on screen describe a
   * pipeline that no longer exists.
   *
   * The caller clears those rows and keeps what the peer's quality events
   * measured for this session, because those are this session's own numbers.
   */
  consumeFrameReset(): boolean {
    const crossed = this.frameReset;
    this.frameReset = false;
    return crossed;
  }

  /**
   * Whether this poll may read the snapshot at all.
   *
   * A different binding is a different session, and an unusable one ends the
   * reading entirely.
   */
  shouldRead(binding: string, now: number): boolean {
    if (binding.length === 0 || !Number.isFinite(now) || now < 0) {
      this.reset();
      return false;
    }
    if (binding !== this.binding) {
      this.reset();
      this.binding = binding;
    }
    if (this.lastReadAt >= 0 && now < this.lastReadAt) {
      // A clock that moved backwards is not an elapsed interval; re-anchor on
      // it instead of dividing by it.
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
   * One read of the engine's snapshot for `display`.
   *
   * Returns the reading the panel may show, or `undefined` when this read has
   * nothing to show for that display: nothing published, a direct wire read
   * that measured nothing, a failed generation, an unreadable packet, or a
   * reading that belongs to another display. A reading from a pipeline other
   * than the one already on screen also returns `undefined`, after telling the
   * caller once that the rows it still shows describe a decoder that no longer
   * exists.
   */
  sample(raw: string, display: number): FrameRateSnapshot | undefined {
    if (this.binding.length === 0) {
      this.forgetReading();
      return undefined;
    }
    const current = parseFrameRateSnapshot(raw);
    if (current === undefined || !current.measured() || current.display !== display) {
      this.forgetReading();
      return undefined;
    }
    if (this.hasReading && (current.round !== this.round || current.generation !== this.generation
      || display !== this.display)) {
      this.forgetReading();
      this.remember(current, display);
      return undefined;
    }
    this.remember(current, display);
    return current;
  }

  private remember(current: FrameRateSnapshot, display: number): void {
    this.hasReading = true;
    this.display = display;
    this.round = current.round;
    this.generation = current.generation;
  }

  private forgetReading(): void {
    if (this.hasReading) {
      this.frameReset = true;
    }
    this.hasReading = false;
    this.display = -1;
    this.round = '';
    this.generation = '';
  }
}
