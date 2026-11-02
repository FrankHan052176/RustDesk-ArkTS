import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ControlledHostBackgroundService } from './ControlledHostBackgroundService';
import {
  ControlledHostState,
  ControlledHostStateListener,
  ControlledIncomingPeer,
  ControlledPasswordMode,
  ControlledTrustedDevice,
  ControlledTwoFactorState,
  PASSWORD_MODE_BOTH,
  PASSWORD_MODE_PERMANENT,
  PASSWORD_MODE_TEMPORARY,
} from './ControlledHostTypes';
import { NativeHostBridge } from './NativeHostBridge';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskViewedHost';
const POLL_INTERVAL_MS = 250;
const STOPPING_RECHECK_MS = 250;
/** The native teardown bound is 30 s; this only observes it from the foreground. */
const STOPPING_RECHECK_LIMIT = 120;

/**
 * The start request the legacy UI built.
 *
 * `requireLocalApproval: true` is the real policy this service runs: the engine
 * pins the run to per-connection local approval (a click on this machine), and
 * `false` would only fall back to password-or-click, which still authenticates a
 * password or a local click and never auto-approves. Input and clipboard stay
 * off, which is what a view-only host accepts. Desktop audio is requested and
 * reported: this engine has no audio owner yet, so the answer carries
 * `audioEnabled: false` instead of a silent success.
 *
 * `approvedServerProfile` is the explicitly saved v2 profile the run registers
 * with; it is filled only from `runtimeGetServerConfig`, never from a draft, a
 * LAN hit or a target string.
 */
class ControlledStartOptions {
  requireLocalApproval: boolean = true;
  enableInput: boolean = false;
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

/** One queued security operation and the panel generation it was queued for. */
class SecurityTicket {
  readonly panel: number;
  readonly operation: () => Promise<void>;

  constructor(panel: number, operation: () => Promise<void>) {
    this.panel = panel;
    this.operation = operation;
  }
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
  private generation: number = 0;
  /** The one start attempt in flight, kept until its run is closed or admitted. */
  private startTask: Promise<void> | undefined = undefined;
  private initialized: boolean = false;
  private runtimeReady: boolean = false;
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
  }

  onRuntimeReady(): void {
    if (!this.initialized) {
      return;
    }
    if (this.runtimeReady) {
      this.refreshIdentityState();
      return;
    }
    this.runtimeReady = true;
    this.refreshIdentityState();
    this.refreshPasswordState();
    this.refreshTwoFactorState();
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
  async start(): Promise<void> {
    if (!this.initialized || this.startTask !== undefined || this.running()) {
      return;
    }
    if (this.state.phase === 'starting') {
      return;
    }
    const task: Promise<void> = this.performStart();
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
  private async performStart(): Promise<void> {
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
      this.state.lastError = 'RustDesk Core 尚未初始化，请稍后重试。';
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
      const backgroundStarted = await backgroundService?.start();
      if (currentGeneration !== this.generation) {
        // Only the continuous task this attempt started is released; the run
        // itself was never asked for.
        backgroundService?.stop();
        return;
      }
      if (backgroundStarted !== true) {
        throw new Error('无法启动被看服务后台任务');
      }
      const displayInfo = display.getDefaultDisplaySync();
      const screenOptions = new ControlledScreenOptions();
      screenOptions.displayId = displayInfo.id;
      screenOptions.width = displayInfo.width;
      screenOptions.height = displayInfo.height;
      this.requireSuccess(
        this.parse(this.bridge.configureScreen(JSON.stringify(screenOptions))),
        '屏幕参数配置失败',
      );
      if (currentGeneration !== this.generation) {
        backgroundService?.stop();
        return;
      }
      const startOptions = new ControlledStartOptions();
      startOptions.approvedServerProfile = config.approvedProfile;
      // Everything above is admission; this is the one call that creates a run.
      const rawStartReply = this.parse(await this.bridge.start(JSON.stringify(startOptions)));
      const attemptedEpoch: string = runEpochOf(rawStartReply);
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
      }
      const startReply = this.requireSuccess(rawStartReply, 'RustDesk 被看服务启动失败');
      if (startReply.serverRunning !== true || startReply.state !== 'listening') {
        throw new Error(this.failureText(startReply, '原生被看服务未进入监听状态'));
      }
      const epoch: string = runEpochOf(startReply);
      if (epoch.length === 0) {
        throw new Error('原生被看服务未返回本次运行的 epoch，无法停止或复核该次运行');
      }
      this.runEpoch = epoch;
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
        await this.failClosed(`启动失败：${String(error)}`);
      }
    }
  }

  async stop(reason: string = '被看服务已停止'): Promise<void> {
    this.generation += 1;
    const stopGeneration = this.generation;
    this.state.temporaryPassword = '';
    this.clearPoll();
    this.clearStoppingTimer();
    this.stoppingAttempts = 0;
    const backgroundService = this.backgroundService;
    this.state.phase = 'stopping';
    this.state.statusText = reason;
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
      this.state.statusText = allow ? '已在本机同意观看，正在建立仅观看会话' : '正在拒绝并断开该请求';
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
   * The app is leaving the foreground, and the native lifecycle fence has just
   * requested the host service's close: nothing may keep claiming a live share.
   *
   * This is not a second stop and adds no background keep-alive: the fence
   * already revoked the listener and every peer, and the owner's own join reports
   * an unconfirmed reclamation as such. The panel only stops claiming that the
   * screen is still being shared while the native close settles.
   */
  onAbilityBackground(): void {
    if (!this.initialized) {
      return;
    }
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
    this.state.statusText = '应用已进入后台：系统生命周期已请求关闭被看服务，共享不会在后台继续';
    this.emitState();
  }

  onAbilityForeground(): void {
    if (!this.initialized) {
      return;
    }
    if (this.runtimeReady) {
      this.refreshIdentityState();
    }
    this.stoppingAttempts = 0;
    if (this.running() && !this.stillListening()) {
      // Every native lifecycle update runs the app fence, and that fence asks
      // the host service to close (this foreground one included). A run that is
      // no longer listening is not reported as still sharing.
      this.clearPoll();
      this.clearStoppingTimer();
      this.backgroundService?.stop();
      this.state.runningInBackground = false;
      this.state.incoming = undefined;
      this.state.incomingResolving = false;
      this.resolvingRequestId = '';
      this.state.activePeerName = '';
      this.state.phase = 'stopping';
      this.state.statusText = '系统生命周期已请求关闭被看服务，正在等待原生确认';
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

  /** One read: the service is still in its real listening state right now. */
  private stillListening(): boolean {
    try {
      const payload = this.parse(this.bridge.status());
      return payload.ok === true && payload.serverRunning === true && payload.state === 'listening';
    } catch (error) {
      return false;
    }
  }

  onAbilityDestroy(): void {
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
    const parts: string[] = [];
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
    if (this.pollTimer >= 0 || !this.running()) {
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
    if (epoch.length > 0) {
      this.runEpoch = epoch;
    }
    this.applyHostPolicy(payload);
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
    if (nextRequest !== undefined) {
      this.state.incoming = nextRequest;
      this.state.incomingResolving = resolutionStillPending && nextRequest.requestId === this.resolvingRequestId;
      const peerLabel: string = nextRequest.peerName.length > 0 ? nextRequest.peerName : nextRequest.peerId;
      this.state.phase = 'incoming';
      if (this.state.incomingResolving) {
        this.state.statusText = this.resolvingAccepted ? '已在本机同意观看；等待系统屏幕共享确认' :
          '正在拒绝并断开该请求';
      } else if (activePeer !== undefined) {
        this.state.statusText =
          `正在连接 ${this.state.activePeerName}${captureSuffix}；${peerLabel} 请求连接，${this.approveRequirementText()}`;
      } else {
        this.state.statusText = `${peerLabel} 请求连接，${this.approveRequirementText()}`;
      }
    } else if (activePeer !== undefined) {
      this.state.incoming = undefined;
      this.state.phase = 'active';
      this.state.statusText = capture.length > 0
        ? `已连接 ${this.state.activePeerName}${captureSuffix}`
        : `已连接 ${this.state.activePeerName}，等待系统屏幕共享确认`;
    } else {
      this.state.incoming = undefined;
      if (this.state.phase === 'incoming' || this.state.phase === 'active') {
        this.state.phase = 'ready';
      }
      this.state.statusText = this.readyStatusText();
    }
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
    } catch (error) {
      message = `原生被看服务停止失败：${String(error)}`;
    }
    return message;
  }

  private async failClosed(message: string): Promise<void> {
    this.generation += 1;
    const failedGeneration = this.generation;
    this.clearPoll();
    this.clearStoppingTimer();
    this.stoppingAttempts = 0;
    this.backgroundService?.stop();
    const stopError = await this.stopNative(this.runEpoch, failedGeneration);
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
