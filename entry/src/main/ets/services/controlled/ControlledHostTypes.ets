export type ControlledHostPhase = 'disabled' | 'starting' | 'ready' | 'incoming' | 'active' | 'stopping' |
  'failed';
export type ControlledPasswordMode = 'use-temporary-password' | 'use-permanent-password' | 'use-both-passwords';

export const PASSWORD_MODE_TEMPORARY: ControlledPasswordMode = 'use-temporary-password';
export const PASSWORD_MODE_PERMANENT: ControlledPasswordMode = 'use-permanent-password';
export const PASSWORD_MODE_BOTH: ControlledPasswordMode = 'use-both-passwords';

export class ControlledIncomingPeer {
  requestId: string = '';
  peerId: string = '';
  peerName: string = '';
  authorized: boolean = false;
}

export class ControlledTrustedDevice {
  hwid: number[] = [];
  time: number = 0;
  id: string = '';
  name: string = '';
  platform: string = '';
}

@ObservedV2
export class ControlledTwoFactorState {
  @Trace enabled: boolean = false;
  @Trace setupUri: string = '';
  @Trace verificationCode: string = '';
  @Trace trustedDevicesEnabled: boolean = true;
  @Trace trustedDevicesFixed: boolean = false;
  @Trace trustedDevices: ControlledTrustedDevice[] = [];
  @Trace busy: boolean = false;
  @Trace errorText: string = '';
}

@ObservedV2
export class ControlledHostState {
  @Trace phase: ControlledHostPhase = 'disabled';
  @Trace myId: string = '';
  @Trace temporaryPassword: string = '';
  @Trace verificationMethod: ControlledPasswordMode = PASSWORD_MODE_BOTH;
  @Trace permanentPasswordSet: boolean = false;
  @Trace localPermanentPasswordSet: boolean = false;
  @Trace verificationMethodFixed: boolean = false;
  @Trace permanentPasswordChangeDisabled: boolean = false;
  @Trace maxPasswordLength: number = 128;
  @Trace passwordError: string = '';
  @Trace statusText: string = '被看服务未启用';
  @Trace lastError: string = '';
  @Trace incoming: ControlledIncomingPeer | undefined = undefined;
  @Trace incomingResolving: boolean = false;
  @Trace activePeerName: string = '';
  /** The capture owner really reported it is producing. */
  @Trace captureActive: boolean = false;
  /** The full native capture verdict: producing, consented and not terminal. */
  @Trace captureAuthorized: boolean = false;
  /**
   * A previous close the native side could not confirm.
   *
   * Non-empty means the owner is in a state that cannot be trusted: it is shown
   * until a later status clears it, and the host is not reported as ready.
   */
  @Trace teardownUnconfirmed: string = '';
  /** The owner's own reason for a terminal capture state, when it reported one. */
  @Trace terminalReason: string = '';
  /** The real local-approval policy Core governs connections with. */
  @Trace approveMode: string = '';
  /** The effective policy really requires a local approval for every connection. */
  @Trace localApprovalEnforced: boolean = false;
  /** This service's own scoped policy is what requires it, and it reverts on stop. */
  @Trace approveModeScoped: boolean = false;
  /** Whether the Core option forwards this device's audio. */
  @Trace audioEnabled: boolean = true;
  @Trace runningInBackground: boolean = false;
}

export type ControlledHostStateListener = (state: ControlledHostState) => void;

/**
 * One host answer, in the field names the RustDesk host adapter really emits.
 *
 * A field the core has no record for is absent, so a reader applies its own
 * fail-closed default instead of this layer inventing one. There is no
 * `nativeStateCode`: the SDK's own state callback code is `sdkStateCode`, and it
 * is reported verbatim rather than interpreted as a verdict.
 */
export interface ControlledNativeActionPayload {
  ok?: boolean;
  /** `live` | `failed` | `idle` for the capture owner; `ready` | `failed` | `stopped` for the server. */
  state?: string;
  /** The capture owner is really producing. */
  active?: boolean;
  /**
   * The same fact as `active`, under the name the server status uses.
   *
   * Either may be absent: a reader treats a missing liveness field as "not
   * shown to be running" rather than as a claim it is.
   */
  captureActive?: boolean;
  /** The SDK's own screen-capture state callback code, verbatim. */
  sdkStateCode?: number | null;
  /** The system consented to capturing this screen and it is confirmed. */
  systemCaptureConfirmed?: boolean;
  /** Access units the producer really emitted. */
  framesObserved?: number;
  /** The owner reported a terminal reason; nothing will resume on its own. */
  terminal?: boolean;
  terminalReason?: string | null;
  /** A previous close could not be confirmed: fail closed until a later status clears it. */
  teardownUnconfirmed?: string | null;
  consentState?: string | null;
  codec?: string;
  width?: number;
  height?: number;
  bitrateBps?: number | null;
  encoderName?: string;
  queuedUnits?: number;
  queuedBytes?: number;
  closed?: boolean;
  quarantined?: boolean;
  error?: string | null;
  message?: string;
  lastError?: string;
}

export interface ControlledPasswordPayload extends ControlledNativeActionPayload {
  temporaryPassword?: string;
  verificationMethod?: string;
  permanentPasswordSet?: boolean;
  localPermanentPasswordSet?: boolean;
  verificationMethodFixed?: boolean;
  permanentPasswordChangeDisabled?: boolean;
  maxPasswordLength?: number;
}

export interface ControlledServerStatusPayload extends ControlledNativeActionPayload {
  serverRunning?: boolean;
  /** The device id; absent from the credential-free stop answers. */
  myId?: string;
  /** The temporary password; absent from the credential-free stop answers. */
  temporaryPassword?: string;
  clientCount?: number;
  /** Whether the Core option forwards this device's audio. */
  audioEnabled?: boolean;
  /** The real local-approval policy: `both` | `password` | `click`. */
  approveMode?: string;
  /** The effective policy really requires a local approval for every connection. */
  localApprovalEnforced?: boolean;
  /** This service's own scoped policy is what requires it; it reverts when the service stops. */
  approveModeScoped?: boolean;
}

export interface ControlledIncomingPayload {
  ok?: boolean;
  message?: string;
  lastError?: string;
  clients?: ControlledIncomingPeer[];
  requests?: ControlledIncomingPeer[];
  totalRequests?: number;
  totalClients?: number;
  /** A list was cut by the limit, so this batch is not the whole state. */
  truncated?: boolean;
}

export interface ControlledTwoFactorPayload extends ControlledNativeActionPayload {
  enabled?: boolean;
  uri?: string;
  trustedDevicesEnabled?: boolean;
  trustedDevicesFixed?: boolean;
  trustedDevices?: ControlledTrustedDevice[];
}
