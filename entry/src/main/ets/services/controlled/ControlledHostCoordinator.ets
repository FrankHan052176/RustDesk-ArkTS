import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ControlledHostBackgroundService } from './ControlledHostBackgroundService';
import {
  ControlledHostState,
  ControlledHostStateListener,
  ControlledInputAuthorizationPayload,
  ControlledInputAuthorizationStatus,
  ControlledIncomingPeer,
  ControlledPasswordMode,
  ControlledTrustedDevice,
  ControlledTwoFactorState,
  PASSWORD_MODE_BOTH,
  PASSWORD_MODE_PERMANENT,
  PASSWORD_MODE_TEMPORARY,
} from './ControlledHostTypes';
import { NativeHostBridge } from './NativeHostBridge';
import { rustDeskRuntimeController, RustDeskRuntimeState } from '../RustDeskRuntimeController';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskViewedHost';
const POLL_INTERVAL_MS = 250;
const STOPPING_RECHECK_MS = 250;
/**
 * The capture-fact sample interval.
 *
 * The poll runs every 250 ms; writing its whole status text four times a second
 * pushed the real failures out of the device log window. One sample per five
 * seconds keeps the counters readable as a progression and leaves the log for
 * errors. Nothing else in this coordinator is throttled.
 */
const CAPTURE_DIAG_INTERVAL_MS = 5000;
/** The native teardown bound is 30 s; this only observes it from the foreground. */
const STOPPING_RECHECK_LIMIT = 120;
/**
 * The real background fact of a consented run.
 *
 * A foreground/background transition retires discovery/presence and the injection
 * grant only; the viewed-host run keeps listening and capturing, so nothing here
 * claims a close the engine never requested.
 */
const BACKGROUND_KEEPALIVE_TEXT = '已进入后台，被看服务继续运行';

/**
 * The start request the legacy UI built.
 *
 * `requireLocalApproval: false` selects the engine's password-or-click policy,
 * which is what the operator asked for: a controller authenticates with this
 * run's real temporary or permanent password, or waits for a click on this
 * machine. Neither path is an auto-approval, and the panel prints the policy the
 * native run actually reports. Clipboard stays off. Input
 * is opt-in for one explicit control-start action and only a fresh OS-authorized
 * fact admits it; ordinary start remains view-only. Desktop audio is requested
 * and reported: this engine has no audio owner yet, so the answer carries
 * `audioEnabled: false` instead of a silent success.
 *
 * `approvedServerProfile` is the explicitly saved v2 profile the run registers
 * with; it is filled only from `runtimeGetServerConfig`, never from a draft, a
 * LAN hit or a target string.
 */
class ControlledStartOptions {
  requireLocalApproval: boolean = false;
  enableInput: boolean = false;
  inputAuthorizationRequestId: string = '';
  enableClipboard: boolean = false;
  enableAudio: boolean = true;
  approvedServerProfile: Object | undefined = undefined;
}

class ControlledScreenOptions {
  displayId: number = 0;
  width: number = 0;
  height: number = 0;
  frameRate: number = 30;
}

/**
 * The fields this coordinator reads from one host answer, in the names the
 * engine's host service, security owner and profile store really emit.
 *
 * Every fact is optional: a field an answer does not carry is absent, and each
 * reader applies its own fail-closed default instead of this layer inventing one.
 */
interface HostPayload {
  ok?: boolean;
  action?: string;
  /** `disabled` | `starting` | `listening` | `stopping` | `failed`. */
  state?: string;
  serverRunning?: boolean;
  myId?: string;
  temporaryPassword?: string;
  verificationMethod?: string;
  permanentPasswordSet?: boolean;
  localPermanentPasswordSet?: boolean;
  verificationMethodFixed?: boolean;
  permanentPasswordChangeDisabled?: boolean;
  maxPasswordLength?: number;
  passwordSettingsSupported?: boolean;
  approveMode?: string;
  localApprovalEnforced?: boolean;
  approveModeScoped?: boolean;
  audioEnabled?: boolean;
  inputEnabled?: boolean;
  inputAuthorization?: ControlledInputAuthorizationStatus;
  audioSupported?: boolean;
  audioRequested?: boolean;
  registration?: string;
  runEpoch?: string;
  peerCount?: number;
  clientCount?: number;
  /** The capture owner's own consent state, verbatim. */
  captureState?: string | null;
  captureActive?: boolean;
  systemCaptureConfirmed?: boolean;
  framesObserved?: number;
  /** The encoded bytes the same capture owner really produced. */
  captureEncodedBytes?: number;
  /** Which owner really holds the capture: `run`, `peer`, or none at all. */
  captureOwner?: string | null;
  /** Unix ms the run-level capture owner was created; null for a peer owner. */
  captureOpenedAtMs?: number | null;
  sdkStateCode?: number | null;
  consentState?: string | null;
  terminal?: boolean;
  terminalReason?: string | null;
  teardownUnconfirmed?: string | null;
  error?: string | null;
  message?: string;
  lastError?: string;
  /** 2FA document. */
  enabled?: boolean;
  setupPending?: boolean;
  uri?: string;
  trustedDevicesEnabled?: boolean;
  trustedDevicesFixed?: boolean;
  trustedDevices?: ControlledTrustedDevice[];
  /** Setting document. */
  key?: string;
  value?: string;
  /** Saved-profile document. */
  approved?: boolean;
  approvedProfile?: Object;
  revision?: string;
  /** Incoming-connection documents. */
  requests?: ControlledIncomingPeer[];
  clients?: ControlledIncomingPeer[];
  totalRequests?: number;
  totalClients?: number;
  truncated?: boolean;
}

/**
 * A run epoch is the nonzero decimal `u64` the engine spelled, and nothing else.
 *
 * `controlledServerStop('')` means "stop the run this process currently has", so
 * an empty, zero or non-decimal string is never sent: it would name a run this
 * panel never admitted.
 */
function isRunEpoch(value: string): boolean {
  if (value.length === 0 || value.charCodeAt(0) === 0x30) {
    return false;
  }
  for (let index = 0; index < value.length; index += 1) {
    const code: number = value.charCodeAt(index);
    if (code < 0x30 || code > 0x39) {
      return false;
    }
  }
  return true;
}

/** The run epoch an answer really names, or empty when it names none. */
function runEpochOf(payload: HostPayload): string {
  const raw: string = payload.runEpoch ?? '';
  return isRunEpoch(raw) ? raw : '';
}

/** The run a diagnostic line really names: the epoch, `none`, or `missing`. */
function runEpochFact(payload: HostPayload): string {
  if (payload.runEpoch === undefined) {
    return 'missing';
  }
  const epoch: string = runEpochOf(payload);
  return epoch.length > 0 ? epoch : 'none';
}

/** A number the answer really carries; a null is `none`, an absent one `missing`. */
function numberFact(value: number | null | undefined): string {
  if (value === undefined) {
    return 'missing';
  }
  return value === null ? 'none' : String(value);
}

/** A boolean the answer really carries: an absent one is never reported as `false`. */
function booleanFact(value: boolean | undefined): string {
  if (value === undefined) {
    return 'missing';
  }
  return value ? 'true' : 'false';
}

/** A closed engine enum (`captureOwner`, `captureState`), or how it was omitted. */
function enumFact(value: string | null | undefined): string {
  if (value === undefined) {
    return 'missing';
  }
  return value === null || value.length === 0 ? 'none' : value;
}

/**
 * The host may be admitted only by the one native lifecycle receipt: current
 * privacy consent and foreground, a completed `appInit`, and the native owner
 * generation that receipt named. A pending update, a failed one or a bare
 * `ready` (the private root stays initialized across a fence) admit nothing.
 */
function runtimeAdmits(runtime: RustDeskRuntimeState): boolean {
  return !runtime.pending && runtime.privacyAccepted && runtime.foreground && runtime.ready &&
    runtime.discoveryAllowed && runtime.ownerGeneration.length > 0;
}

/** Why a start is refused right now, from the same lifecycle state. */
function runtimeBlockText(runtime: RustDeskRuntimeState): string {
  if (!runtime.privacyAccepted) {
    return '尚未获得隐私授权，无法启用被看服务。';
  }
  if (!runtime.foreground) {
    return '应用不在前台，无法启用被看服务。';
  }
  if (runtime.pending) {
    return 'RustDesk Core 正在初始化，请稍后重试。';
  }
  if (runtime.error.length > 0) {
    return `RustDesk Core 初始化失败：${runtime.error}`;
  }
  return 'RustDesk Core 尚未就绪，请稍后重试。';
}

/**
 * What the panel says when a real close is being observed.
 *
 * A withdrawn consent is the only lifecycle fact that makes the native fence close
 * the viewed-host run, and it is reported as exactly that.
 */
const PRIVACY_WITHDRAWN_TEXT = '隐私授权已撤回：已请求关闭被看服务';

/** One queued security operation and the panel generation it was queued for. */
class SecurityTicket {
  readonly panel: number;
  readonly operation: () => Promise<void>;

  constructor(panel: number, operation: () => Promise<void>) {
    this.panel = panel;
    this.operation = operation;
  }
}

/** One explicit authorization wait, owned by the start and panel that requested it. */
class InputAuthorizationWait {
  readonly generation: number;
  readonly panel: number;
  readonly requestId: string;
  readonly finish: (error: Error | undefined) => void;

  constructor(generation: number, panel: number, requestId: string, finish: (error: Error | undefined) => void) {
    this.generation = generation;
    this.panel = panel;
    this.requestId = requestId;
    this.finish = finish;
  }
}

/** Unknown/missing native authorization is never promoted to a grant. */
function inputAuthorizationOf(value: string | undefined): ControlledInputAuthorizationStatus {
  if (value === 'unauthorized' || value === 'authorizing' || value === 'authorized' || value === 'unsupported') {
    return value;
  }
  return 'failed';
}

export class ControlledHostCoordinator {
  readonly state: ControlledHostState = new ControlledHostState();
  readonly twoFactorState: ControlledTwoFactorState = new ControlledTwoFactorState();
  private context: common.UIAbilityContext | undefined = undefined;
  private backgroundService: ControlledHostBackgroundService | undefined = undefined;
  private bridge: NativeHostBridge = new NativeHostBridge();
  private listeners: ControlledHostStateListener[] = [];
  private pollTimer: number = -1;
  private pollInFlight: boolean = false;
  /** The last capture-fact sample (wall-clock ms); `0` means none was printed yet. */
  private captureDiagAtMs: number = 0;
  private generation: number = 0;
  /** The one start attempt in flight, kept until its run is closed or admitted. */
  private startTask: Promise<void> | undefined = undefined;
  private inputAuthorizationWait: InputAuthorizationWait | undefined = undefined;
  /** Pending/pre-run authorization only; a run that really starts owns its own grant. */
  private inputAuthorizationRequestId: string = '';
  /** A control run must fail closed on revocation, not silently become view-only. */
  private runRequiresInput: boolean = false;
  private initialized: boolean = false;
  /**
   * True only between a native lifecycle receipt that admits the host and the
   * next change of that state. It is derived, never set by a caller: the single
   * writer is `applyRuntimeState`, fed by RustDeskRuntimeController.
   */
  private runtimeReady: boolean = false;
  /** The native discovery/lifecycle owner generation `runtimeReady` was granted for. */
  private runtimeOwner: string = '';
  private runtimeBlock: string = 'RustDesk Core 尚未就绪，请稍后重试。';
  /**
   * The app-foreground fact the current lifecycle state reports.
   *
   * A backgrounded app keeps a consented run, so this only decides how a live
   * status text names that fact; it never withdraws a run by itself.
   */
  private appInBackground: boolean = false;
  private runtimeListener: (runtime: RustDeskRuntimeState) => void = (runtime: RustDeskRuntimeState): void => {
    this.applyRuntimeState(runtime);
  };
  private resolvingRequestId: string = '';
  private resolvingAccepted: boolean = false;
  /** The run epoch this coordinator admitted; every stop names it. */
  private runEpoch: string = '';
  /** A panel generation keeps a late security answer out of a newer panel. */
  private panelGeneration: number = 0;
  /** Invalidates an enrolment URI that a cancelled/backgrounded begin still owes. */
  private twoFactorSetupGeneration: number = 0;
  private stoppingTimer: number = -1;
  private stoppingAttempts: number = 0;
  /**
   * One security operation at a time: the store is one record, not a queue.
   *
   * Each entry carries the panel generation it was queued for; that is captured
   * at enqueue and never re-read when the closure finally runs.
   */
  private securityQueue: SecurityTicket[] = [];
  private securityRunning: boolean = false;

  initialize(context: common.UIAbilityContext): void {
    if (this.initialized) {
      this.onAbilityForeground();
      return;
    }
    this.context = context;
    this.backgroundService = new ControlledHostBackgroundService(context, (): void => {
      void this.failClosed('系统已终止被看服务后台任务');
    });
    this.initialized = true;
    this.runtimeReady = false;
    this.runtimeOwner = '';
    this.panelGeneration += 1;
    this.state.temporaryPassword = '';
    // Nothing queued for the panel that just went away may run against this one.
    this.securityQueue = [];
    this.twoFactorState.busy = false;
    this.twoFactorState.setupUri = '';
    this.twoFactorState.verificationCode = '';
    this.state.phase = 'disabled';
    this.state.audioEnabled = false;
    this.state.statusText = '可启用屏幕共享（设备内音频尚未实现）';
    this.state.lastError = '';
    this.emitState();
    // The listener is handed the current lifecycle state at once, so a runtime
    // that is already admitted is picked up here and not only on the next change.
    rustDeskRuntimeController.addListener(this.runtimeListener);
  }

  /**
   * The only writer of `runtimeReady`: a change of the native lifecycle state.
   *
   * Every lifecycle update is a native fence that invalidates this admission
   * synchronously (`pending`) before its receipt arrives. Admission is therefore
   * granted only by a current, completed receipt and is withdrawn by the next
   * update, whatever its cause (a foreground/background transition, a consent
   * change, a same-state refresh or a destroy). A late receipt of a superseded
   * update never reaches this method.
   *
   * What that fence really closes is the *new* state's own consent answer: with
   * consent it retires discovery/presence and the injection grant and leaves the
   * listening run, its peers and its capture alone. The panel therefore keeps a
   * run it really still has and observes a close only when one really happened.
   */
  private applyRuntimeState(runtime: RustDeskRuntimeState): void {
    if (!this.initialized) {
      return;
    }
    this.appInBackground = !runtime.foreground;
    const admitted: boolean = runtimeAdmits(runtime);
    if (admitted && this.runtimeReady && this.runtimeOwner === runtime.ownerGeneration) {
      return; // Same owner: a LAN notification, not a lifecycle change.
    }
    if (this.runtimeReady) {
      this.runtimeReady = false;
      this.runtimeOwner = '';
      this.withdrawAdmission(runtime);
    }
    if (!admitted) {
      this.runtimeBlock = runtimeBlockText(runtime);
      return;
    }
    this.runtimeBlock = '';
    this.runtimeReady = true;
    this.runtimeOwner = runtime.ownerGeneration;
    // A host closed by the previous fence may still be settling.
    this.stoppingAttempts = 0;
    this.reconcileStoppedRun();
    this.publishIdentity();
    this.refreshPasswordState();
    this.refreshTwoFactorState();
  }

  /**
   * What one withdrawn admission really did to the run this panel owns.
   *
   * The fence closes the host only when the new lifecycle state carries no privacy
   * consent; a foreground/background transition keeps it. The panel mirrors exactly
   * that instead of assuming either outcome: a consented run that is still
   * listening stays this panel's run, and a run that is really not listening any
   * more is observed as a close rather than reported as still sharing.
   */
  private withdrawAdmission(runtime: RustDeskRuntimeState): void {
    if (!runtime.privacyAccepted) {
      this.retireRuntimeAdmission(PRIVACY_WITHDRAWN_TEXT, runtime.foreground);
      return;
    }
    const unkept: string = this.keepConsentedRun(runtime.foreground);
    if (unkept.length > 0) {
      this.retireRuntimeAdmission(unkept, runtime.foreground);
    }
  }

  /**
   * Keeps the running host a consent-preserving fence did not close.
   *
   * The empty string means the run this panel owns is still the engine's listening
   * run and was kept; anything else is the honest reason it cannot be kept, and the
   * caller then observes the real close. Nothing here stops the run and nothing here
   * claims a close that was never requested: the temporary password, the continuous
   * task, pending connections and polling stay with the run they belong to.
   */
  private keepConsentedRun(foreground: boolean): string {
    if (this.startTask !== undefined) {
      // A start admitted for the withdrawn generation cannot complete: native
      // refuses it at resolution and closes whatever that attempt really created.
      // It is abandoned like any other superseded attempt.
      return '被看服务启动已被系统生命周期中断，正在请求关闭';
    }
    if (!this.running()) {
      return ''; // Nothing is owned here: no run and no close to observe.
    }
    let payload: HostPayload;
    try {
      payload = this.parse(this.bridge.status());
    } catch (error) {
      return `无法读取原生被看服务状态：${String(error)}`;
    }
    if (payload.ok !== true || payload.serverRunning !== true || payload.state !== 'listening' ||
      runEpochOf(payload) !== this.runEpoch) {
      return '原生被看服务已不在监听，正在确认关闭';
    }
    this.stoppingAttempts = 0;
    this.clearStoppingTimer();
    this.applyHostPolicy(payload);
    this.applyInputPolicy(payload);
    this.state.lastError = '';
    if (!foreground) {
      // Only a background transition needs new words; a foreground one keeps the
      // text the run already has and refreshes it from the real status.
      this.state.statusText = BACKGROUND_KEEPALIVE_TEXT;
    }
    this.emitState();
    this.schedulePoll(0);
    return '';
  }

  /** The background fact a live status text names, or nothing. */
  private backgroundSuffix(): string {
    return this.appInBackground ? '；应用在后台，被看服务继续运行' : '';
  }

  /**
   * The engine's status document carries the local ID only after the host bridge
   * was handed it by `configureScreen` or a start, and no run exists yet. Handing
   * it the display geometry (the same call a start makes; it starts no capture
   * and grants no consent) is what makes the device ID readable before the first
   * start. A refusal leaves the ID empty rather than invented.
   */
  private publishIdentity(): void {
    if (this.startTask === undefined && (this.state.phase === 'disabled' || this.state.phase === 'failed')) {
      try {
        const configured: HostPayload = this.configureDisplay();
        if (configured.ok !== true) {
          hilog.warn(DOMAIN, TAG, 'Display geometry was not published: %{public}s',
            this.failureText(configured, 'refused'));
        }
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Display geometry was not published: %{public}s', String(error));
      }
    }
    this.refreshIdentityState();
  }

  private configureDisplay(): HostPayload {
    const displayInfo = display.getDefaultDisplaySync();
    const screenOptions = new ControlledScreenOptions();
    screenOptions.displayId = displayInfo.id;
    screenOptions.width = displayInfo.width;
    screenOptions.height = displayInfo.height;
    return this.parse(this.bridge.configureScreen(JSON.stringify(screenOptions)));
  }

  addStateListener(listener: ControlledHostStateListener): void {
    for (let index = 0; index < this.listeners.length; index += 1) {
      if (this.listeners[index] === listener) {
        listener(this.state);
        return;
      }
    }
    this.listeners.push(listener);
    listener(this.state);
  }

  removeStateListener(listener: ControlledHostStateListener): void {
    for (let index = 0; index < this.listeners.length; index += 1) {
      if (this.listeners[index] === listener) {
        this.listeners.splice(index, 1);
        return;
      }
    }
  }

  /**
   * Starts the host service and stops at the listener/route admission.
   *
   * A controller has not connected and the system has not consented to capture:
   * both are normal after a successful start. `ready` therefore means "the host
   * can be reached", never "this screen is being shared". The approved profile is
   * the explicitly saved one; a run never derives a server from a draft or scan.
   */
  start(): Promise<void> {
    return this.startHost(false);
  }

  /** Called only by the foreground card's explicit authorization/start action. */
  startWithInput(): Promise<void> {
    if (this.running()) {
      this.state.lastError = '请先停止当前服务，确认停止后再授权并启用远程控制。';
      this.emitState();
      return Promise.resolve();
    }
    return this.startHost(true);
  }

  private async startHost(enableInput: boolean): Promise<void> {
    if (!this.initialized || this.startTask !== undefined || this.running()) {
      return;
    }
    if (this.state.phase === 'starting') {
      return;
    }
    const task: Promise<void> = this.performStart(enableInput);
    this.startTask = task;
    try {
      await task;
    } finally {
      if (this.startTask === task) {
        this.startTask = undefined;
      }
    }
  }

  /**
   * One start attempt: from the saved server record to the live listener.
   *
   * A stop, a background transition or a destroy that lands on any await below
   * supersedes `generation`. From then on this attempt may still close the run
   * the engine really created, but it dispatches no further start, adopts no
   * epoch and rewrites none of the newer generation's state or policy.
   */
  private async performStart(enableInput: boolean): Promise<void> {
    if (this.state.phase === 'stopping') {
      this.stoppingAttempts = 0;
      this.reconcileStoppedRun();
      if (this.state.phase === 'stopping') {
        this.state.lastError = '被看服务正在停止，请稍后重试。';
        this.state.statusText = this.state.lastError;
        this.emitState();
        return;
      }
    }
    if (!this.runtimeReady) {
      // Refused at the source: native would refuse the same start (app scope),
      // and nothing is dispatched or faked ready here.
      this.state.lastError = this.runtimeBlock;
      this.state.statusText = this.state.lastError;
      this.emitState();
      return;
    }
    const currentGeneration = this.generation + 1;
    this.generation = currentGeneration;
    const backgroundService = this.backgroundService;
    this.stoppingAttempts = 0;
    this.clearStoppingTimer();
    this.state.phase = 'starting';
    this.state.statusText = '正在启动被看服务（等待本机监听就绪）';
    this.state.lastError = '';
    this.emitState();
    let attemptedEpoch: string = '';
    let authorizationRequestId: string = '';
    try {
      const config = this.parse(await this.bridge.serverConfig());
      if (currentGeneration !== this.generation) {
        // A stop/background arrived while the record was being read: nothing has
        // been dispatched yet, so this attempt dispatches nothing more.
        return;
      }
      if (config.ok !== true) {
        throw new Error(this.failureText(config, '无法读取服务器配置'));
      }
      if (config.approved !== true || config.approvedProfile === undefined) {
        throw new Error('尚未保存并确认服务器配置：请先在设置中保存 ID/中继服务器后再启用被看服务');
      }
      const backgroundFailure = await backgroundService?.start();
      if (currentGeneration !== this.generation) {
        // Only the continuous task this attempt started is released; the run
        // itself was never asked for.
        backgroundService?.stop();
        return;
      }
      if (backgroundFailure === undefined) {
        throw new Error('被看服务后台任务不可用');
      }
      if (backgroundFailure.length > 0) {
        // The system's own reason (a mode this UIAbility has not declared, a
        // denied permission) is the only actionable answer for this failure.
        throw new Error(backgroundFailure);
      }
      this.requireSuccess(this.configureDisplay(), '屏幕参数配置失败');
      if (currentGeneration !== this.generation) {
        backgroundService?.stop();
        return;
      }
      // Query on every start, including view-only. Only this explicit input
      // path requests a new authorization-owner token; a previous grant or a
      // local setting cannot supply one. The existing poll observes its dialog.
      this.readInputAuthorization();
      if (enableInput) {
        authorizationRequestId = await this.authorizeInput(currentGeneration);
        if (currentGeneration !== this.generation) {
          return;
        }
        const admission = this.readInputAuthorization();
        if (admission.requestId !== authorizationRequestId) {
          throw new Error('远程控制授权请求已失效，请重新操作。');
        }
        if (admission.ok !== true || admission.status !== 'authorized') {
          throw this.inputAuthorizationError(admission);
        }
      }
      if (currentGeneration !== this.generation) {
        return;
      }
      const startOptions = new ControlledStartOptions();
      startOptions.approvedServerProfile = config.approvedProfile;
      startOptions.enableInput = enableInput;
      startOptions.inputAuthorizationRequestId = authorizationRequestId;
      // Everything above is admission; this is the one call that creates a run.
      const rawStartReply = this.parse(await this.bridge.start(JSON.stringify(startOptions)));
      attemptedEpoch = runEpochOf(rawStartReply);
      if (currentGeneration !== this.generation) {
        // Native start was already dispatched under the superseded generation.
        // The run it really created is closed by the epoch that reply named and
        // joined; nothing of the newer generation's state, epoch or policy is
        // touched by this older answer.
        await this.stopNative(attemptedEpoch, currentGeneration);
        return;
      }
      // A failed start still names the run it attempted, so a later stop names
      // that run instead of a stale one.
      if (attemptedEpoch.length > 0) {
        this.runEpoch = attemptedEpoch;
        // The native run now owns authorization cleanup through its checked
        // close. Only that epoch stop may release it; pending cancel may not.
        if (this.inputAuthorizationRequestId === authorizationRequestId) {
          this.inputAuthorizationRequestId = '';
        }
      }
      this.applyInputPolicy(rawStartReply);
      const startReply = this.requireSuccess(rawStartReply, 'RustDesk 被看服务启动失败');
      if (startReply.serverRunning !== true || startReply.state !== 'listening') {
        throw new Error(this.failureText(startReply, '原生被看服务未进入监听状态'));
      }
      const epoch: string = runEpochOf(startReply);
      if (epoch.length === 0) {
        throw new Error('原生被看服务未返回本次运行的 epoch，无法停止或复核该次运行');
      }
      this.runEpoch = epoch;
      if (this.state.inputEnabled !== enableInput ||
        (enableInput && this.state.inputAuthorization !== 'authorized')) {
        throw new Error('原生服务未确认本次远程控制模式，正在停止；未将其视为控制成功。');
      }
      this.runRequiresInput = enableInput;
      // A listening run is one the engine really owns: an unconfirmed earlier
      // reclamation would have refused this launch, so nothing is stale here.
      this.state.teardownUnconfirmed = '';
      // Listening is not capture: the capture fields are adopted exactly as the
      // answer reports them (none before a controller asks to be viewed).
      this.applyHostPolicy(startReply);
      this.state.runningInBackground = backgroundService?.isRunning() === true;
      this.state.phase = 'ready';
      this.state.statusText = this.readyStatusText();
      this.state.lastError = '';
      this.emitState();
      this.reportCapture(startReply, true);
      if (currentGeneration !== this.generation) {
        // Superseded while this answer was being published: the run this attempt
        // created is closed by its own epoch and joined, and the newer generation
        // keeps its own state.
        await this.stopNative(epoch, currentGeneration);
        return;
      }
      this.refreshPasswordState();
      this.schedulePoll(0);
    } catch (error) {
      // A stop admitted while this start was in flight owns the close; a failed
      // start must not overwrite that newer generation's state.
      if (currentGeneration === this.generation) {
        await this.failClosed(`启动失败：${String(error)}`, attemptedEpoch);
      }
    }
  }

  async stop(reason: string = '被看服务已停止'): Promise<void> {
    this.generation += 1;
    this.cancelPendingInputAuthorization();
    const stopGeneration = this.generation;
    this.state.temporaryPassword = '';
    this.clearPoll();
    this.clearStoppingTimer();
    this.stoppingAttempts = 0;
    const backgroundService = this.backgroundService;
    this.state.phase = 'stopping';
    this.state.statusText = '正在停止被看服务，等待原生确认';
    this.emitState();
    backgroundService?.stop();
    this.state.runningInBackground = false;
    // Only a run this panel really admitted is ever named: the engine reads an
    // empty epoch as "the run this process currently has", which is not this
    // generation's run and may belong to a newer one.
    const epoch: string = this.runEpoch;
    const supersededStart: Promise<void> | undefined = this.startTask;
    if (supersededStart !== undefined) {
      // A start this stop just superseded may already own a native run, or be
      // about to own one. That attempt closes the run it really got by its real
      // epoch and joins it, so this stop waits for that close and then reads the
      // native truth instead of reporting a teardown it never named.
      await supersededStart;
      if (stopGeneration !== this.generation) {
        return;
      }
      this.reconcileStoppedRun(reason);
      return;
    }
    const stopError = await this.stopNative(epoch, stopGeneration);
    if (stopGeneration !== this.generation) {
      // A newer panel generation owns the state now; this confirmed stop still
      // stopped its own run but must not relabel that newer generation.
      return;
    }
    this.state.approveModeScoped = false;
    this.state.localApprovalEnforced = false;
    this.state.incoming = undefined;
    this.state.incomingResolving = false;
    this.resolvingRequestId = '';
    this.state.activePeerName = '';
    if (stopError.length > 0) {
      this.state.phase = 'failed';
      this.state.lastError = stopError;
      this.state.statusText = stopError;
    } else {
      // A confirmed teardown really released the one owner; nothing outside a
      // confirmed stop clears the capture facts.
      this.state.phase = 'disabled';
      this.state.captureActive = false;
      this.state.captureAuthorized = false;
      if (epoch.length > 0) {
        // This exact run was stopped and its owners joined: that is the one
        // reclamation that clears an unconfirmed earlier close.
        this.state.teardownUnconfirmed = '';
      }
      this.state.lastError = '';
      this.state.statusText = reason;
    }
    this.emitState();
  }

  rejectIncoming(requestId: string, peerId: string): void {
    this.resolveIncoming(requestId, peerId, false);
  }

  acceptIncoming(requestId: string, peerId: string): void {
    this.resolveIncoming(requestId, peerId, true);
  }

  /**
   * Latches one local decision for exactly the connection its token names.
   *
   * `requestId` is the engine's composite run/connection/approval/revision token
   * and is forwarded verbatim; it is never rebuilt and `peerId` never replaces it.
   */
  private resolveIncoming(requestId: string, peerId: string, allow: boolean): void {
    const incoming = this.state.incoming;
    if (incoming === undefined || incoming.requestId !== requestId || incoming.peerId !== peerId) {
      this.state.lastError = '连接请求已变化，请确认当前请求后重试。';
      this.emitState();
      this.schedulePoll(0);
      return;
    }
    if (this.resolvingRequestId.length > 0) {
      return;
    }
    try {
      this.requireSuccess(
        this.parse(allow ? this.bridge.acceptIncoming(incoming.requestId) :
          this.bridge.rejectIncoming(incoming.requestId)),
        allow ? '无法同意远端观看请求' : '无法拒绝远端观看请求',
      );
      this.resolvingRequestId = incoming.requestId;
      this.resolvingAccepted = allow;
      this.state.incomingResolving = true;
      this.state.statusText = allow
        ? (this.state.inputEnabled ? '已在本机同意连接，正在建立远程控制会话' : '已在本机同意观看，正在建立仅观看会话')
        : '正在拒绝并断开该请求';
      this.emitState();
      this.schedulePoll(0);
    } catch (error) {
      this.state.lastError = `${allow ? '同意' : '拒绝'}连接失败：${String(error)}`;
      this.state.statusText = this.state.lastError;
      this.emitState();
      this.schedulePoll(0);
    }
  }

  /** Reads the password panel from the record the host really authenticates with. */
  refreshPasswordState(): void {
    if (!this.runtimeReady) {
      return; // Admission re-reads it; native would only refuse outside the app scope.
    }
    this.enqueueSecurity((): Promise<void> => this.loadPasswordState());
  }

  refreshTemporaryPassword(): void {
    this.enqueueSecurity((): Promise<void> => this.replaceTemporaryPassword());
  }

  setVerificationMethod(mode: ControlledPasswordMode): void {
    if (this.state.verificationMethodFixed) {
      this.state.passwordError = '密码模式已由策略固定，无法更改。';
      this.emitState();
      return;
    }
    if (mode === PASSWORD_MODE_PERMANENT && !this.state.permanentPasswordSet) {
      this.state.passwordError = '请先设置固定密码。';
      this.emitState();
      return;
    }
    this.enqueueSecurity((): Promise<void> => this.applyVerificationMethod(mode));
  }

  setPermanentPassword(password: string, confirmation: string): void {
    if (this.state.permanentPasswordChangeDisabled) {
      this.state.passwordError = '固定密码已由策略锁定，无法更改。';
      this.emitState();
      return;
    }
    if (confirmation !== password) {
      this.state.passwordError = '两次输入的固定密码不一致。';
      this.emitState();
      return;
    }
    if (password.length > this.state.maxPasswordLength) {
      this.state.passwordError = `固定密码不能超过 ${this.state.maxPasswordLength} 个字符。`;
      this.emitState();
      return;
    }
    if (password.length > 0 && password.length < 6) {
      this.state.passwordError = '固定密码至少需要 6 个字符。';
      this.emitState();
      return;
    }
    this.enqueueSecurity((): Promise<void> => this.applyPermanentPassword(password));
  }

  clearPermanentPassword(): void {
    if (this.state.permanentPasswordChangeDisabled) {
      this.state.passwordError = '固定密码已由策略锁定，无法更改。';
      this.emitState();
      return;
    }
    // The engine's own revocation moves a permanent-only method back to `both`
    // in the same write; the reply carries the resulting method.
    this.enqueueSecurity((): Promise<void> => this.applyPermanentPassword(''));
  }

  refreshTwoFactorState(): void {
    if (!this.runtimeReady) {
      return;
    }
    this.enqueueSecurity((): Promise<void> => this.loadTwoFactorState());
  }

  beginTwoFactorSetup(): void {
    if (this.twoFactorState.busy || this.twoFactorState.enabled) {
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    // The enrolment identity is taken here, while the operator asked for it: a
    // cancel that lands while this call is only queued must still void it.
    const setupGeneration: number = this.twoFactorSetupGeneration;
    this.enqueueSecurity((): Promise<void> => this.runBeginTwoFactor(setupGeneration));
  }

  cancelTwoFactorSetup(): void {
    this.twoFactorSetupGeneration += 1;
    this.twoFactorState.setupUri = '';
    this.twoFactorState.verificationCode = '';
    this.twoFactorState.errorText = '';
    this.emitState();
  }

  verifyTwoFactorSetup(code: string): void {
    if (this.twoFactorState.busy) {
      return;
    }
    const trimmed: string = code.trim();
    if (trimmed.length === 0) {
      this.twoFactorState.errorText = '请输入双重认证验证码。';
      this.emitState();
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    this.enqueueSecurity((): Promise<void> => this.runVerifyTwoFactor(trimmed));
  }

  disableTwoFactor(): void {
    if (this.twoFactorState.busy) {
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    this.enqueueSecurity((): Promise<void> => this.runDisableTwoFactor());
  }

  removeTrustedDevice(device: ControlledTrustedDevice): void {
    if (this.twoFactorState.busy) {
      return;
    }
    if (device.hwid.length === 0) {
      this.twoFactorState.errorText = '该设备没有可用的设备标识，无法移除。';
      this.emitState();
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    const hwidsJson: string = JSON.stringify([device.hwid]);
    this.enqueueSecurity((): Promise<void> => this.runRemoveTrustedDevices(hwidsJson));
  }

  clearTrustedDevices(): void {
    if (this.twoFactorState.busy) {
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    this.enqueueSecurity((): Promise<void> => this.runClearTrustedDevices());
  }

  setTrustedDevicesEnabled(enabled: boolean): void {
    if (this.twoFactorState.trustedDevicesFixed) {
      this.twoFactorState.errorText = '信任设备策略已锁定，无法更改。';
      this.emitState();
      return;
    }
    if (this.twoFactorState.busy) {
      return;
    }
    this.twoFactorState.busy = true;
    this.twoFactorState.errorText = '';
    this.emitState();
    this.enqueueSecurity((): Promise<void> => this.runSetTrustedDevices(enabled));
  }

  /**
   * The app is leaving the foreground.
   *
   * The fence of this transition retires discovery/presence and the injection grant
   * only: a consented viewed-host run keeps listening and capturing in the
   * background. The panel therefore keeps that run — its temporary password, its
   * continuous task and its pending connections — and names the background fact
   * instead of claiming a close the engine never requested. A state without consent
   * is the one case where the fence really closes, and it is observed as before.
   */
  onAbilityBackground(): void {
    if (!this.initialized) {
      return;
    }
    // The lifecycle update that precedes this call already reached this decision
    // from the same state; repeating it is idempotent and keeps this hook correct
    // on its own if the Ability ever calls it in another order.
    this.withdrawAdmission(rustDeskRuntimeController.state());
  }

  /**
   * Withdraws everything one admission owned *when its run really ends*: the
   * panel's secrets and queued writes, an in-flight start, polling, and any claim
   * that a share is live.
   *
   * It is not a second stop: a fence that closes the host (a withdrawn consent or a
   * destroyed Ability) already requested the close and the owner joins its own
   * teardown. When the app is still in the foreground the close is observed at
   * once; from the background it is observed on the next foreground.
   */
  private retireRuntimeAdmission(statusText: string, foreground: boolean): void {
    this.twoFactorSetupGeneration += 1;
    this.panelGeneration += 1;
    this.state.temporaryPassword = '';
    // A write queued for the panel that is leaving may hold a permanent password
    // or an enrolment URI from that panel: it is dropped, not run later.
    this.securityQueue = [];
    this.twoFactorState.busy = false;
    if (this.twoFactorState.setupUri.length > 0) {
      this.cancelTwoFactorSetup();
    }
    const startingTask: Promise<void> | undefined = this.startTask;
    if (!this.running() && startingTask === undefined) {
      return;
    }
    if (startingTask !== undefined) {
      // A start admitted before this fence must not keep dispatching or report
      // itself ready in the background: it closes whatever the engine really
      // created and leaves the state to the newer generation.
      this.generation += 1;
      this.cancelPendingInputAuthorization();
    }
    this.clearPoll();
    this.clearStoppingTimer();
    this.backgroundService?.stop();
    this.state.runningInBackground = false;
    this.state.incoming = undefined;
    this.state.incomingResolving = false;
    this.resolvingRequestId = '';
    this.state.activePeerName = '';
    this.state.phase = 'stopping';
    this.state.statusText = statusText;
    this.emitState();
    if (foreground) {
      this.stoppingAttempts = 0;
      this.reconcileStoppedRun();
    }
  }

  /**
   * Returning to the foreground re-reads the real native status.
   *
   * The fence of this transition keeps a consented run, so a run that is really
   * still listening is still the enabled service this panel shows, and only a run
   * that really is not listening any more moves to the close observation.
   */
  onAbilityForeground(): void {
    if (!this.initialized) {
      return;
    }
    if (this.runtimeReady) {
      this.refreshIdentityState();
    }
    this.stoppingAttempts = 0;
    const unkept: string = this.keepConsentedRun(true);
    if (unkept.length > 0) {
      this.retireRuntimeAdmission(unkept, true);
    }
    this.reconcileStoppedRun();
    if (this.running()) {
      if (this.state.phase !== 'active') {
        this.state.statusText = this.readyStatusText();
      }
      this.schedulePoll(0);
    }
    this.emitState();
  }

  onAbilityDestroy(): void {
    rustDeskRuntimeController.removeListener(this.runtimeListener);
    void this.stop('应用已退出，被看服务已停止');
    this.panelGeneration += 1;
    this.twoFactorSetupGeneration += 1;
    this.state.temporaryPassword = '';
    // Nothing queued for the destroyed panel runs anywhere else, and the
    // one-time enrolment URI it was showing is released with it.
    this.securityQueue = [];
    this.twoFactorState.busy = false;
    this.twoFactorState.setupUri = '';
    this.twoFactorState.verificationCode = '';
    this.clearPoll();
    this.clearStoppingTimer();
    this.stoppingAttempts = 0;
    this.listeners = [];
    this.backgroundService = undefined;
    this.context = undefined;
    this.initialized = false;
    this.runtimeReady = false;
    this.runtimeOwner = '';
  }

  private running(): boolean {
    return this.state.phase === 'ready' || this.state.phase === 'incoming' || this.state.phase === 'active';
  }

  private normalizePasswordMode(value: string): ControlledPasswordMode {
    if (value === PASSWORD_MODE_TEMPORARY || value === PASSWORD_MODE_PERMANENT) {
      return value;
    }
    return PASSWORD_MODE_BOTH;
  }

  private parse(document: string): HostPayload {
    return JSON.parse(document) as HostPayload;
  }

  /** The run's input capability comes only from a server answer, never capture status. */
  private applyInputPolicy(payload: HostPayload): void {
    this.state.inputEnabled = payload.inputEnabled === true;
    this.state.inputAuthorization = inputAuthorizationOf(payload.inputAuthorization);
    if (this.state.inputAuthorization === 'unauthorized') {
      this.state.inputAuthorizationError = '';
    }
  }

  /** Pure OS query, including its opaque current request owner; no dialog or retries. */
  private readInputAuthorization(): ControlledInputAuthorizationPayload {
    const payload = JSON.parse(this.bridge.inputAuthorizationStatus()) as ControlledInputAuthorizationPayload;
    this.state.inputAuthorization = inputAuthorizationOf(payload.status);
    if (this.state.inputAuthorization === 'unauthorized') {
      this.state.inputAuthorizationError = '';
    }
    return payload;
  }

  private inputAuthorizationError(payload: ControlledInputAuthorizationPayload): Error {
    const code: string = payload.resultCode !== undefined && payload.resultCode !== 0
      ? `（结果码 ${payload.resultCode}）` : '';
    return new Error(`未获远程控制系统授权${code}：${payload.message ?? payload.status ?? '无法确认系统状态'}`);
  }

  /** One request per explicit control-start; even an old OS grant supplies no new owner token. */
  private async authorizeInput(generation: number): Promise<string> {
    const requested = JSON.parse(this.bridge.requestInputAuthorization()) as ControlledInputAuthorizationPayload;
    const requestId: string = requested.requestId ?? '';
    this.state.inputAuthorization = inputAuthorizationOf(requested.status);
    // Native request never lends an older token on refusal. If it created one,
    // keep it through admission/failure so only that request can be cancelled.
    if (requestId.length > 0) {
      this.inputAuthorizationRequestId = requestId;
    }
    if (requested.ok !== true || requestId.length === 0 ||
      (requested.status !== 'authorized' && requested.status !== 'authorizing')) {
      throw this.inputAuthorizationError(requested);
    }
    this.state.inputAuthorizationError = '';
    if (requested.status === 'authorized') {
      return requestId;
    }
    await new Promise<void>((resolve, reject): void => {
      this.inputAuthorizationWait = new InputAuthorizationWait(generation, this.panelGeneration, requestId,
        (error: Error | undefined): void => {
          if (error === undefined) {
            resolve();
          } else {
            reject(error);
          }
        });
      this.state.statusText = '等待系统远程控制授权';
      this.emitState();
      this.schedulePoll(0);
    });
    return requestId;
  }

  /** The existing poll services exactly this start's dialog; it never requests another. */
  private pollInputAuthorization(): void {
    const waiting = this.inputAuthorizationWait;
    if (waiting === undefined) {
      return;
    }
    if (waiting.generation !== this.generation || waiting.panel !== this.panelGeneration) {
      this.inputAuthorizationWait = undefined;
      waiting.finish(undefined);
      return;
    }
    try {
      const payload = this.readInputAuthorization();
      if (payload.requestId !== waiting.requestId) {
        throw new Error('远程控制授权请求已失效，请重新操作。');
      }
      if (payload.ok !== true || (payload.status !== 'authorizing' && payload.status !== 'authorized')) {
        throw this.inputAuthorizationError(payload);
      }
      if (payload.status === 'authorized') {
        this.inputAuthorizationWait = undefined;
        waiting.finish(undefined);
      }
      this.emitState();
    } catch (error) {
      this.inputAuthorizationWait = undefined;
      waiting.finish(new Error(String(error)));
    }
    if (this.inputAuthorizationWait === waiting) {
      this.schedulePoll(POLL_INTERVAL_MS);
    }
  }

  /**
   * Retires only the pending authorization token. A run's grant belongs to its
   * checked epoch close instead. Local wait retirement is not OS cancellation:
   * Cancel is void in the SDK, and only the following Unauthorized query proves
   * system revocation. An authorizing/authorized/error result stays visible.
   */
  private cancelPendingInputAuthorization(): void {
    const waiting = this.inputAuthorizationWait;
    this.inputAuthorizationWait = undefined;
    waiting?.finish(undefined);
    const requestId: string = this.inputAuthorizationRequestId;
    this.inputAuthorizationRequestId = '';
    if (requestId.length === 0) {
      return;
    }
    try {
      const payload = JSON.parse(this.bridge.cancelInputAuthorization(requestId)) as ControlledInputAuthorizationPayload;
      this.state.inputAuthorization = inputAuthorizationOf(payload.status);
      if (payload.ok === true && payload.status === 'unauthorized') {
        this.state.inputAuthorizationError = '';
      } else {
        const code: string = payload.resultCode !== undefined && payload.resultCode !== 0
          ? `（结果码 ${payload.resultCode}）` : '';
        this.state.inputAuthorizationError =
          `远程控制启动已取消，但系统授权撤回未确认${code}：${payload.message ?? payload.status ?? '无法确认系统状态'}`;
      }
    } catch (error) {
      this.state.inputAuthorizationError = `远程控制启动已取消，但系统授权撤回未确认：${String(error)}`;
    }
  }

  private requireSuccess(payload: HostPayload, fallback: string): HostPayload {
    if (payload.ok !== true) {
      throw new Error(this.failureText(payload, fallback));
    }
    return payload;
  }

  /** The engine's own message for a refusal, else the caller's fallback. */
  private failureText(payload: HostPayload, fallback: string): string {
    const message: string | undefined = payload.message;
    if (message !== undefined && message.length > 0) {
      return message;
    }
    const lastError: string | undefined = payload.lastError;
    if (lastError !== undefined && lastError.length > 0) {
      return lastError;
    }
    const error: string | null | undefined = payload.error;
    if (error !== undefined && error !== null && error.length > 0) {
      return error;
    }
    return fallback;
  }

  private refreshIdentityState(): void {
    try {
      const payload = this.parse(this.bridge.status());
      const myId: string = (payload.myId ?? '').trim();
      if (myId.length > 0) {
        this.state.myId = myId;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Device ID is unavailable: %{public}s', String(error));
    }
  }

  /**
   * Adopts the capture and policy facts one host answer really carries.
   *
   * `captureActive` is the owner's own claim that a non-terminal capture exists;
   * `captureAuthorized` additionally needs the system consent and at least one
   * access unit this owner produced. A listening host with no controller is
   * neither, and that is a normal state rather than a failure.
   */
  private applyHostPolicy(payload: HostPayload): void {
    const frames: number = payload.framesObserved ?? 0;
    this.state.captureActive = payload.captureActive === true;
    this.state.captureAuthorized = this.state.captureActive
      && payload.terminal !== true
      && payload.systemCaptureConfirmed === true
      && frames > 0;
    const unconfirmed: string = payload.teardownUnconfirmed ?? '';
    if (unconfirmed.length > 0) {
      // Native reclamation that was never confirmed is not un-claimed by a
      // status that merely omits the field; only a confirmed close of this exact
      // run, or a run the engine really admitted afterwards, clears it.
      this.state.teardownUnconfirmed = unconfirmed;
    }
    if (payload.approveMode !== undefined) {
      this.state.approveMode = payload.approveMode;
    }
    if (payload.localApprovalEnforced !== undefined) {
      this.state.localApprovalEnforced = payload.localApprovalEnforced;
    }
    if (payload.approveModeScoped !== undefined) {
      this.state.approveModeScoped = payload.approveModeScoped;
    }
    if (payload.audioEnabled !== undefined) {
      this.state.audioEnabled = payload.audioEnabled;
    }
  }

  /** What the owner says it is doing with this screen, from its own state only. */
  private captureText(payload: HostPayload): string {
    if (this.state.captureAuthorized) {
      return '屏幕正在共享';
    }
    const captureState: string = payload.captureState ?? '';
    if (captureState === 'awaiting_system_consent') {
      return '等待系统屏幕共享确认';
    }
    if (captureState === 'granted') {
      return '系统已确认共享，等待首帧';
    }
    if (captureState === 'stopping') {
      return '屏幕共享正在结束';
    }
    if (captureState === 'stopped') {
      return '本次屏幕共享已结束';
    }
    if (captureState === 'quarantined') {
      return '屏幕共享异常结束，需重新启动服务';
    }
    return '';
  }

  /**
   * One sampled line of capture facts, and the only capture diagnostic there is.
   *
   * Every value is a field of the native answer itself: the owner that really
   * holds the capture, the system consent it reported, the access units and
   * encoded bytes it produced, the peer counts of that run, and its opaque run
   * epoch. An omitted field prints as `missing` and a null as `none`, so a host
   * that has no capture yet is never read as an authorized one, and no low field
   * set promotes `captureActive` into consent. Only numbers, booleans, those
   * closed enums and the epoch are printed: no password, peer id or name, screen
   * geometry, free error text or panel status text reaches this line.
   *
   * `force` is the start snapshot: printed at once, and at info level so it is
   * visible even where debug lines are filtered. Every later sample is throttled
   * by `CAPTURE_DIAG_INTERVAL_MS`.
   */
  private reportCapture(payload: HostPayload, force: boolean): void {
    const now: number = Date.now();
    if (!force && this.captureDiagAtMs !== 0 && now - this.captureDiagAtMs < CAPTURE_DIAG_INTERVAL_MS) {
      return;
    }
    this.captureDiagAtMs = now;
    const facts: string = `epoch=${runEpochFact(payload)} owner=${enumFact(payload.captureOwner)}` +
      ` state=${enumFact(payload.captureState)} captureActive=${booleanFact(payload.captureActive)}` +
      ` systemCaptureConfirmed=${booleanFact(payload.systemCaptureConfirmed)}` +
      ` framesObserved=${numberFact(payload.framesObserved)}` +
      ` captureEncodedBytes=${numberFact(payload.captureEncodedBytes)}` +
      ` openedAtMs=${numberFact(payload.captureOpenedAtMs)}` +
      ` peerCount=${numberFact(payload.peerCount)} clientCount=${numberFact(payload.clientCount)}`;
    if (force) {
      hilog.info(DOMAIN, TAG, 'DIAG capture %{public}s', facts);
      return;
    }
    hilog.debug(DOMAIN, TAG, 'DIAG capture %{public}s', facts);
  }

  /** What the operator's local-approval policy really requires, or empty. */
  private approveModeText(): string {
    const scoped: string = this.state.approveModeScoped ? '（仅本次服务）' : '';
    if (this.state.approveMode === 'password') {
      return `远端需输入密码${scoped}`;
    }
    if (this.state.approveMode === 'click') {
      return `需在本机点击同意${scoped}`;
    }
    if (this.state.approveMode === 'both') {
      return `远端密码或本机点击同意${scoped}`;
    }
    return '';
  }

  /** What one new connection really needs under the owner's reported policy. */
  private approveRequirementText(): string {
    if (this.state.approveMode === 'click') {
      return '需在本机点击同意';
    }
    if (this.state.approveMode === 'password') {
      return '需由远端输入密码';
    }
    if (this.state.approveMode === 'both') {
      return '需由远端输入密码，或在本机同意';
    }
    // No policy was reported: say so instead of inventing a weaker path.
    return '等待本机审批';
  }

  /** The ready text, naming the real approval policy and the real audio state. */
  private readyStatusText(): string {
    const parts: string[] = [this.state.inputEnabled ? '远程控制已开启' : '仅观看'];
    const approval: string = this.approveModeText();
    if (approval.length > 0) {
      parts.push(approval);
    }
    if (!this.state.audioEnabled) {
      parts.push('仅屏幕，设备内音频未共享');
    }
    return parts.length > 0
      ? `被看服务已启用（${parts.join('；')}），等待远端认证`
      : '被看服务已启用，等待远端认证';
  }

  private schedulePoll(delayMs: number): void {
    if (this.pollTimer >= 0 || (!this.running() && this.inputAuthorizationWait === undefined)) {
      return;
    }
    this.pollTimer = setTimeout((): void => {
      this.pollTimer = -1;
      void this.pollOnce();
    }, delayMs) as number;
  }

  private clearPoll(): void {
    if (this.pollTimer < 0) {
      return;
    }
    clearTimeout(this.pollTimer);
    this.pollTimer = -1;
  }

  private clearStoppingTimer(): void {
    if (this.stoppingTimer < 0) {
      return;
    }
    clearTimeout(this.stoppingTimer);
    this.stoppingTimer = -1;
  }

  private refreshNativeStatus(): HostPayload {
    const payload = this.parse(this.bridge.status());
    const myId: string = (payload.myId ?? '').trim();
    if (myId.length > 0) {
      this.state.myId = myId;
    }
    const epoch: string = runEpochOf(payload);
    if (epoch !== this.runEpoch) {
      throw new Error('原生服务状态不属于本次运行，不能继续报告远程控制状态。');
    }
    this.applyHostPolicy(payload);
    this.applyInputPolicy(payload);
    if (this.runRequiresInput &&
      (!this.state.inputEnabled || this.state.inputAuthorization !== 'authorized')) {
      throw new Error('系统远程控制授权已失效或输入已关闭，正在停止本次服务。');
    }
    this.state.terminalReason = payload.terminalReason ?? payload.error ?? '';
    const nativeState: string = payload.state ?? '';
    if (payload.ok !== true || payload.serverRunning !== true || nativeState !== 'listening') {
      if (nativeState === 'disabled') {
        throw new Error('原生被看服务已停止；本次共享已结束，请重新启动');
      }
      if (nativeState === 'stopping') {
        throw new Error('原生被看服务正在停止');
      }
      throw new Error(this.failureText(payload, '原生被看服务已停止监听'));
    }
    if (this.state.teardownUnconfirmed.length > 0) {
      throw new Error(this.state.teardownUnconfirmed);
    }
    if ((payload.lastError ?? '').length > 0) {
      throw new Error(payload.lastError ?? '原生服务报告失败');
    }
    return payload;
  }

  private async pollOnce(): Promise<void> {
    if (this.inputAuthorizationWait !== undefined) {
      this.pollInputAuthorization();
      return;
    }
    if (this.pollInFlight || !this.running()) {
      return;
    }
    this.pollInFlight = true;
    try {
      const status = this.refreshNativeStatus();
      // The same owner's capture projection; it is a read, not a second owner,
      // and a listening host with no controller legitimately has no capture.
      const capture = this.parse(this.bridge.screenCaptureStatus());
      this.applyHostPolicy(capture);
      const incomingPayload = this.parse(this.bridge.pollIncoming(256));
      if (incomingPayload.ok !== true) {
        throw new Error(this.failureText(incomingPayload, '无法读取被看连接列表'));
      }
      this.applyIncoming(incomingPayload, status);
      this.emitState();
      this.reportCapture(status, false);
    } catch (error) {
      await this.failClosed(`服务轮询失败：${String(error)}`);
      return;
    } finally {
      this.pollInFlight = false;
    }
    this.schedulePoll(POLL_INTERVAL_MS);
  }


  private applyIncoming(incomingPayload: HostPayload, status: HostPayload): void {
    const requests: ControlledIncomingPeer[] = incomingPayload.requests ?? [];
    const clients: ControlledIncomingPeer[] = incomingPayload.clients ?? [];
    let activePeer: ControlledIncomingPeer | undefined = undefined;
    for (let index = 0; index < clients.length; index += 1) {
      if (clients[index].authorized) {
        activePeer = clients[index];
        break;
      }
    }
    let nextRequest: ControlledIncomingPeer | undefined = undefined;
    let resolvingRequest: ControlledIncomingPeer | undefined = undefined;
    let displayedRequest: ControlledIncomingPeer | undefined = undefined;
    for (let index = 0; index < requests.length; index += 1) {
      if (!requests[index].authorized) {
        if (nextRequest === undefined) {
          nextRequest = requests[index];
        }
        if (requests[index].requestId === this.resolvingRequestId) {
          resolvingRequest = requests[index];
        }
        if (this.state.incoming !== undefined &&
          requests[index].requestId === this.state.incoming.requestId &&
          requests[index].peerId === this.state.incoming.peerId) {
          displayedRequest = requests[index];
        }
      }
    }
    const resolutionStillPending: boolean = resolvingRequest !== undefined;
    if (resolvingRequest !== undefined) {
      nextRequest = resolvingRequest;
    } else if (displayedRequest !== undefined) {
      nextRequest = displayedRequest;
    }
    if (!resolutionStillPending) {
      this.resolvingRequestId = '';
      this.state.incomingResolving = false;
    }
    if (activePeer !== undefined) {
      this.state.activePeerName = activePeer.peerName.length > 0 ? activePeer.peerName : activePeer.peerId;
    } else {
      this.state.activePeerName = '';
    }
    const capture: string = this.captureText(status);
    const captureSuffix: string = capture.length > 0 ? `；${capture}` : '';
    const inputSuffix: string = this.state.inputEnabled ? '；远程控制已开启' : '；仅观看';
    if (nextRequest !== undefined) {
      this.state.incoming = nextRequest;
      this.state.incomingResolving = resolutionStillPending && nextRequest.requestId === this.resolvingRequestId;
      const peerLabel: string = nextRequest.peerName.length > 0 ? nextRequest.peerName : nextRequest.peerId;
      this.state.phase = 'incoming';
      if (this.state.incomingResolving) {
        this.state.statusText = this.resolvingAccepted ? `已在本机同意连接${inputSuffix}；等待系统屏幕共享确认` :
          '正在拒绝并断开该请求';
      } else if (activePeer !== undefined) {
        this.state.statusText =
          `正在连接 ${this.state.activePeerName}${captureSuffix}${inputSuffix}；${peerLabel} 请求连接，${this.approveRequirementText()}`;
      } else {
        this.state.statusText = `${peerLabel} 请求连接，${this.approveRequirementText()}${inputSuffix}`;
      }
    } else if (activePeer !== undefined) {
      this.state.incoming = undefined;
      this.state.phase = 'active';
      this.state.statusText = capture.length > 0
        ? `已连接 ${this.state.activePeerName}${captureSuffix}${inputSuffix}`
        : `已连接 ${this.state.activePeerName}${inputSuffix}，等待系统屏幕共享确认`;
    } else {
      this.state.incoming = undefined;
      if (this.state.phase === 'incoming' || this.state.phase === 'active') {
        this.state.phase = 'ready';
      }
      this.state.statusText = this.readyStatusText();
    }
    const plainClient: boolean = clients.some((peer: ControlledIncomingPeer): boolean => peer.encrypted === false);
    if (nextRequest?.encrypted === false || plainClient) {
      this.state.statusText += '；未加密连接，控制端身份未验证';
    } else if (activePeer?.encrypted === true || nextRequest?.encrypted === true) {
      this.state.statusText += '；传输已加密';
      if (activePeer?.peerVerified === false || nextRequest?.peerVerified === false) {
        this.state.statusText += '，控制端身份未验证';
      }
    }
    // The app being in the background does not end this run: every text above
    // keeps the fact it reports and additionally names that one.
    this.state.statusText = `${this.state.statusText}${this.backgroundSuffix()}`;
  }

  /**
   * Observes the fence-driven close from the foreground.
   *
   * The native service is not this call's to stop: the lifecycle fence already
   * requested it and its own owner joins. This only reads the real state, so a
   * disabled service is reported as disabled and an unconfirmed reclamation is
   * reported as a failure instead of a silent success.
   */
  private reconcileStoppedRun(reason: string = '被看服务已随系统生命周期停止'): void {
    if (!this.initialized || this.state.phase !== 'stopping') {
      return;
    }
    let payload: HostPayload;
    try {
      payload = this.parse(this.bridge.status());
    } catch (error) {
      this.state.phase = 'failed';
      this.state.lastError = `读取原生被看服务状态失败：${String(error)}`;
      this.state.statusText = this.state.lastError;
      this.emitState();
      return;
    }
    this.applyHostPolicy(payload);
    const nativeState: string = payload.state ?? '';
    if (payload.ok === true && nativeState === 'disabled' && payload.serverRunning === false) {
      if (this.runEpoch.length > 0 && runEpochOf(payload) !== this.runEpoch) {
        this.state.phase = 'failed';
        this.state.lastError = '原生停止状态不属于本次运行，尚未确认回收';
        this.state.statusText = this.state.lastError;
        this.emitState();
        return;
      }
      this.applyInputPolicy(payload);
      if (this.runEpoch.length > 0 && runEpochOf(payload) === this.runEpoch &&
        payload.teardownUnconfirmed === null) {
        // Only an explicit clean verdict for this same run clears a held owner.
        this.state.teardownUnconfirmed = '';
      }
      if (this.state.teardownUnconfirmed.length > 0) {
        this.state.phase = 'failed';
        this.state.lastError = this.state.teardownUnconfirmed;
        this.state.statusText = this.state.lastError;
        this.emitState();
        return;
      }
      this.runRequiresInput = false;
      this.state.phase = 'disabled';
      this.state.captureActive = false;
      this.state.captureAuthorized = false;
      this.state.runningInBackground = false;
      this.state.lastError = '';
      this.state.statusText = reason;
      this.emitState();
      return;
    }
    if (nativeState === 'failed') {
      this.state.phase = 'failed';
      this.state.runningInBackground = false;
      this.state.lastError = this.failureText(payload, '原生被看服务已停止');
      this.state.statusText = this.state.lastError;
      this.emitState();
      return;
    }
    this.state.statusText = '系统生命周期已请求关闭被看服务，正在等待原生确认';
    this.emitState();
    this.scheduleStoppingRecheck();
  }

  private scheduleStoppingRecheck(): void {
    if (!this.initialized || this.state.phase !== 'stopping' || this.stoppingTimer >= 0) {
      return;
    }
    if (this.stoppingAttempts >= STOPPING_RECHECK_LIMIT) {
      this.state.lastError = '原生被看服务未在限定时间内确认停止；请稍后刷新或重新启动。';
      this.state.statusText = this.state.lastError;
      this.emitState();
      return;
    }
    this.stoppingAttempts += 1;
    this.stoppingTimer = setTimeout((): void => {
      this.stoppingTimer = -1;
      this.reconcileStoppedRun();
    }, STOPPING_RECHECK_MS) as number;
  }

  /**
   * Stops the one run this panel admitted or attempted, naming its exact epoch.
   *
   * The engine treats an empty epoch as "the run this process currently has", so
   * nothing but a real nonzero decimal epoch is ever sent. Only the generation
   * that is still current adopts the answer: an older stop's reply cannot
   * rewrite a newer run's epoch, capture facts or approval policy.
   */
  private async stopNative(epoch: string, generation: number): Promise<string> {
    if (!isRunEpoch(epoch)) {
      return '';
    }
    let message = '';
    try {
      const payload = this.parse(await this.bridge.stop(epoch));
      const replyEpoch: string = runEpochOf(payload);
      if (generation === this.generation && replyEpoch === epoch) {
        this.applyHostPolicy(payload);
        this.applyInputPolicy(payload);
        this.runEpoch = replyEpoch;
      }
      if (payload.ok !== true) {
        message = this.failureText(payload, '原生被看服务停止失败');
      } else if (replyEpoch !== epoch) {
        message = '原生关闭回执不属于本次运行，尚未确认停止';
      } else if ((payload.teardownUnconfirmed ?? '').length > 0) {
        // The owner stopped but did not confirm reclamation: reported as such,
        // never as a confirmed close.
        message = payload.teardownUnconfirmed ?? '';
      } else if (payload.state !== 'disabled' || payload.serverRunning !== false) {
        message = this.failureText(payload, '原生尚未确认本次运行已停止');
      }
      if (message.length === 0 && generation === this.generation) {
        this.runRequiresInput = false;
      }
    } catch (error) {
      message = `原生被看服务停止失败：${String(error)}`;
    }
    return message;
  }

  private async failClosed(message: string, epoch: string = this.runEpoch): Promise<void> {
    this.generation += 1;
    this.cancelPendingInputAuthorization();
    const failedGeneration = this.generation;
    this.clearPoll();
    this.clearStoppingTimer();
    this.stoppingAttempts = 0;
    this.backgroundService?.stop();
    this.state.phase = 'stopping';
    this.state.statusText = message;
    this.emitState();
    const stopError = await this.stopNative(epoch, failedGeneration);
    if (failedGeneration !== this.generation) {
      // A newer generation owns the panel now; this close must not relabel it.
      return;
    }
    this.state.captureActive = false;
    this.state.captureAuthorized = false;
    this.state.runningInBackground = false;
    this.state.incoming = undefined;
    this.state.incomingResolving = false;
    this.resolvingRequestId = '';
    this.state.activePeerName = '';
    this.state.phase = 'failed';
    this.state.lastError = stopError.length > 0 ? `${message}；${stopError}` : message;
    this.state.statusText = this.state.lastError;
    hilog.error(DOMAIN, TAG, '%{public}s', this.state.lastError);
    this.emitState();
  }

  /**
   * Serializes security operations: one record, one answer at a time.
   *
   * The ticket's panel generation is the one that was current when the operator
   * asked, not when the closure finally runs: a queued write from a panel that
   * was cancelled, backgrounded, destroyed or reinitialised in between is
   * dropped unexecuted. A queued call is not a saved value, and a failed one
   * changed nothing.
   */
  private enqueueSecurity(operation: () => Promise<void>): void {
    this.securityQueue.push(new SecurityTicket(this.panelGeneration, operation));
    void this.drainSecurity();
  }

  private async drainSecurity(): Promise<void> {
    if (this.securityRunning) {
      return;
    }
    this.securityRunning = true;
    while (this.securityQueue.length > 0) {
      const ticket: SecurityTicket | undefined = this.securityQueue.shift();
      if (ticket === undefined) {
        break;
      }
      if (ticket.panel !== this.panelGeneration) {
        // Its closure may hold a permanent password or an enrolment URI that
        // belongs to the panel that is gone; it is released unexecuted.
        continue;
      }
      try {
        await ticket.operation();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Security operation failed: %{public}s', String(error));
      }
    }
    this.securityRunning = false;
  }

  /** The live password panel; only a real answer updates the shown state. */
  private async loadPasswordState(): Promise<void> {
    const runGeneration = this.generation;
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.password());
    } catch (error) {
      if (panel === this.panelGeneration && runGeneration === this.generation) {
        this.state.passwordError = `读取密码设置失败：${String(error)}；请点击刷新重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration || runGeneration !== this.generation) {
      return;
    }
    this.applyPassword(payload, true, '读取密码设置失败');
    this.emitState();
  }

  private async replaceTemporaryPassword(): Promise<void> {
    const runGeneration = this.generation;
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.refreshPassword());
    } catch (error) {
      if (panel === this.panelGeneration && runGeneration === this.generation) {
        this.state.passwordError = `刷新临时密码失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration || runGeneration !== this.generation) {
      return;
    }
    // A rotation answer is a live password document: it carries the new
    // temporary password and the accepted method.
    this.applyPassword(payload, true, '刷新临时密码失败');
    this.emitState();
  }

  private async applyVerificationMethod(mode: ControlledPasswordMode): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.setVerificationMethod(mode));
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.state.passwordError = `保存密码模式失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    if (!this.applyPassword(payload, false, '保存密码模式失败')) {
      this.emitState();
      return;
    }
    this.emitState();
    await this.reloadPasswordPanel(panel, '密码模式已保存，但读取最新密码状态失败');
  }

  private async applyPermanentPassword(password: string): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.setPermanentPassword(password));
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.state.passwordError = `保存固定密码失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    // This answer omits the live temporary password; the panel read below is
    // what fills it, so nothing here blanks a value the run still owns.
    if (!this.applyPassword(payload, false, '保存固定密码失败')) {
      this.emitState();
      return;
    }
    this.emitState();
    await this.reloadPasswordPanel(panel, '固定密码已保存，但读取最新密码状态失败');
  }

  private async reloadPasswordPanel(panel: number, failure: string): Promise<void> {
    const runGeneration = this.generation;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.password());
    } catch (error) {
      if (panel === this.panelGeneration && runGeneration === this.generation) {
        this.state.passwordError = `${failure}：${String(error)}；请点击刷新重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration || runGeneration !== this.generation) {
      return;
    }
    this.applyPassword(payload, true, failure);
    this.emitState();
  }

  /**
   * Applies a password document. Only `ok === true` is a stored fact; a refusal
   * keeps the last valid state and leaves a retry hint instead of a fake save.
   */
  private applyPassword(payload: HostPayload, includeTemporary: boolean, failure: string): boolean {
    if (payload.ok !== true) {
      this.state.passwordError = `${failure}：${this.failureText(payload, 'Core 拒绝了密码设置操作')}；请重试`;
      return false;
    }
    if (includeTemporary) {
      this.state.temporaryPassword = payload.temporaryPassword ?? '';
    }
    this.state.verificationMethod = this.normalizePasswordMode(payload.verificationMethod ?? '');
    this.state.permanentPasswordSet = payload.permanentPasswordSet === true;
    this.state.localPermanentPasswordSet = payload.localPermanentPasswordSet === true;
    this.state.verificationMethodFixed = payload.verificationMethodFixed === true;
    this.state.permanentPasswordChangeDisabled = payload.permanentPasswordChangeDisabled === true;
    this.state.maxPasswordLength = Math.max(8, payload.maxPasswordLength ?? 128);
    this.state.passwordError = '';
    return true;
  }

  private async loadTwoFactorState(): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.twoFactor());
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.errorText = `读取双重认证状态失败：${String(error)}；请点击刷新重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.applyTwoFactor(payload, '读取双重认证状态失败');
    this.emitState();
  }

  private async runBeginTwoFactor(setup: number): Promise<void> {
    const panel = this.panelGeneration;
    if (setup !== this.twoFactorSetupGeneration) {
      // The operator cancelled (or left the foreground) while this begin was
      // still queued: no new enrolment is opened here, so there is no URI that
      // could be shown into a later panel.
      this.twoFactorState.busy = false;
      this.emitState();
      return;
    }
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.beginTwoFactor());
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `启动双重认证设置失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    const uri: string = payload.uri ?? '';
    if (payload.ok !== true || uri.length === 0) {
      this.twoFactorState.errorText =
        `启动双重认证设置失败：${this.failureText(payload, 'Core 未能生成双重认证设置')}；请重试`;
      this.emitState();
      return;
    }
    if (setup !== this.twoFactorSetupGeneration) {
      // The operator cancelled (or left the foreground) while this call was in
      // flight: the one-time enrolment URI is not delivered into that panel.
      this.emitState();
      return;
    }
    this.applyTwoFactor(payload, '启动双重认证设置失败');
    this.twoFactorState.setupUri = uri;
    this.twoFactorState.verificationCode = '';
    this.twoFactorState.errorText = '';
    this.emitState();
  }

  private async runVerifyTwoFactor(code: string): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.verifyTwoFactor(code));
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `启用双重认证失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    if (payload.ok !== true || payload.enabled !== true) {
      this.twoFactorState.errorText =
        `启用双重认证失败：${this.failureText(payload, '验证码错误或已过期')}；请重试`;
      this.emitState();
      return;
    }
    this.applyTwoFactor(payload, '启用双重认证失败');
    this.twoFactorState.setupUri = '';
    this.twoFactorState.verificationCode = '';
    this.emitState();
  }

  private async runDisableTwoFactor(): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.disableTwoFactor());
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `关闭双重认证失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    if (payload.ok !== true || payload.enabled === true) {
      this.twoFactorState.errorText =
        `关闭双重认证失败：${this.failureText(payload, 'Core 未能关闭双重认证')}；请重试`;
      this.emitState();
      return;
    }
    this.applyTwoFactor(payload, '关闭双重认证失败');
    this.twoFactorState.setupUri = '';
    this.emitState();
  }

  private async runRemoveTrustedDevices(hwidsJson: string): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.removeTrustedDevices(hwidsJson));
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `移除受信任设备失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    this.applyTwoFactor(payload, '移除受信任设备失败');
    this.emitState();
  }

  private async runClearTrustedDevices(): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      payload = this.parse(await this.bridge.clearTrustedDevices());
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `清空受信任设备失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    this.applyTwoFactor(payload, '清空受信任设备失败');
    this.emitState();
  }

  private async runSetTrustedDevices(enabled: boolean): Promise<void> {
    const panel = this.panelGeneration;
    let payload: HostPayload;
    try {
      // The one host setting this engine acts on, under the exact key the store
      // reads; an unhandled key is refused, not reported as saved.
      payload = this.parse(await this.bridge.setSetting('trustedDevicesEnabled',
        enabled ? 'true' : 'false'));
    } catch (error) {
      if (panel === this.panelGeneration) {
        this.twoFactorState.busy = false;
        this.twoFactorState.errorText = `更新信任设备设置失败：${String(error)}；请重试`;
        this.emitState();
      }
      return;
    }
    if (panel !== this.panelGeneration) {
      return;
    }
    this.twoFactorState.busy = false;
    if (payload.ok !== true) {
      this.twoFactorState.errorText =
        `更新信任设备设置失败：${this.failureText(payload, 'Core 未能更新信任设备设置')}；请重试`;
      this.emitState();
      return;
    }
    this.twoFactorState.trustedDevicesEnabled = payload.trustedDevicesEnabled ?? enabled;
    this.twoFactorState.errorText = '';
    this.emitState();
  }

  /**
   * Applies a 2FA document. Only `ok === true` is a stored fact, and an
   * enrolment URI is only ever the one `begin` returned — never re-derived,
   * never kept after it was used or cancelled.
   */
  private applyTwoFactor(payload: HostPayload, failure: string): boolean {
    if (payload.ok !== true) {
      this.twoFactorState.errorText = `${failure}：${this.failureText(payload, 'Core 拒绝了双重认证操作')}；请重试`;
      return false;
    }
    this.twoFactorState.enabled = payload.enabled === true;
    if (payload.trustedDevicesEnabled !== undefined) {
      this.twoFactorState.trustedDevicesEnabled = payload.trustedDevicesEnabled;
    }
    this.twoFactorState.trustedDevicesFixed = payload.trustedDevicesFixed === true;
    this.twoFactorState.trustedDevices = payload.trustedDevices ?? [];
    // Clear only when the enrolment really ended (enabled) or the record says no
    // enrolment is pending; a pending one keeps the URI `begin` already returned.
    if (this.twoFactorState.enabled || payload.setupPending === false) {
      this.twoFactorState.setupUri = '';
      this.twoFactorState.verificationCode = '';
    }
    const registrationError: string | undefined = payload.lastError;
    if (registrationError !== undefined && registrationError.length > 0) {
      // The code verified but the device could not be stored: said plainly, and
      // not turned into "the device is trusted".
      this.twoFactorState.errorText = `受信任设备未能保存：${registrationError}`;
    } else {
      this.twoFactorState.errorText = '';
    }
    return true;
  }

  private emitState(): void {
    for (let index = 0; index < this.listeners.length; index += 1) {
      try {
        this.listeners[index](this.state);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'State listener failed: %{public}s', String(error));
      }
    }
  }
}

export const controlledHostCoordinator = new ControlledHostCoordinator();
