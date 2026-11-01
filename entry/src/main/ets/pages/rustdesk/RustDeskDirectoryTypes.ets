export type ServerMode = 'official' | 'custom';
export type ServerEndpointTestState = 'untested' | 'success' | 'error';
export type PeerSource = 'recent' | 'addressBook' | 'lan';
export type PeerViewSource = 'recent' | 'favorite' | 'lan' | 'addressBook';
/**
 * The remote-desktop protocol a target names.
 *
 * A saved target is identified by (protocol, target, rustdeskIdOnly), so a LAN
 * claimed ID can never collide with a manually entered direct address.
 */
export type PeerProtocol = 'rustdesk' | 'vnc' | 'rdp';
/**
 * What the runtime has observed about a peer in this process.
 *
 * `unknown` is not a weaker `offline`: it means no live observation exists yet.
 */
export type PeerOnlineState = 'unknown' | 'online' | 'offline';
export type VncQuality = 'lossless' | 'balanced' | 'fast';
export type RustDeskInputMode = 'off' | 'touch' | 'mouse' | 'relative';
export type RustDeskRightClickGesture = 'double_tap' | 'two_finger_tap' | 'long_press';

export class ServerConfig {
  mode: ServerMode = 'official';
  idServer: string = '';
  relayServer: string = '';
  apiServer: string = '';
  key: string = '';
  effectiveApiServer: string = '';
  usingPublicServer: boolean = true;
  remoteReachable: boolean = false;
  accountAvailable: boolean = false;
  resultState: string = 'idle';
  message: string = '';
  idServerTestState: ServerEndpointTestState = 'untested';
  relayServerTestState: ServerEndpointTestState = 'untested';
  apiServerTestState: ServerEndpointTestState = 'untested';
  idServerTestMessage: string = '';
  relayServerTestMessage: string = '';
  apiServerTestMessage: string = '';
}

/** Editable configuration never carries approval. Only a durable explicit Save does. */
export class ServerProfileState {
  config: ServerConfig = new ServerConfig();
  approval: 'missing' | 'legacy-unapproved' | 'approved' = 'missing';
  revision: number = 0;

  captureApproved(): ApprovedServerProfile | undefined {
    if (this.approval !== 'approved' || !Number.isSafeInteger(this.revision) || this.revision <= 0) {
      return undefined;
    }
    return new ApprovedServerProfile(this.config, this.revision);
  }
}

/** Value-owned session option; no reference to an editor or mutable saved config. */
export class ApprovedServerProfile {
  readonly schemaVersion: number = 2;
  readonly approval: string = 'explicit-save';
  readonly revision: number;
  readonly mode: ServerMode;
  readonly idServer: string;
  readonly relayServer: string;
  readonly key: string;

  constructor(config: ServerConfig, revision: number) {
    this.revision = revision;
    this.mode = config.mode;
    this.idServer = config.idServer;
    this.relayServer = config.relayServer;
    this.key = config.key;
  }

  /**
   * Rebuilds this value-owned route from an engine `approvedProfile` envelope.
   *
   * Only the engine's own persisted explicit save produces that envelope, so this
   * validates it instead of turning an editable draft into an approval. It reads
   * `revision` from the envelope (a number there), not the string `revision` the
   * same reply carries beside it.
   */
  static fromNative(source: ESObject): ApprovedServerProfile | undefined {
    if (source === undefined || source === null) {
      return undefined;
    }
    if (Number(source.schemaVersion) !== 2 || String(source.approval ?? '') !== 'explicit-save') {
      return undefined;
    }
    const revision = Number(source.revision);
    if (!Number.isSafeInteger(revision) || revision <= 0) {
      return undefined;
    }
    const mode = String(source.mode ?? '');
    if (mode !== 'official' && mode !== 'custom') {
      return undefined;
    }
    const config = new ServerConfig();
    config.mode = mode as ServerMode;
    config.idServer = String(source.idServer ?? '').trim();
    config.relayServer = String(source.relayServer ?? '').trim();
    config.key = String(source.key ?? '').trim();
    config.usingPublicServer = mode === 'official';
    if (config.idServer.length === 0 || config.key.length === 0) {
      return undefined;
    }
    return new ApprovedServerProfile(config, revision);
  }
}

/**
 * One engine server-profile receipt.
 *
 * Approval, persistence and reachability stay three separate facts: `committed`
 * is only the engine's own write, and no field here makes an endpoint reachable.
 */
export class ServerProfileReply {
  ok: boolean = false;
  action: string = '';
  approved: boolean = false;
  committed: boolean = false;
  revision: number = 0;
  config: ServerConfig = new ServerConfig();
  approvedProfile: ApprovedServerProfile | undefined = undefined;
  message: string = '';
  error: string = '';

  /** The approval a page may hold: only a real approved receipt produces one. */
  toProfileState(): ServerProfileState {
    const state = new ServerProfileState();
    const profile = this.approvedProfile;
    if (!this.ok || !this.approved || profile === undefined) {
      return state;
    }
    const config = new ServerConfig();
    config.mode = profile.mode;
    config.idServer = profile.idServer;
    config.relayServer = profile.relayServer;
    config.key = profile.key;
    config.usingPublicServer = profile.mode === 'official';
    state.config = config;
    state.approval = 'approved';
    state.revision = profile.revision;
    return state;
  }
}

/** One engine directory read: `exists:false` is a real empty store, `ok:false` is not. */
export class DirectoryReadReply {
  ok: boolean = false;
  action: string = '';
  source: string = '';
  exists: boolean = false;
  revision: number = 0;
  peers: PeerRecord[] = [];
  favorites: string[] = [];
  error: string = '';
}

/** One engine directory write. The local saved list stays the owner of the row. */
export class DirectoryWriteReply {
  ok: boolean = false;
  action: string = '';
  revision: number = 0;
  error: string = '';
}

/** The row this client observed after a real session; the engine only persists it. */
export interface NativeRecentPeerRow {
  id: string;
  protocol: PeerProtocol;
  address: string;
  port: number;
  username: string;
  hostname: string;
  platform: string;
  alias: string;
  note: string;
  lastSuccessAt: number;
}

export class ConnectionAttempt {
  readonly attemptId: number;
  readonly target: string;
  readonly approvedServerProfile: ApprovedServerProfile | undefined;
  readonly password: string;
  readonly requestedFps: number;
  readonly rustdeskIdOnly: boolean;

  constructor(attemptId: number, target: string, profile: ApprovedServerProfile | undefined,
    password: string, requestedFps: number, rustdeskIdOnly: boolean) {
    this.attemptId = attemptId;
    this.target = target;
    this.approvedServerProfile = profile;
    this.password = password;
    this.requestedFps = requestedFps;
    this.rustdeskIdOnly = rustdeskIdOnly;
  }

  withPassword(password: string): ConnectionAttempt {
    return new ConnectionAttempt(this.attemptId, this.target, this.approvedServerProfile,
      password, this.requestedFps, this.rustdeskIdOnly);
  }
}

export class NativeLifecycleReply {
  ok: boolean = false;
  ownerGeneration: string = '';
  ready: boolean = false;
  discoveryAllowed: boolean = false;
  error?: string;
}

export class LanPeerObservation {
  id: string = '';
  username: string = '';
  hostname: string = '';
  platform: string = '';
}

export class NativeLanReply {
  ok: boolean = false;
  ownerGeneration: string = '';
  scanId: string = '';
  revision: string = '0';
  state: string = 'idle';
  peers: LanPeerObservation[] = [];
  terminal?: string;
  error?: string;
}

@ObservedV2
export class PeerRecord {
  id: string = '';
  address: string = '';
  port: number = 0;
  rdpCertificateSha256: string = '';
  /**
   * Stated when the record came from the saved directory. `undefined` means the
   * record's protocol was not stated and has to follow the target's scheme.
   */
  protocol: PeerProtocol | undefined = undefined;
  /** LAN-derived intent survives favorites/recents; never reinterpret the ID as a direct IP. */
  rustdeskIdOnly: boolean = false;
  username: string = '';
  hostname: string = '';
  platform: string = '';
  alias: string = '';
  forceAlwaysRelay: boolean = false;
  rdpPort: string = '';
  rdpUsername: string = '';
  loginName: string = '';
  deviceGroupName: string = '';
  /** Optional local-only note; cloud address-book records never use this field. */
  note: string = '';
  sameServer: boolean | undefined = undefined;
  source: PeerSource = 'recent';
  addressBookName: string = '';
  tags: string[] = [];
  /** Epoch ms of the last caller-observed success; 0 means never observed. */
  lastSuccessAt: number = 0;
  /**
   * `undefined` until the runtime observes this peer in this process.
   *
   * Reachability is never persisted, so a restarted app reports `unknown`
   * rather than a remembered online or offline claim. Only an hbbs
   * `OnlineResponse` answered for this exact id fills this field; a LAN hit, a
   * stored address or an accepted TCP socket never does.
   */
  @Trace online: boolean | undefined = undefined;
  /**
   * TCP reachability of a direct RDP/VNC endpoint, never a RustDesk answer.
   *
   * The two observations stay apart so a reachable port can never read as a
   * peer the id server reported online, and an id-only peer is not probed here.
   */
  @Trace directWireReachable: boolean | undefined = undefined;
  @Trace favorite: boolean = false;
}

export class DirectorySnapshot {
  revision: number = 0;
  recent: PeerRecord[] = [];
  favorite: PeerRecord[] = [];
  /**
   * Every saved target, including entries that only carry an alias.
   *
   * `recent` and `favorite` are views of this set; it exists so a row from a
   * transient source (LAN, address book) can be merged with the alias and
   * favorite mark the operator saved for the same (protocol, target, ID-only intent).
   */
  saved: PeerRecord[] = [];
  addressBook: PeerRecord[] = [];
  lan: PeerRecord[] = [];
  lanScanning: boolean = false;
  lanCanScan: boolean = false;
  lanState: string = 'idle';
  lanTerminal: string = '';
  lanDisabledReason: ResourceStr = '';
  lanError: string = '';
  message: string = '';
}

export class PeerOnlineStatusResult {
  ok: boolean = false;
  /** The engine's own token for this answered query; empty when nothing answered. */
  queryGeneration: string = '';
  onlines: string[] = [];
  offlines: string[] = [];
  message: string = '';
}

export class SessionDefaults {
  touchMode: boolean = true;
  relativeMouseMode: boolean = false;
  /** Whether the local pointer and keyboard send anything to the peer at all. */
  inputEnabled: boolean = true;
  rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  audioEnabled: boolean = true;
  clipboardEnabled: boolean = true;
  /** Requested RustDesk capture rate; direct protocols do not expose a frame-rate control. */
  refreshRate: number = 60;
  preferredCodec: string = 'auto';
  gesturesEnabled: boolean = true;
  toolbarExpanded: boolean = false;
  sessionSharingEnabled: boolean = false;
  rdpResolution: string = 'follow';
  /** Zero means derive the whitelisted percent from this pane's pixel density. */
  rdpScaleFactor: number = 0;
  rdpAudioEnabled: boolean = true;
  vncQuality: VncQuality = 'balanced';
}

export class AccountState {
  loggedIn: boolean = false;
  apiServer: string = '';
  name: string = '';
  displayName: string = '';
  email: string = '';
  busy: boolean = false;
  syncing: boolean = false;
  challengeId: string = '';
  challengeType: string = '';
  emailHint: string = '';
  oidcProvider: string = '';
  message: string = '';
}

export class AccountLoginProvider {
  name: string = '';
  label: string = '';
}

export class AccountLoginOptionsResult {
  ok: boolean = false;
  state: string = 'idle';
  message: string = '';
  apiServer: string = '';
  providers: AccountLoginProvider[] = [];
}

export class AccountActionResult {
  ok: boolean = false;
  state: string = 'idle';
  message: string = '';
  challengeId: string = '';
  challengeType: string = '';
  emailHint: string = '';
  name: string = '';
  displayName: string = '';
  email: string = '';
  url: string = '';
  stateMessage: string = '';
  provider: string = '';
  addressBookCount: number = 0;
  peerCount: number = 0;
}
