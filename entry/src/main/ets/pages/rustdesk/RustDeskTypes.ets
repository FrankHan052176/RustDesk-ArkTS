export const DOMAIN = 0xFF01;
export const TAG = 'RustDeskIndex';
export const EVENT_POLL_INTERVAL_MS = 50;
export const MAX_PREVIEW_LONG_EDGE = 1280;
export const PASSWORD_TIMEOUT_MS = 60000;

export interface BridgeSummary {
  integrationStage: string;
  upstreamRepo: string;
  notes: string;
}

export interface SessionSnapshot {
  sessionId: string;
  coreSessionId?: string;
  phase: string;
  lastError?: string;
  /** Opaque native lifecycle epoch; bind/ACK must echo the value the native side issued. */
  lifecycleEpoch?: string;
  /**
   * The generation this session's viewer published, a decimal string.
   *
   * A RustDesk session's input authority lives in Core and its callers may omit
   * the generation; a VNC/RDP session is only admitted with this exact one.
   */
  inputGeneration?: string;
  /** Which wire this session really is: `rustdesk`, `vnc` or `rdp`. */
  kind?: string;
  /**
   * The exact target handed to `sessionAdd`, scheme included.
   *
   * It is the same key the runtime stores a local peer note under, so a RustDesk
   * id, a VNC endpoint and an RDP endpoint on one host are three keys.
   */
  target?: string;
  /**
   * Holds whose release this connection attempted and the peer refused, as a
   * decimal string.
   *
   * Absent means native has not read a count yet — unknown, not zero. Once
   * present, `0` is a measured clean stop, and a non-zero value means releases
   * are still owed, so the session must not be reported as cleanly stopped. It is
   * never cleared locally by a release attempt: only native's next value counts.
   */
  inputHoldsOwed?: string;
}

/** One destination a close or a Surface give-back reported. */
export interface NativeSurfaceRelease {
  /** Opaque destination token, a decimal string. */
  token: string;
  /** The source generation that token belongs to, a decimal string. */
  sourceIdentity: string;
  /** The Surface id the destination was bound to, a decimal string. */
  surfaceId: string;
  /** The native owner was really given back. */
  released: boolean;
  /** The destination is retained: its producer still owed a join. Never reused. */
  quarantined: boolean;
}

export interface ActionResponse {
  ok: boolean;
  action: string;
  message?: string;
  session?: SessionSnapshot;
  events?: NativeEvent[];
  /**
   * Close receipt: every destination was really given back.
   *
   * Only a `true` here authorizes destroying the Surface; a held destination
   * means the producer still owes a join.
   */
  released?: boolean;
  /** The destinations the native side reported for this close or give-back. */
  surfaces?: NativeSurfaceRelease[];
  /** Close: the producer's own join verdict token (`settled`, `unconfirmed`, `neverstarted`). */
  settle?: string;
  /**
   * Surface give-back: a destination is still held by a producer that owes a
   * join, so the Surface must not be destroyed.
   */
  held?: boolean;
  /** Surface destroy report: it belonged to another epoch or Surface, nothing changed. */
  stale?: boolean;
  /**
   * The generation the session is at now, named by a refused input call.
   *
   * It is the epoch a caller needs to retire input state kept for a boundary
   * that has gone; it is not a receipt that the event was delivered.
   */
  inputGeneration?: string;
  /**
   * Poll: the session was closed outside this bridge (a privacy revocation closes
   * a VNC/RDP wire underneath the UI). A `close` event accompanies it.
   */
  closed_externally?: boolean;
  /** Poll: the producer's close verdict, when one was recorded. */
  target_destroyed?: boolean;
  /**
   * A command answer: `accepted` means the command reached the connection's own
   * queue, `commanded` is what this call asked for. Neither is evidence the
   * backend already did it.
   */
  accepted?: boolean;
  commanded?: boolean;
  /** A mutation answer: the change was really applied. */
  applied?: boolean;
  /**
   * `sessionSendClipboard` on a direct wire: the text was accepted into the
   * session's one-slot queue.
   *
   * It is a queue receipt, not a write. The peer's own verdict arrives later as
   * the `clipboard_write_result` event, which is the only completion evidence.
   */
  queued?: boolean;
  /** Refresh: a real request reached the direct session task. */
  requested?: boolean;
  /** `sessionEnterOrLeave`: this build applies nothing, so this is informational. */
  notSupported?: boolean;
  /** `sessionSetCommon`: the Core does not act on that key, so it was refused by name. */
  unsupported?: boolean;
  /**
   * The same count as `session.inputHoldsOwed`, on the responses that carry one
   * (view-only/toggle mutations and input receipts).
   */
  inputHoldsOwed?: string;
  /** `sessionSetCodecPreference`: the value the Core's own option store holds now. */
  codec?: string;
  /** `sessionSetCodecPreference`: the Core really stored the value it read back. */
  stored?: boolean;
  /** `sessionSetCodecPreference`: the Core's own codec path accepted the change. */
  coreAccepted?: boolean;
}

export interface NativeEvent {
  name: string;
  /** certificate_untrusted: display-only leaf metadata, emitted before certificate rejection. */
  target?: string;
  sha256?: string;
  subject?: string;
  issuer?: string;
  notBefore?: string;
  notAfter?: string;
  reason?: string;
  pinnedSha256?: string;
  content?: string;
  paths?: Array<string>;
  /**
   * A verdict event's outcome: whether the operation the peer was asked for
   * really succeeded. `clipboard_write_result` carries it.
   */
  ok?: boolean;
  /** Verdict reason; resolution_refused carries the local reason its requested size was refused. */
  message?: string;
  type?: string;
  secure?: string;
  direct?: string;
  stream_type?: string;
  id?: string;
  hostname?: string;
  platform?: string;
  version?: string;
  keyboard?: string;
  displays?: string;
  resolutions?: string;
  audio?: string;
  current_display?: string;
  title?: string;
  text?: string;
  display?: number | string;
  width?: string;
  height?: string;
  fps?: string;
  delay?: string;
  codec_format?: string;
  x?: string;
  y?: string;
  hotx?: string;
  hoty?: string;
  colors?: string;
  gpu_texture?: boolean;
  speed?: string;
  target_bitrate?: string;
  chroma?: string;
  value?: string;
  is_local?: string;
  file_num?: string;
  finished_size?: string;
  err?: string;
  read_path?: string;
  is_upload?: string;
  is_identical?: string;
}

export interface PeerDisplayInfo {
  width: number;
  height: number;
  x: number;
  y: number;
  cursor_embedded?: number;
  original_width?: number;
  original_height?: number;
  scaled_width?: number;
  scaled_height?: number;
}

export interface ResolutionInfo {
  width: number;
  height: number;
}

export class DecoderCapability {
  codec: string = '';
  mime: string = '';
  mimeAvailable: boolean = false;
  recommendedAvailable: boolean = false;
  recommendedName: string = '';
  recommendedIsHardware: boolean = false;
  hardwareAvailable: boolean = false;
  hardwareName: string = '';
  softwareAvailable: boolean = false;
  softwareName: string = '';
}

export interface SavedConnectionSettings {
  target: string;
  /** Home's mode index the target was saved under (0 RustDesk, 1 VNC, 2 RDP, 3 files). */
  mode: number;
  password: string;
  rememberPassword: boolean;
}
