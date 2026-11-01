import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ControlledHostBackgroundService } from './ControlledHostBackgroundService';
import {
  ControlledHostState,
  ControlledHostStateListener,
  ControlledIncomingPeer,
  ControlledIncomingPayload,
  ControlledNativeActionPayload,
  ControlledPasswordMode,
  ControlledPasswordPayload,
  ControlledServerStatusPayload,
  ControlledTrustedDevice,
  ControlledTwoFactorPayload,
  ControlledTwoFactorState,
  PASSWORD_MODE_BOTH,
  PASSWORD_MODE_PERMANENT,
  PASSWORD_MODE_TEMPORARY,
} from './ControlledHostTypes';
import { NativeHostBridge } from './NativeHostBridge';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskViewedHost';
const POLL_INTERVAL_MS = 250;
/**
 * The legacy start option object.
 *
 * `requireLocalApproval: true` is really enforced: for the lifetime of the
 * service every connection must be approved locally, through Core's own approval
 * option, without ever writing the local user's persisted setting. A deployment
 * policy that cannot require local approval makes the start refuse, and `false`
 * is refused too (this host never auto-approves). Omitting the field leaves the
 * policy untouched. Input and clipboard stay off, which is what a view-only host
 * accepts; desktop audio follows the Core option and is only reported.
 */
class ControlledStartOptions {
  requireLocalApproval: boolean = true;
  enableInput: boolean = false;
  enableClipboard: boolean = false;
  enableAudio: boolean = true;
}

class ControlledScreenOptions {
  displayId: number = 0;
  width: number = 0;
  height: number = 0;
  frameRate: number = 30;
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
  private initialized: boolean = false;
  private runtimeReady: boolean = false;
  private resolvingRequestId: string = '';
  private resolvingAccepted: boolean = false;

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
    this.state.phase = 'disabled';
    this.state.statusText = '可启用屏幕与设备内音频共享';
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

  async start(): Promise<void> {
    if (!this.initialized || this.state.phase === 'starting' || this.running()) {
      return;
    }
    if (!this.runtimeReady) {
      this.state.lastError = 'RustDesk Core 尚未初始化，请稍后重试。';
      this.state.statusText = this.state.lastError;
      this.emitState();
      return;
    }
    const currentGeneration = this.generation + 1;
    this.generation = currentGeneration;
    this.state.phase = 'starting';
    this.state.statusText = '正在等待系统录屏确认';
    this.state.lastError = '';
    this.emitState();
    try {
      const backgroundStarted = await this.backgroundService?.start();
      if (backgroundStarted !== true) {
        throw new Error('无法启动设备内音频后台任务');
      }
      const displayInfo = display.getDefaultDisplaySync();
      const screenOptions = new ControlledScreenOptions();
      screenOptions.displayId = displayInfo.id;
      screenOptions.width = displayInfo.width;
      screenOptions.height = displayInfo.height;
      const screenJson = JSON.stringify(screenOptions);
      this.requireSuccess(this.bridge.configureScreen(screenJson), '屏幕参数配置失败');
      const startOptions = new ControlledStartOptions();
      const startReply = this.requireSuccess(
        await this.bridge.start(JSON.stringify(startOptions)),
        'RustDesk 被看服务启动失败',
      );
      // `start` resolves only from the real capture state: consent granted, the
      // first access unit produced, and the frontend's privacy admission still in
      // force. Its own fields are re-checked here rather than assumed.
      this.applyHostPolicy(startReply);
      if (!this.state.captureAuthorized) {
        throw new Error('被看服务启动后未确认屏幕采集');
      }
      if (currentGeneration !== this.generation) {
        await this.stopNativeFailClosed();
        return;
      }
      this.state.runningInBackground = this.backgroundService?.isRunning() === true;
      this.state.phase = 'ready';
      this.state.statusText = this.readyStatusText();
      this.refreshNativeStatus();
      this.emitState();
      this.schedulePoll(0);
    } catch (error) {
      await this.failClosed(`启动失败：${String(error)}`);
    }
  }

  async stop(reason: string = '被看服务已停止'): Promise<void> {
    this.generation += 1;
    this.clearPoll();
    const backgroundService = this.backgroundService;
    this.state.phase = 'stopping';
    this.state.statusText = reason;
    this.emitState();
    backgroundService?.stop();
    const stopError = await this.stopNativeFailClosed();
    this.state.captureActive = false;
    this.state.captureAuthorized = false;
    // The service's scoped approval policy is released when it stops, so it is
    // not reported as still in force.
    this.state.approveModeScoped = false;
    this.state.localApprovalEnforced = false;
    this.state.runningInBackground = false;
    this.state.incoming = undefined;
    this.state.incomingResolving = false;
    this.resolvingRequestId = '';
    this.state.activePeerName = '';
    if (stopError.length > 0) {
      this.state.phase = 'failed';
      this.state.lastError = stopError;
      this.state.statusText = stopError;
    } else {
      this.state.phase = 'disabled';
    }
    this.emitState();
  }

  rejectIncoming(requestId: string, peerId: string): void {
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
      this.requireSuccess(this.bridge.rejectIncoming(incoming.requestId), '无法拒绝远端观看请求');
      this.resolvingRequestId = incoming.requestId;
      this.resolvingAccepted = false;
      this.state.incomingResolving = true;
      this.state.statusText = '正在拒绝并断开该请求';
      this.emitState();
      this.schedulePoll(0);
    } catch (error) {
      this.state.lastError = `拒绝连接失败：${String(error)}`;
      this.state.statusText = this.state.lastError;
      this.emitState();
      this.schedulePoll(0);
    }
  }

  acceptIncoming(requestId: string, peerId: string): void {
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
      this.requireSuccess(this.bridge.acceptIncoming(incoming.requestId), '无法同意远端观看请求');
      this.resolvingRequestId = incoming.requestId;
      this.resolvingAccepted = true;
      this.state.incomingResolving = true;
      this.state.statusText = '已同意免密观看，正在建立仅观看会话';
      this.emitState();
      this.schedulePoll(0);
    } catch (error) {
      this.state.lastError = `同意连接失败：${String(error)}`;
      this.state.statusText = this.state.lastError;
      this.emitState();
      this.schedulePoll(0);
    }
  }

  refreshPasswordState(): void {
    try {
      const payload = JSON.parse(this.bridge.password()) as ControlledPasswordPayload;
      if (payload.ok === false) {
        throw new Error(payload.message ?? payload.lastError ?? 'Core 拒绝读取密码设置');
      }
      this.state.temporaryPassword = payload.temporaryPassword ?? '';
      this.state.verificationMethod = this.normalizePasswordMode(payload.verificationMethod ?? '');
      this.state.permanentPasswordSet = payload.permanentPasswordSet ?? false;
      this.state.localPermanentPasswordSet = payload.localPermanentPasswordSet ?? false;
      this.state.verificationMethodFixed = payload.verificationMethodFixed ?? false;
      this.state.permanentPasswordChangeDisabled = payload.permanentPasswordChangeDisabled ?? false;
      this.state.maxPasswordLength = Math.max(8, payload.maxPasswordLength ?? 128);
      this.state.passwordError = '';
    } catch (error) {
      this.state.passwordError = `读取密码设置失败：${String(error)}`;
    }
    this.emitState();
  }

  refreshTemporaryPassword(): void {
    try {
      const payload = JSON.parse(this.bridge.refreshPassword()) as ControlledPasswordPayload;
      if (payload.ok === false) {
        throw new Error(payload.message ?? payload.lastError ?? 'Core 拒绝刷新随机密码');
      }
      this.state.temporaryPassword = payload.temporaryPassword ?? '';
      this.state.passwordError = '';
    } catch (error) {
      this.state.passwordError = `刷新随机密码失败：${String(error)}`;
    }
    this.emitState();
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
    try {
      this.requireSuccess(this.bridge.setVerificationMethod(mode), 'Core 拒绝了密码模式变更');
      this.refreshPasswordState();
    } catch (error) {
      this.state.passwordError = `保存密码模式失败：${String(error)}`;
      this.emitState();
    }
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
    try {
      this.requireSuccess(this.bridge.setPermanentPassword(password), 'Core 拒绝了固定密码变更');
      this.refreshPasswordState();
    } catch (error) {
      this.state.passwordError = `保存固定密码失败：${String(error)}`;
      this.emitState();
    }
  }

  clearPermanentPassword(): void {
    this.setPermanentPassword('', '');
    if (!this.state.permanentPasswordSet && this.state.verificationMethod === PASSWORD_MODE_PERMANENT) {
      this.setVerificationMethod(PASSWORD_MODE_BOTH);
    }
  }

  refreshTwoFactorState(): void {
    try {
      const payload = JSON.parse(this.bridge.twoFactor()) as ControlledTwoFactorPayload;
      if (payload.ok === false) {
        throw new Error(payload.message ?? payload.lastError ?? 'Core 拒绝读取双重认证状态');
      }
      this.twoFactorState.enabled = payload.enabled ?? false;
      this.twoFactorState.trustedDevicesEnabled = payload.trustedDevicesEnabled ?? true;
      this.twoFactorState.trustedDevicesFixed = payload.trustedDevicesFixed ?? false;
      this.twoFactorState.trustedDevices = payload.trustedDevices ?? [];
      if (!this.twoFactorState.enabled) {
        this.twoFactorState.setupUri = '';
        this.twoFactorState.verificationCode = '';
      }
      this.twoFactorState.errorText = '';
    } catch (error) {
      this.twoFactorState.errorText = `读取双重认证状态失败：${String(error)}`;
    }
    this.emitState();
  }

  beginTwoFactorSetup(): void {
    if (this.twoFactorState.busy || this.twoFactorState.enabled) {
      return;
    }
    this.twoFactorState.busy = true;
    try {
      const payload = JSON.parse(this.bridge.beginTwoFactor()) as ControlledTwoFactorPayload;
      if (payload.ok === false || (payload.uri ?? '').length === 0) {
        throw new Error(payload.message ?? 'Core 未能生成双重认证设置');
      }
      this.twoFactorState.setupUri = payload.uri ?? '';
      this.twoFactorState.verificationCode = '';
      this.twoFactorState.errorText = '';
    } catch (error) {
      this.twoFactorState.errorText = `启动双重认证设置失败：${String(error)}`;
    } finally {
      this.twoFactorState.busy = false;
      this.emitState();
    }
  }

  cancelTwoFactorSetup(): void {
    this.twoFactorState.setupUri = '';
    this.twoFactorState.verificationCode = '';
    this.twoFactorState.errorText = '';
    this.emitState();
  }

  verifyTwoFactorSetup(code: string): void {
    if (this.twoFactorState.busy) {
      return;
    }
    this.twoFactorState.busy = true;
    try {
      const payload = JSON.parse(this.bridge.verifyTwoFactor(code.trim())) as ControlledTwoFactorPayload;
      if (payload.ok === false || payload.enabled !== true) {
        throw new Error(payload.message ?? '验证码错误');
      }
      this.twoFactorState.setupUri = '';
      this.twoFactorState.verificationCode = '';
      this.refreshTwoFactorState();
    } catch (error) {
      this.twoFactorState.errorText = `启用双重认证失败：${String(error)}`;
    } finally {
      this.twoFactorState.busy = false;
      this.emitState();
    }
  }

  disableTwoFactor(): void {
    if (this.twoFactorState.busy) {
      return;
    }
    this.twoFactorState.busy = true;
    try {
      const payload = JSON.parse(this.bridge.disableTwoFactor()) as ControlledTwoFactorPayload;
      if (payload.ok === false || payload.enabled === true) {
        throw new Error(payload.message ?? 'Core 未能关闭双重认证');
      }
      this.refreshTwoFactorState();
    } catch (error) {
      this.twoFactorState.errorText = `关闭双重认证失败：${String(error)}`;
    } finally {
      this.twoFactorState.busy = false;
      this.emitState();
    }
  }

  removeTrustedDevice(device: ControlledTrustedDevice): void {
    try {
      this.requireSuccess(this.bridge.removeTrustedDevices(JSON.stringify([device.hwid])), 'Core 未能移除受信任设备');
      this.refreshTwoFactorState();
    } catch (error) {
      this.twoFactorState.errorText = `移除受信任设备失败：${String(error)}`;
      this.emitState();
    }
  }

  clearTrustedDevices(): void {
    try {
      this.requireSuccess(this.bridge.clearTrustedDevices(), 'Core 未能清空受信任设备');
      this.refreshTwoFactorState();
    } catch (error) {
      this.twoFactorState.errorText = `清空受信任设备失败：${String(error)}`;
      this.emitState();
    }
  }

  setTrustedDevicesEnabled(enabled: boolean): void {
    if (this.twoFactorState.trustedDevicesFixed) {
      this.twoFactorState.errorText = '信任设备策略已锁定，无法更改。';
      this.emitState();
      return;
    }
    try {
      this.requireSuccess(this.bridge.setSetting('trustedDevicesEnabled', enabled ? 'true' : 'false'),
        'Core 未能更新信任设备设置');
      this.refreshTwoFactorState();
    } catch (error) {
      this.twoFactorState.errorText = `更新信任设备设置失败：${String(error)}`;
      this.emitState();
    }
  }

  onAbilityForeground(): void {
    if (!this.initialized) {
      return;
    }
    if (this.runtimeReady) {
      this.refreshIdentityState();
    }
    if (this.running()) {
      this.state.statusText = this.state.phase === 'active' ? this.state.statusText :
        this.readyStatusText();
      this.schedulePoll(0);
    }
    this.emitState();
  }

  onAbilityBackground(): void {
    if (this.twoFactorState.setupUri.length > 0) {
      this.cancelTwoFactorSetup();
    }
    if (this.running()) {
      // Desktop audio follows the Core option, so the text does not claim audio
      // is being shared when the option says it is not.
      this.state.statusText = this.state.audioEnabled
        ? '被看服务正在后台共享屏幕与设备内音频'
        : '被看服务正在后台共享屏幕';
      this.schedulePoll(0);
      this.emitState();
    }
  }

  onAbilityDestroy(): void {
    void this.stop('应用已退出，被看服务已停止');
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

  private refreshIdentityState(): void {
    try {
      const payload = JSON.parse(this.bridge.status()) as ControlledServerStatusPayload;
      const myId: string = (payload.myId ?? '').trim();
      if (myId.length > 0) {
        this.state.myId = myId;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Device ID is unavailable: %{public}s', String(error));
    }
  }

  /**
   * The native capture verdict, exactly as the host adapter reports it.
   *
   * A missing field fails closed: an absent `active`/`captureActive` or
   * `systemCaptureConfirmed` is not a claim that capture is running, and the
   * SDK's own state code is never interpreted as one.
   */
  private captureIsHealthy(payload: ControlledNativeActionPayload): boolean {
    const live = payload.active === true || payload.captureActive === true;
    return payload.ok !== false
      && live
      && payload.terminal !== true
      && payload.systemCaptureConfirmed === true
      && (payload.framesObserved ?? 0) > 0;
  }

  private refreshNativeStatus(): void {
    const payload = JSON.parse(this.bridge.status()) as ControlledServerStatusPayload;
    this.state.myId = payload.myId ?? this.state.myId;
    this.state.temporaryPassword = payload.temporaryPassword ?? '';
    this.applyHostPolicy(payload);
    this.state.terminalReason = payload.terminalReason ?? payload.error ?? '';
    if (payload.ok === false || payload.serverRunning !== true || payload.state !== 'ready') {
      throw new Error(payload.message ?? payload.lastError ?? '原生被看服务已停止');
    }
    if (this.state.teardownUnconfirmed.length > 0) {
      throw new Error(this.state.teardownUnconfirmed);
    }
    if ((payload.lastError ?? '').length > 0) {
      throw new Error(payload.lastError ?? '原生服务报告失败');
    }
  }

  /**
   * Adopts the capture and policy facts one host answer really carries.
   *
   * Everything here is copied from the answer: the approval mode is Core's own
   * policy, an unconfirmed teardown is kept until a later status clears it, and
   * the capture verdict is the adapter's predicate rather than a local guess.
   */
  private applyHostPolicy(payload: ControlledNativeActionPayload): void {
    this.state.captureActive = payload.active === true || payload.captureActive === true;
    this.state.captureAuthorized = this.captureIsHealthy(payload);
    this.state.teardownUnconfirmed = payload.teardownUnconfirmed ?? '';
    const server = payload as ControlledServerStatusPayload;
    if (server.approveMode !== undefined) {
      this.state.approveMode = server.approveMode;
    }
    if (server.localApprovalEnforced !== undefined) {
      this.state.localApprovalEnforced = server.localApprovalEnforced;
    }
    if (server.approveModeScoped !== undefined) {
      this.state.approveModeScoped = server.approveModeScoped;
    }
    if (server.audioEnabled !== undefined) {
      this.state.audioEnabled = server.audioEnabled;
    }
  }

  /** What the operator's local-approval policy really requires, or an empty string. */
  private approveModeText(): string {
    if (this.state.approveModeScoped) {
      return '本机要求每次连接都需点击同意';
    }
    if (this.state.approveMode === 'password') {
      return '远端需输入密码';
    }
    if (this.state.approveMode === 'click') {
      return '需在本机点击同意';
    }
    if (this.state.approveMode === 'both') {
      return '远端密码或本机点击同意';
    }
    return '';
  }

  /** The ready text, naming Core's own approval policy when it reported one. */
  private readyStatusText(): string {
    const approval = this.approveModeText();
    return approval.length > 0
      ? `被看服务已启用（${approval}），等待远端认证`
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

  private async pollOnce(): Promise<void> {
    if (this.pollInFlight || !this.running()) {
      return;
    }
    this.pollInFlight = true;
    try {
      this.refreshNativeStatus();
      const capture = JSON.parse(this.bridge.screenCaptureStatus()) as ControlledNativeActionPayload;
      this.applyHostPolicy(capture);
      if (!this.state.captureAuthorized) {
        throw new Error(capture.terminalReason ?? capture.error ?? capture.lastError ?? capture.message
          ?? '系统屏幕共享已停止');
      }
      const incomingPayload = JSON.parse(this.bridge.pollIncoming(256)) as ControlledIncomingPayload;
      if (incomingPayload.ok === false) {
        throw new Error(incomingPayload.message ?? '无法读取被看连接列表');
      }
      const requests = incomingPayload.requests ?? incomingPayload.clients ?? [];
      const clients = incomingPayload.clients ?? [];
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
      if (nextRequest !== undefined) {
        this.state.incoming = nextRequest;
        this.state.incomingResolving = resolutionStillPending && nextRequest.requestId === this.resolvingRequestId;
        const peerLabel: string = nextRequest.peerName.length > 0 ? nextRequest.peerName : nextRequest.peerId;
        this.state.phase = 'incoming';
        if (this.state.incomingResolving) {
          this.state.statusText = this.resolvingAccepted ? '已同意免密观看，正在建立仅观看会话' :
            '正在拒绝并断开该请求';
        } else if (activePeer !== undefined) {
          this.state.statusText = `正在向 ${this.state.activePeerName} 分享；${peerLabel} 请求连接，等待本机同意`;
        } else {
          this.state.statusText = `${peerLabel} 请求连接；可同意免密观看，或由远端输入密码`;
        }
      } else if (activePeer !== undefined) {
        this.state.incoming = undefined;
        this.state.phase = 'active';
        this.state.statusText = `正在向 ${this.state.activePeerName} 分享屏幕和设备内音频`;
      } else if (this.state.phase === 'incoming' || this.state.phase === 'active') {
        this.state.incoming = undefined;
        this.state.activePeerName = '';
        this.state.phase = 'ready';
        this.state.statusText = this.readyStatusText();
      }
      this.emitState();
    } catch (error) {
      await this.failClosed(`服务轮询失败：${String(error)}`);
      return;
    } finally {
      this.pollInFlight = false;
    }
    this.schedulePoll(POLL_INTERVAL_MS);
  }

  private requireSuccess(resultJson: string, fallback: string): ControlledNativeActionPayload {
    const payload = JSON.parse(resultJson) as ControlledNativeActionPayload;
    if (payload.ok === false) {
      throw new Error(payload.message ?? payload.lastError ?? fallback);
    }
    return payload;
  }

  private clearPoll(): void {
    if (this.pollTimer < 0) {
      return;
    }
    clearTimeout(this.pollTimer);
    this.pollTimer = -1;
  }

  private async stopNativeFailClosed(): Promise<string> {
    let message = '';
    try {
      const captureResult = JSON.parse(await this.bridge.stopScreenCapture()) as ControlledNativeActionPayload;
      if (captureResult.ok === false) {
        message = captureResult.message ?? captureResult.lastError ?? '屏幕采集停止失败';
      }
    } catch (error) {
      message = `屏幕采集停止失败：${String(error)}`;
    }
    try {
      const serverResult = JSON.parse(await this.bridge.stop()) as ControlledNativeActionPayload;
      if (serverResult.ok === false && message.length === 0) {
        message = serverResult.message ?? serverResult.lastError ?? '原生服务停止失败';
      }
    } catch (error) {
      if (message.length === 0) {
        message = `原生服务停止失败：${String(error)}`;
      }
    }
    return message;
  }

  private async failClosed(message: string): Promise<void> {
    this.generation += 1;
    this.clearPoll();
    this.backgroundService?.stop();
    const stopError = await this.stopNativeFailClosed();
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
