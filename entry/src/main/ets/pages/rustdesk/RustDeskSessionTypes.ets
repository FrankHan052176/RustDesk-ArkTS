import { FrameRateSnapshot } from '../../services/FrameRateTelemetry';
import { ApprovedServerProfile, VncQuality } from './RustDeskDirectoryTypes';

export type TransferDirection = 'upload' | 'download';
export type TransferState = 'queued' | 'running' | 'awaiting_override' | 'completed' | 'failed' | 'cancelled';

export interface SessionStartOptions {
  password: string;
  connToken?: string;
  forceRelay: boolean;
  isFileTransfer: boolean;
  isViewOnly: boolean;
  passwordEphemeral?: boolean;
  /**
   * Whether this target is a claimed RustDesk ID (LAN consensus or an ID-only
   * entry), so the engine records the ID route instead of reading an address.
   */
  rustdeskIdOnly?: boolean;
  /**
   * The route the engine itself explicitly saved for this ID, as a value-owned
   * envelope. Only an engine-approved profile produces it and the engine refuses
   * an ID registration without one; direct endpoints ignore it.
   */
  approvedServerProfile?: ApprovedServerProfile;
  /**
   * Requested peer capture rate.
   *
   * It has to travel with the session start because the controlled host reads
   * the rate once, from the login options, and holds it for the session; a
   * rate sent after authentication is not applied. Omitting it means the host
   * keeps its own configured rate.
   */
  customFps?: number;
  /**
   * The SHA-256 pin the operator confirmed for this RDP endpoint, as 64 hex
   * characters.
   *
   * It travels with session start, and only RDP reads it. The UI supplies it from
   * the host:port trust store or an explicit certificate-dialog acceptance, never
   * a manually typed fingerprint or an observed certificate by itself. Omitting
   * it leaves trust exactly as the platform's own certificate validation decides,
   * and never relaxes it. The native side refuses a malformed pin, and refuses a
   * non-empty pin on a wire that cannot use one, rather than ignoring either.
   */
  rdpCertificateSha256?: string;
  rdpDesktopWidth?: number;
  rdpDesktopHeight?: number;
  rdpScaleFactor?: number;
  rdpAudio?: boolean;
  vncQuality?: VncQuality;
}

export interface RemoteFileEntry {
  entry_type: number;
  name: string;
  size: number;
  modified_time: number;
}

export interface RemoteFileDirectory {
  id: number;
  path: string;
  entries: RemoteFileEntry[];
}

export interface LocalFileEntry {
  name: string;
  path: string;
  size: number;
}

export interface TransferItem {
  id: number;
  fileNum: number;
  direction: TransferDirection;
  sourcePath: string;
  destinationPath: string;
  fileName: string;
  totalBytes: number;
  transferredBytes: number;
  speedBytesPerSecond: number;
  state: TransferState;
  errorText: string;
}

/**
 * What the quality panel and the session toolbar show.
 *
 * Every field is the bare value as text, and `''` means "not measured", which
 * the panel renders as `--`. `'0'` is a real measurement and never the same as
 * `''`: a decoder that submitted nothing is a reading, not an absence.
 *
 * Only what the pipeline really reports is here. The Core's status tick gives
 * the frame rates and the queue depth; a direct VNC/RDP wire gives its own
 * submission rate and received-update rate once it reports a genuine sample;
 * the peer's quality events give the network round trip, the receive bandwidth,
 * the target bitrate and the codec. A direct wire measures no queue depth, so
 * `queuedUnits` stays unmeasured there instead of reading as zero. There is no
 * source for a submission-path latency, a decode duration or an admission rate,
 * so no field claims one.
 */
export interface QualityTelemetry {
  /** Successful submissions per second, not physical scanout. */
  submittedFps: string;
  /** The capture rate this client asked the peer for. */
  requestedFps: string;
  /** Compressed units arriving per second, or a direct wire's decoded updates per second. */
  receivedFps: string;
  /** Units waiting for the decoder right now; a direct wire measures none. */
  queuedUnits: string;
  /** The codec the engine or the peer's quality event named. */
  codec: string;
  /** Network round-trip time in milliseconds, as the peer measured it. */
  networkRttMs: string;
  /** Receive bandwidth in kB/s, as the peer's quality event reported it. */
  receiveBandwidthKBs: string;
  /** The peer encoder's target bitrate in kbps. */
  targetBitrateKbps: string;
}

/** The panel before anything has been measured: every row unknown, none zero. */
export function emptyQualityTelemetry(): QualityTelemetry {
  return {
    submittedFps: '',
    requestedFps: '',
    receivedFps: '',
    queuedUnits: '',
    codec: '',
    networkRttMs: '',
    receiveBandwidthKBs: '',
    targetBitrateKbps: '',
  };
}

/**
 * Clears the frame-chain rows a new pipeline invalidates.
 *
 * A generation, round or display change is a new pipeline: the rates measured
 * on the old one describe a decoder that no longer exists, so they are dropped
 * rather than shown as the new one's. A direct wire names no generation or
 * round, so a read there that stops measuring -- not streaming, or a failed
 * snapshot -- drops them the same way. What the peer's quality events measured --
 * the round trip, the bandwidth, the target bitrate, the codec it named -- is
 * this session's own and stays.
 */
export function clearQualityFrameMetrics(current: QualityTelemetry): QualityTelemetry {
  return {
    submittedFps: '',
    requestedFps: current.requestedFps,
    receivedFps: '',
    queuedUnits: '',
    codec: current.codec,
    networkRttMs: current.networkRttMs,
    receiveBandwidthKBs: current.receiveBandwidthKBs,
    targetBitrateKbps: current.targetBitrateKbps,
  };
}

/** A measured counter as the panel shows it: unknown stays empty, a real 0 stays 0. */
function measuredText(value: number | null): string {
  return value === null ? '' : String(value);
}

/**
 * Applies one frame snapshot to the panel's values.
 *
 * The snapshot is the only source of the frame rows -- a Core status tick or a
 * direct wire's own sample -- and it replaces them together: the engine
 * computed its rates over its own interval, so nothing here differences a
 * counter or scales anything to a window. A snapshot that carries no counters
 * clears those rows instead of publishing zeros.
 */
export function applyFrameRateSnapshot(
  current: QualityTelemetry,
  snapshot: FrameRateSnapshot,
  requestedFps: string,
): QualityTelemetry {
  const measured = snapshot.measured();
  return {
    submittedFps: measured ? measuredText(snapshot.submittedFps) : '',
    requestedFps,
    receivedFps: measured ? measuredText(snapshot.receivedFps) : '',
    queuedUnits: measured ? measuredText(snapshot.queuedUnits) : '',
    codec: measured && snapshot.codec.length > 0 ? snapshot.codec : current.codec,
    networkRttMs: current.networkRttMs,
    receiveBandwidthKBs: current.receiveBandwidthKBs,
    targetBitrateKbps: current.targetBitrateKbps,
  };
}

/**
 * One `update_quality_status` event, as its string fields arrived.
 *
 * The engine sends these in batches and leaves out whatever a batch did not
 * measure, so an empty field means "this event carried none", never zero and
 * never "clear the previous value".
 *
 * The event's own `fps` is deliberately absent: it is a display-frame rate (a
 * count of frames a renderer took), and the H.264/H.265 Surface path this build
 * runs reports no such count, so there is no row it could fill.
 */
export interface QualityStatusFields {
  /** Receive bandwidth, written as `123.45kB/s`; '' when this event carried none. */
  speed: string;
  /** Network round-trip time in ms; '' when this event carried none. */
  delay: string;
  /** The peer encoder's target bitrate in kbps; '' when this event carried none. */
  targetBitrate: string;
  /** The codec a decoder really opened with; '' when this event carried none. */
  codec: string;
}

/** A non-negative integer the peer wrote as text, or the previous value when it wrote none. */
function integerText(value: string, previous: string): string {
  return /^(0|[1-9][0-9]*)$/.test(value) && Number.isSafeInteger(Number(value)) ? value : previous;
}

/** `123.45kB/s`, the one spelling the peer's quality event uses for bandwidth. */
function bandwidthText(value: string, previous: string): string {
  return /^[0-9]+(\.[0-9]+)?kB\/s$/.test(value) ? value.substring(0, value.length - 4) : previous;
}

/**
 * Folds one quality event into the panel's values.
 *
 * Each field the event carried replaces the previous reading; each field it
 * left empty keeps the previous one, because the two batches that make up one
 * status tick carry different halves of the same reading.
 */
export function mergeQualityStatus(
  current: QualityTelemetry,
  event: QualityStatusFields,
): QualityTelemetry {
  return {
    submittedFps: current.submittedFps,
    requestedFps: current.requestedFps,
    receivedFps: current.receivedFps,
    queuedUnits: current.queuedUnits,
    codec: event.codec.length > 0 ? event.codec : current.codec,
    networkRttMs: integerText(event.delay, current.networkRttMs),
    receiveBandwidthKBs: bandwidthText(event.speed, current.receiveBandwidthKBs),
    targetBitrateKbps: integerText(event.targetBitrate, current.targetBitrateKbps),
  };
}

export interface RemoteAudioState {
  available: boolean;
  muted: boolean;
  rendererActive: boolean;
  errorText: string;
}

export interface DownloadRoot {
  uri: string;
  path: string;
}
