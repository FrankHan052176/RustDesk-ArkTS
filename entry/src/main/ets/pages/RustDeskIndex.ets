import { HdsNavigation, HdsNavigationTitleMode, HdsTabs } from '@kit.UIDesignKit';
import native from 'rustdesk-ohrs';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ConnectTab } from './rustdesk/components/ConnectTab';
import { PasswordPromptDialog } from './rustdesk/components/PasswordPromptDialog';
import { SettingsTab } from './rustdesk/components/SettingsTab';
import { RustDeskPreferences } from './rustdesk/RustDeskPreferences';
import { RustDeskSurfaceController } from './rustdesk/RustDeskSurfaceController';
import {
  mapHarmonyKeyCode,
  mapMouseButton,
  mapPointerToRemote,
  mapRemoteToPointer,
  resolvePreviewTransform,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskModifierKey,
  RustDeskSize,
} from './rustdesk/RustDeskInputMapper';
import {
  ActionResponse,
  BridgeSummary,
  DecoderCapability,
  DecoderCapabilityResponse,
  DOMAIN,
  EVENT_POLL_INTERVAL_MS,
  NativeEvent,
  PASSWORD_TIMEOUT_MS,
  PeerDisplayInfo,
  RENDER_STATS_POLL_INTERVAL_MS,
  ResolutionInfo,
  SavedConnectionSettings,
  TAG,
} from './rustdesk/RustDeskTypes';

const TOUCHPAD_TAP_MAX_MS = 220;
const TOUCHPAD_TAP_MAX_DISTANCE = 18;
const TOUCHPAD_LONG_PRESS_MS = 550;
const TOUCHPAD_DOUBLE_TAP_MAX_MS = 260;
const TOUCHPAD_MOVE_SENSITIVITY = 1.4;
const TOUCHPAD_SCROLL_SENSITIVITY = 1.6;
const RELATIVE_MOVE_LOG_SAMPLE_EVERY = 8;
const RELATIVE_TOUCH_LOG_SAMPLE_EVERY = 6;

@Entry
@Component
struct RustDeskIndex {
  private previewController: RustDeskSurfaceController = new RustDeskSurfaceController();
  private preferences?: RustDeskPreferences;
  private passwordDialogController?: CustomDialogController;
  private connectScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();

  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @State currentTabIndex: number = 0;

  @State nativeVersion: string = 'loading...';
  @State health: string = 'waiting...';
  @State integrationStage: string = 'unknown';
  @State upstreamRepo: string = '';
  @State notes: string = '';
  @State apiServer: string = '';
  @State nativeBuildMarker: string = '';
  @State decoderCapabilitiesSummary: string = '';
  @State errorText: string = '';

  @State peerTarget: string = '10.52.176.1';
  @State passwordDraft: string = '';
  @State rememberPassword: boolean = false;

  @State activeSessionId: string = '';
  @State activeCoreSessionId: string = '';
  @State sessionPhase: string = 'idle';
  @State sessionMessage: string = '未连接';
  @State connectionSummary: string = '未连接';
  @State qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @State isPolling: boolean = false;
  @State frameStatus: string = 'Surface not ready';
  @State frameWidth: number = 0;
  @State frameHeight: number = 0;
  @State renderFpsText: string = 'FPS --';
  @State showPreviewModal: boolean = false;
  @State previewSurfaceVisible: boolean = false;
  @State previewSurfaceGeneration: number = 0;
  @State relativeMouseMode: boolean = false;

  private runtimeInitialized: boolean = false;
  private pollTimer: number = -1;
  private passwordTimeoutId: number = -1;
  private eventPollInFlight: boolean = false;
  private performanceTuningApplied: boolean = false;
  private lastRenderStatsPollAt: number = 0;
  private previewSurfaceId: string = '';
  private currentDisplay: number = 0;
  private peerDisplays: PeerDisplayInfo[] = [];
  private supportedResolutions: ResolutionInfo[] = [];
  private remoteFpsText: string = '--';
  private remoteDelayText: string = '--';
  private remoteCodecText: string = '--';
  private savedPassword: string = '';
  private passwordDialogVisible: boolean = false;
  private previewViewWidth: number = 0;
  private previewViewHeight: number = 0;
  private activeModifiers: Set<RustDeskModifierKey> = new Set();
  private touchpadPrimaryId: number = -1;
  private touchpadSecondaryId: number = -1;
  private touchpadPrimaryDownX: number = 0;
  private touchpadPrimaryDownY: number = 0;
  private touchpadPrimaryLastX: number = 0;
  private touchpadPrimaryLastY: number = 0;
  private touchpadPrimaryDownAt: number = 0;
  private touchpadSecondaryLastX: number = 0;
  private touchpadSecondaryLastY: number = 0;
  private touchpadTapMoved: boolean = false;
  private touchpadLongPressTriggered: boolean = false;
  private touchpadLongPressTimer: number = -1;
  private touchpadDragActive: boolean = false;
  private touchpadPendingTapTimer: number = -1;
  private touchpadLastTapAt: number = 0;
  private touchpadLastTapX: number = 0;
  private touchpadLastTapY: number = 0;
  private relativeMouseLastX: number = 0;
  private relativeMouseLastY: number = 0;
  private relativeMouseHasLast: boolean = false;
  private sessionFullscreenApplied: boolean = false;
  private relativeMoveLogCounter: number = 0;
  private relativeTouchMoveLogCounter: number = 0;
  @State remoteCursorVisible: boolean = false;
  @State remoteCursorLeft: number = 0;
  @State remoteCursorTop: number = 0;

  aboutToAppear(): void {
    this.previewController.onCreated = (surfaceId: string) => this.handlePreviewSurfaceCreated(surfaceId);
    this.previewController.onChanged = (_surfaceId: string, rect: SurfaceRect) => this.handlePreviewSurfaceChanged(rect);
    this.previewController.onDestroyed = () => this.handlePreviewSurfaceDestroyed();
    this.initializeRuntime();
  }

  aboutToDisappear(): void {
    this.clearPasswordTimeout();
    this.clearSurfaceBinding();
    this.stopPolling();
    this.applySessionFullscreen(false);
  }

  private initializeRuntime(): void {
    if (this.runtimeInitialized) {
      this.refreshNativeState();
      return;
    }
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.preferences = new RustDeskPreferences(hostContext);
      this.applySavedSettings(this.preferences.load());

      const response = JSON.parse(native.runtimeInit(hostContext.filesDir, 'RustDesk HMOS')) as Record<string, string>;
      this.runtimeInitialized = true;
      this.apiServer = native.runtimeGetApiServer();
      this.nativeBuildMarker = native.buildMarker();
      const capabilityResponse = JSON.parse(native.runtimeGetDecoderCapabilities()) as DecoderCapabilityResponse;
      this.decoderCapabilitiesSummary = capabilityResponse.capabilities
        .map((item: DecoderCapability) => `${item.codec}:${item.recommendedName || '-'} hw=${String(item.hardwareAvailable)} sw=${String(item.softwareAvailable)}`)
        .join(' | ');
      this.sessionMessage = String(response['message'] ?? 'Runtime initialized');
      this.refreshNativeState();
    } catch (error) {
      this.errorText = `Runtime init failed: ${String(error)}`;
      hilog.error(DOMAIN, TAG, 'initializeRuntime failed: %{public}s', this.errorText);
    }
  }

  private applySavedSettings(settings: SavedConnectionSettings): void {
    this.peerTarget = settings.target;
    this.rememberPassword = settings.rememberPassword;
    this.savedPassword = settings.password;
  }

  private refreshNativeState(): void {
    try {
      this.nativeVersion = native.nativeVersion();
      this.health = native.healthcheck();
      const summary = JSON.parse(native.backendSummary()) as BridgeSummary;
      this.integrationStage = summary.integrationStage;
      this.upstreamRepo = summary.upstreamRepo;
      this.notes = summary.notes;
      this.apiServer = native.runtimeGetApiServer();
      this.nativeBuildMarker = native.buildMarker();
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'refreshNativeState failed: %{public}s', this.errorText);
    }
  }

  private nextSessionId(): string {
    return `hm-session-${Date.now().toString()}`;
  }

  private parseResponse(raw: string): ActionResponse {
    return JSON.parse(raw) as ActionResponse;
  }

  private async connectSession(): Promise<void> {
    if (!this.runtimeInitialized) {
      this.initializeRuntime();
    }
    const target = this.peerTarget.trim();
    if (target.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    this.preferences?.saveTarget(target);
    this.errorText = '';
    this.connectionSummary = '正在建立连接...';
    this.sessionMessage = '正在连接';
    this.showPreviewModal = false;
    this.performanceTuningApplied = false;
    this.resetPreviewState();
    await this.createSession();
    await this.startSession();
    this.startPolling();
  }

  private async createSession(): Promise<void> {
    try {
      const response = this.parseResponse(native.sessionAdd(this.nextSessionId(), this.peerTarget.trim(), JSON.stringify({
        password: '',
        forceRelay: false
      })));
      this.updateSessionState(response);
    } catch (error) {
      this.errorText = String(error);
    }
  }

  private async startSession(): Promise<void> {
    if (!this.activeSessionId) {
      return;
    }
    try {
      const response = this.parseResponse(native.sessionStart(this.activeSessionId));
      this.updateSessionState(response);
    } catch (error) {
      this.errorText = String(error);
    }
  }

  private openPasswordDialog(): void {
    if (this.passwordDialogVisible) {
      return;
    }
    this.passwordDraft = this.rememberPassword ? this.savedPassword : '';
    this.passwordDialogVisible = true;
    this.sessionPhase = 'awaiting_password';
    this.sessionMessage = '等待输入密码';
    this.connectionSummary = '已建立连接，等待密码验证';
    this.passwordDialogController = new CustomDialogController({
      builder: PasswordPromptDialog({
        controller: this.passwordDialogController,
        initialPassword: this.passwordDraft,
        initialRememberPassword: this.rememberPassword,
        onCancel: () => this.cancelPasswordDialog(),
        onSubmit: (password: string, rememberPassword: boolean) => this.submitPassword(password, rememberPassword)
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      autoCancel: false,
    });
    this.clearPasswordTimeout();
    this.passwordTimeoutId = setTimeout(() => {
      if (this.passwordDialogVisible) {
        this.passwordDialogController?.close();
        this.handleRemoteDisconnect('密码输入超时');
      }
    }, PASSWORD_TIMEOUT_MS) as number;
    this.passwordDialogController.open();
  }

  private clearPasswordTimeout(): void {
    if (this.passwordTimeoutId >= 0) {
      clearTimeout(this.passwordTimeoutId);
      this.passwordTimeoutId = -1;
    }
  }

  private async submitPassword(passwordInput?: string, rememberPasswordInput?: boolean): Promise<void> {
    if (!this.activeSessionId) {
      return;
    }
    if (rememberPasswordInput !== undefined) {
      this.rememberPassword = rememberPasswordInput;
    }
    const password = (passwordInput ?? this.passwordDraft).trim();
    if (password.length === 0) {
      this.errorText = '请输入密码';
      return;
    }
    this.passwordDraft = password;
    this.preferences?.savePassword(password, this.rememberPassword);
    this.savedPassword = this.rememberPassword ? password : '';
    this.passwordDialogVisible = false;
    this.passwordDialogController?.close();
    this.clearPasswordTimeout();
    try {
      const response = this.parseResponse(native.sessionLogin(this.activeSessionId, JSON.stringify({
        password,
        remember: false
      })));
      this.updateSessionState(response);
    } catch (error) {
      this.errorText = String(error);
    }
  }

  private cancelPasswordDialog(): void {
    this.passwordDialogVisible = false;
    this.passwordDialogController?.close();
    this.clearPasswordTimeout();
    this.closeSession('已取消密码输入');
  }

  private async closeSession(reason?: string): Promise<void> {
    const sessionId = this.activeSessionId;
    if (this.relativeMouseMode && sessionId) {
      this.syncRelativeMouseMode(false);
    }
    this.applySessionFullscreen(false);
    this.passwordDialogVisible = false;
    this.showPreviewModal = false;
    this.passwordDialogController?.close();
    this.clearPasswordTimeout();
    this.clearSurfaceBinding();
    this.stopPolling();
    this.resetPreviewState();
    this.connectionSummary = '未连接';
    if (reason) {
      this.sessionMessage = reason;
    }
    if (!sessionId) {
      this.sessionPhase = 'idle';
      return;
    }
    try {
      const response = this.parseResponse(native.sessionClose(sessionId));
      this.updateSessionState(response);
    } catch (error) {
      this.errorText = String(error);
    } finally {
      this.activeSessionId = '';
      this.activeCoreSessionId = '';
      this.sessionPhase = 'idle';
    }
  }

  private handleRemoteDisconnect(message: string): void {
    this.errorText = message;
    this.closeSession(message);
  }

  private resetPreviewState(): void {
    this.frameStatus = 'Surface not ready';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.previewViewWidth = 0;
    this.previewViewHeight = 0;
    this.previewSurfaceVisible = false;
    this.previewSurfaceGeneration = 0;
    this.renderFpsText = 'FPS --';
    this.remoteFpsText = '--';
    this.remoteDelayText = '--';
    this.remoteCodecText = '--';
    this.relativeMouseMode = false;
    this.relativeMouseHasLast = false;
    this.activeModifiers.clear();
    this.resetTouchpadState();
    this.remoteCursorVisible = false;
    this.remoteCursorLeft = 0;
    this.remoteCursorTop = 0;
    this.refreshQualitySummary();
  }

  private syncRelativeMouseMode(active: boolean): void {
    this.relativeMouseHasLast = false;
    this.cancelPendingTouchpadTap();
    this.touchpadDragActive = false;
  }

  private applySessionFullscreen(active: boolean): Promise<void> {
    if (this.sessionFullscreenApplied === active) {
      return Promise.resolve();
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return window.getLastWindow(hostContext)
      .then(async (currentWindow: window.Window) => {
        await currentWindow.setPreferredOrientation(
          active ? window.Orientation.LANDSCAPE : window.Orientation.AUTO_ROTATION,
        );
        await currentWindow.setWindowLayoutFullScreen(active);
        const bars: Array<'status' | 'navigation'> = active ? [] : ['status', 'navigation'];
        await currentWindow.setWindowSystemBarEnable(bars);
        this.sessionFullscreenApplied = active;
      })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'applySessionFullscreen failed: %{public}s', JSON.stringify(error) ?? '');
      });
  }

  private enterPreviewMode(event: NativeEvent): void {
    void this.applySessionFullscreen(true).then(async () => {
      await this.waitForPreviewWindowReady(true);
      this.showPreviewModal = true;
      this.previewSurfaceVisible = false;
      this.previewSurfaceId = '';
      this.frameWidth = 0;
      this.frameHeight = 0;
      this.frameStatus = 'Preparing preview surface';
      setTimeout(() => {
        this.configureDisplayFromPeerInfo(event);
      }, 80);
      setTimeout(() => {
        this.previewSurfaceGeneration += 1;
        this.previewSurfaceVisible = true;
      }, 220);
    });
  }

  private async waitForPreviewWindowReady(expectLandscape: boolean): Promise<void> {
    for (let index = 0; index < 8; index++) {
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const isLandscape = displayInfo.width >= displayInfo.height;
        if (isLandscape === expectLandscape) {
          await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
          return;
        }
      } catch (_error) {
        // ignore and retry
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
    }
  }

  private toggleRelativeMouseMode(): void {
    const nextMode = !this.relativeMouseMode;
    this.relativeMouseMode = nextMode;
    this.syncRelativeMouseMode(nextMode);
    if (nextMode) {
      this.ensureRelativeCursorAnchor();
    }
    this.sessionMessage = this.relativeMouseMode ? '已切换为相对鼠标模式' : '已切换为绝对鼠标模式';
  }

  private getPreviewInputSize(): RustDeskSize {
    const display = this.getCurrentDisplayInfo();
    if (display && display.width > 0 && display.height > 0) {
      return new RustDeskSize(display.width, display.height);
    }
    return new RustDeskSize(Math.max(this.frameWidth, 1), Math.max(this.frameHeight, 1));
  }

  private getPreviewContentSize(): RustDeskSize {
    const display = this.getCurrentDisplayInfo();
    if (display && display.original_width && display.original_height && display.original_width > 0 && display.original_height > 0) {
      return new RustDeskSize(display.original_width, display.original_height);
    }
    return this.getPreviewInputSize();
  }

  private getCurrentDisplayInfo(): PeerDisplayInfo | undefined {
    if (this.peerDisplays.length === 0) {
      return undefined;
    }
    const index = Math.min(this.currentDisplay, this.peerDisplays.length - 1);
    return this.peerDisplays[index];
  }

  private getPreviewRotationAngle(): number {
    return 0;
  }

  private getPreviewTransform() {
    const contentSize = this.getPreviewContentSize();
    const viewSize = this.getPreviewViewSize();
    return resolvePreviewTransform(
      viewSize.width,
      viewSize.height,
      contentSize.width,
      contentSize.height,
      this.getPreviewRotationAngle(),
    );
  }

  private getPreviewRenderSize(): RustDeskSize {
    return this.getPreviewTransform().renderSize;
  }

  private logRelativeDebug(label: string, payload: string): void {
    hilog.info(DOMAIN, TAG, 'RelMouse debug [%{public}s] %{public}s', label, payload);
  }

  private getPreviewViewSize(): RustDeskSize {
    if (this.showPreviewModal) {
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const density = Math.max(displayInfo.densityPixels, 1);
        const contentSize = this.getPreviewContentSize();
        const contentLandscape = contentSize.width >= contentSize.height;
        const majorAxis = Math.max(displayInfo.width, displayInfo.height) / density;
        const minorAxis = Math.min(displayInfo.width, displayInfo.height) / density;
        return contentLandscape
          ? new RustDeskSize(majorAxis, minorAxis)
          : new RustDeskSize(minorAxis, majorAxis);
      } catch (_error) {
        // fall through to layout-derived size
      }
    }
    return new RustDeskSize(
      Math.max(this.previewViewWidth || this.frameWidth, 1),
      Math.max(this.previewViewHeight || this.frameHeight, 1),
    );
  }

  private sendMousePayload(payload: RustDeskMousePayload): void {
    if (!this.activeSessionId) {
      return;
    }
    try {
      const response = this.parseResponse(native.sessionSendMouse(this.activeSessionId, JSON.stringify(payload)));
      if (!response.ok) {
        this.errorText = response.message ?? 'Mouse input failed';
      }
    } catch (error) {
      this.errorText = `Mouse input failed: ${String(error)}`;
    }
  }

  private sendRawMouseMessage(raw: string): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionSendMouse(this.activeSessionId, raw));
      if (!response.ok) {
        this.errorText = response.message ?? 'Mouse input failed';
        return false;
      }
      return true;
    } catch (error) {
      this.errorText = `Mouse input failed: ${String(error)}`;
      return false;
    }
  }

  private sendRelativeMouseButton(button: string, isDown: boolean): void {
    this.logRelativeDebug('button', `type=${isDown ? 'down' : 'up'} button=${button}`);
    this.sendRawMouseMessage(JSON.stringify({
      type: isDown ? 'down' : 'up',
      buttons: button,
    }));
  }

  private sendAbsoluteButtonAtCurrentCursor(button: string, isDown: boolean): void {
    this.logRelativeDebug(
      'abs_button',
      `type=${isDown ? 'down' : 'up'} button=${button} cursor=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`,
    );
    this.sendRemoteCursorPositionFromOverlay();
    const payload = new RustDeskMousePayload();
    payload.type = isDown ? 'down' : 'up';
    payload.buttons = button;
    this.sendMousePayload(payload);
  }

  private sendRemoteCursorPositionFromOverlay(): void {
    if (!this.activeSessionId || !this.remoteCursorVisible) {
      return;
    }
    const display = this.getCurrentDisplayInfo();
    const contentSize = this.getPreviewContentSize();
    const inputSize = this.getPreviewInputSize();
    const viewSize = this.getPreviewViewSize();
    const position = mapPointerToRemote(
      this.remoteCursorLeft,
      this.remoteCursorTop,
      viewSize.width,
      viewSize.height,
      contentSize.width,
      contentSize.height,
      inputSize.width,
      inputSize.height,
      display?.x ?? 0,
      display?.y ?? 0,
      this.getPreviewRotationAngle(),
    );
    const payload = new RustDeskMousePayload();
    payload.x = String(position.x);
    payload.y = String(position.y);
    this.sendMousePayload(payload);
  }

  private clickCurrentCursor(button: string): void {
    this.sendAbsoluteButtonAtCurrentCursor(button, true);
    this.sendAbsoluteButtonAtCurrentCursor(button, false);
  }

  private sendMouseClick(button: string): void {
    if (this.relativeMouseMode) {
      this.clickCurrentCursor(button);
      return;
    }
    const downPayload = new RustDeskMousePayload();
    downPayload.type = 'down';
    downPayload.buttons = button;
    this.sendMousePayload(downPayload);

    const upPayload = new RustDeskMousePayload();
    upPayload.type = 'up';
    upPayload.buttons = button;
    this.sendMousePayload(upPayload);
  }

  private clampCursorToPreview(x: number, y: number): void {
    const transform = this.getPreviewTransform();
    const minX = transform.contentRect.left;
    const maxX = transform.contentRect.left + transform.contentRect.width;
    const minY = transform.contentRect.top;
    const maxY = transform.contentRect.top + transform.contentRect.height;
    this.remoteCursorLeft = Math.min(Math.max(x, minX), maxX);
    this.remoteCursorTop = Math.min(Math.max(y, minY), maxY);
    this.remoteCursorVisible = true;
  }

  private ensureRelativeCursorAnchor(): void {
    if (this.remoteCursorVisible) {
      return;
    }
    const transform = this.getPreviewTransform();
    this.clampCursorToPreview(
      transform.contentRect.left + transform.contentRect.width / 2,
      transform.contentRect.top + transform.contentRect.height / 2,
    );
  }

  private isPointInsidePreviewContent(x: number, y: number): boolean {
    const transform = this.getPreviewTransform();
    return x >= transform.contentRect.left
      && x <= transform.contentRect.left + transform.contentRect.width
      && y >= transform.contentRect.top
      && y <= transform.contentRect.top + transform.contentRect.height;
  }

  private updateCursorOverlayFromRemote(remoteX: number, remoteY: number): void {
    if (this.relativeMouseMode) {
      if (this.relativeMoveLogCounter % RELATIVE_MOVE_LOG_SAMPLE_EVERY === 0) {
        this.logRelativeDebug('remote_cursor_ignored', `remote=(${remoteX},${remoteY}) local=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`);
      }
      return;
    }
    const display = this.getCurrentDisplayInfo();
    const contentSize = this.getPreviewContentSize();
    const inputSize = this.getPreviewInputSize();
    const viewSize = this.getPreviewViewSize();
    const position = mapRemoteToPointer(
      remoteX,
      remoteY,
      viewSize.width,
      viewSize.height,
      contentSize.width,
      contentSize.height,
      inputSize.width,
      inputSize.height,
      display?.x ?? 0,
      display?.y ?? 0,
      this.getPreviewRotationAngle(),
    );
    this.clampCursorToPreview(position.x, position.y);
  }

  private moveCursorOverlayBy(deltaX: number, deltaY: number): void {
    this.ensureRelativeCursorAnchor();
    this.clampCursorToPreview(this.remoteCursorLeft + deltaX, this.remoteCursorTop + deltaY);
  }

  private moveRelativeCursorBy(deltaX: number, deltaY: number): void {
    const moveX = Math.round(deltaX * TOUCHPAD_MOVE_SENSITIVITY);
    const moveY = Math.round(deltaY * TOUCHPAD_MOVE_SENSITIVITY);
    if (moveX === 0 && moveY === 0) {
      return;
    }
    this.moveCursorOverlayBy(moveX, moveY);
    this.sendRemoteCursorPositionFromOverlay();
  }

  private moveRemoteCursorToLocalPoint(localX: number, localY: number): void {
    if (!this.isPointInsidePreviewContent(localX, localY)) {
      return;
    }
    const display = this.getCurrentDisplayInfo();
    const contentSize = this.getPreviewContentSize();
    const inputSize = this.getPreviewInputSize();
    const viewSize = this.getPreviewViewSize();
    const position = mapPointerToRemote(
      localX,
      localY,
      viewSize.width,
      viewSize.height,
      contentSize.width,
      contentSize.height,
      inputSize.width,
      inputSize.height,
      display?.x ?? 0,
      display?.y ?? 0,
      this.getPreviewRotationAngle(),
    );
    const payload = new RustDeskMousePayload();
    payload.x = String(position.x);
    payload.y = String(position.y);
    this.sendMousePayload(payload);
    this.clampCursorToPreview(localX, localY);
  }

  private moveRemoteCursorAndClick(localX: number, localY: number, button: string): void {
    this.moveRemoteCursorToLocalPoint(localX, localY);
    this.sendMouseClick(button);
  }

  private resetTouchpadState(): void {
    this.cancelTouchpadLongPressTimer();
    this.touchpadPrimaryId = -1;
    this.touchpadSecondaryId = -1;
    this.touchpadPrimaryDownX = 0;
    this.touchpadPrimaryDownY = 0;
    this.touchpadPrimaryLastX = 0;
    this.touchpadPrimaryLastY = 0;
    this.touchpadPrimaryDownAt = 0;
    this.touchpadSecondaryLastX = 0;
    this.touchpadSecondaryLastY = 0;
    this.touchpadTapMoved = false;
    this.touchpadLongPressTriggered = false;
    this.touchpadDragActive = false;
  }

  private cancelTouchpadLongPressTimer(): void {
    if (this.touchpadLongPressTimer !== -1) {
      clearTimeout(this.touchpadLongPressTimer);
      this.touchpadLongPressTimer = -1;
    }
  }

  private cancelPendingTouchpadTap(): void {
    if (this.touchpadPendingTapTimer !== -1) {
      clearTimeout(this.touchpadPendingTapTimer);
      this.touchpadPendingTapTimer = -1;
    }
  }

  private startTouchpadLongPressTimer(): void {
    this.cancelTouchpadLongPressTimer();
    this.touchpadLongPressTimer = setTimeout(() => {
      this.touchpadLongPressTimer = -1;
      if (this.touchpadPrimaryId === -1 || this.touchpadSecondaryId !== -1 || this.touchpadTapMoved) {
        return;
      }
      this.touchpadLongPressTriggered = true;
      if (this.relativeMouseMode) {
        this.touchpadDragActive = true;
        this.sendAbsoluteButtonAtCurrentCursor('left', true);
      } else {
        this.moveRemoteCursorAndClick(this.touchpadPrimaryDownX, this.touchpadPrimaryDownY, 'right');
      }
    }, TOUCHPAD_LONG_PRESS_MS);
  }

  private scheduleRelativeSingleTap(): void {
    this.cancelPendingTouchpadTap();
    this.touchpadPendingTapTimer = setTimeout(() => {
      this.touchpadPendingTapTimer = -1;
      this.logRelativeDebug('single_tap_fire', `cursor=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`);
      this.clickCurrentCursor('left');
    }, TOUCHPAD_DOUBLE_TAP_MAX_MS);
  }

  private findTouchById(touches: Array<TouchObject>, pointerId: number): TouchObject | undefined {
    for (let index = 0; index < touches.length; index++) {
      const touch = touches[index];
      if (touch.id === pointerId) {
        return touch;
      }
    }
    return undefined;
  }

  private handlePreviewTouchEvent(event: TouchEvent): void {
    if (!this.activeSessionId) {
      return;
    }
    const changedTouches = event.changedTouches;
    switch (event.type) {
      case TouchType.Down:
        for (let index = 0; index < changedTouches.length; index++) {
          const touch = changedTouches[index];
          if (this.touchpadPrimaryId === -1) {
            this.touchpadPrimaryId = touch.id;
            this.touchpadPrimaryDownX = touch.x;
            this.touchpadPrimaryDownY = touch.y;
            this.touchpadPrimaryLastX = touch.x;
            this.touchpadPrimaryLastY = touch.y;
            this.touchpadPrimaryDownAt = Date.now();
            this.touchpadTapMoved = false;
            this.touchpadLongPressTriggered = false;
            this.startTouchpadLongPressTimer();
            continue;
          }
          if (this.touchpadSecondaryId === -1 && touch.id !== this.touchpadPrimaryId) {
            this.touchpadSecondaryId = touch.id;
            this.touchpadSecondaryLastX = touch.x;
            this.touchpadSecondaryLastY = touch.y;
            this.touchpadTapMoved = true;
            this.cancelTouchpadLongPressTimer();
          }
        }
        return;
      case TouchType.Move:
        break;
      case TouchType.Up:
      case TouchType.Cancel:
        this.handlePreviewTouchRelease(event);
        return;
      default:
        return;
    }

    if (this.touchpadPrimaryId === -1) {
      return;
    }
    if (this.touchpadSecondaryId !== -1) {
      const primaryTouch = this.findTouchById(event.touches, this.touchpadPrimaryId);
      const secondaryTouch = this.findTouchById(event.touches, this.touchpadSecondaryId);
      if (!primaryTouch || !secondaryTouch) {
        return;
      }
      const deltaX = ((primaryTouch.x - this.touchpadPrimaryLastX) + (secondaryTouch.x - this.touchpadSecondaryLastX)) / 2;
      const deltaY = ((primaryTouch.y - this.touchpadPrimaryLastY) + (secondaryTouch.y - this.touchpadSecondaryLastY)) / 2;
      this.touchpadPrimaryLastX = primaryTouch.x;
      this.touchpadPrimaryLastY = primaryTouch.y;
      this.touchpadSecondaryLastX = secondaryTouch.x;
      this.touchpadSecondaryLastY = secondaryTouch.y;
      this.cancelTouchpadLongPressTimer();
      const wheelX = Math.round(-deltaX * TOUCHPAD_SCROLL_SENSITIVITY);
      const wheelY = Math.round(-deltaY * TOUCHPAD_SCROLL_SENSITIVITY);
      if (wheelX === 0 && wheelY === 0) {
        return;
      }
      const payload = new RustDeskMousePayload();
      payload.type = 'wheel';
      payload.x = String(wheelX);
      payload.y = String(wheelY);
      this.sendMousePayload(payload);
      return;
    }

    if (!this.relativeMouseMode) {
      const primaryTouch = this.findTouchById(event.touches, this.touchpadPrimaryId);
      if (!primaryTouch) {
        return;
      }
      const movedX = primaryTouch.x - this.touchpadPrimaryDownX;
      const movedY = primaryTouch.y - this.touchpadPrimaryDownY;
      if (!this.touchpadTapMoved && Math.sqrt(movedX * movedX + movedY * movedY) > TOUCHPAD_TAP_MAX_DISTANCE) {
        this.touchpadTapMoved = true;
        this.cancelTouchpadLongPressTimer();
      }
      return;
    }

    const primaryTouch = this.findTouchById(event.touches, this.touchpadPrimaryId);
    if (!primaryTouch) {
      return;
    }
    const deltaX = primaryTouch.x - this.touchpadPrimaryLastX;
    const deltaY = primaryTouch.y - this.touchpadPrimaryLastY;
    this.touchpadPrimaryLastX = primaryTouch.x;
    this.touchpadPrimaryLastY = primaryTouch.y;
    const movedX = primaryTouch.x - this.touchpadPrimaryDownX;
    const movedY = primaryTouch.y - this.touchpadPrimaryDownY;
    if (!this.touchpadTapMoved && Math.sqrt(movedX * movedX + movedY * movedY) > TOUCHPAD_TAP_MAX_DISTANCE) {
      this.touchpadTapMoved = true;
      this.cancelTouchpadLongPressTimer();
    }
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    this.relativeTouchMoveLogCounter += 1;
    if (this.relativeTouchMoveLogCounter % RELATIVE_TOUCH_LOG_SAMPLE_EVERY === 0) {
      this.logRelativeDebug(
        'touch_move',
        `touch=(${primaryTouch.x.toFixed(1)},${primaryTouch.y.toFixed(1)}) rawVp=(${deltaX.toFixed(2)},${deltaY.toFixed(2)}) overlayBefore=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)}) drag=${this.touchpadDragActive}`,
      );
    }
    this.moveRelativeCursorBy(deltaX, deltaY);
  }

  private handlePreviewTouchRelease(event: TouchEvent): void {
    const changedTouches = event.changedTouches;
    let primaryReleased = false;
    let secondaryReleased = false;
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (touch.id === this.touchpadPrimaryId) {
        primaryReleased = true;
      }
      if (touch.id === this.touchpadSecondaryId) {
        secondaryReleased = true;
      }
    }

    if (secondaryReleased) {
      this.touchpadSecondaryId = -1;
      this.touchpadSecondaryLastX = 0;
      this.touchpadSecondaryLastY = 0;
    }

    if (primaryReleased) {
      const elapsed = Date.now() - this.touchpadPrimaryDownAt;
      this.logRelativeDebug(
        'touch_release',
        `elapsed=${elapsed} moved=${this.touchpadTapMoved} longPress=${this.touchpadLongPressTriggered} drag=${this.touchpadDragActive} cursor=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`,
      );
      if (this.relativeMouseMode && this.touchpadDragActive) {
        this.sendAbsoluteButtonAtCurrentCursor('left', false);
        this.resetTouchpadState();
        return;
      }
      if (!this.touchpadTapMoved && !this.touchpadLongPressTriggered && elapsed <= TOUCHPAD_TAP_MAX_MS) {
        if (this.relativeMouseMode) {
          const isDoubleTap = this.touchpadLastTapAt > 0
            && Date.now() - this.touchpadLastTapAt <= TOUCHPAD_DOUBLE_TAP_MAX_MS;
          if (isDoubleTap) {
            this.cancelPendingTouchpadTap();
            this.touchpadLastTapAt = 0;
            this.logRelativeDebug('double_tap', `cursor=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`);
            this.clickCurrentCursor('right');
          } else {
            this.touchpadLastTapAt = Date.now();
            this.touchpadLastTapX = this.remoteCursorLeft;
            this.touchpadLastTapY = this.remoteCursorTop;
            this.logRelativeDebug('single_tap_schedule', `cursor=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`);
            this.scheduleRelativeSingleTap();
          }
        } else {
          this.moveRemoteCursorAndClick(this.touchpadPrimaryDownX, this.touchpadPrimaryDownY, 'left');
        }
      }
      this.resetTouchpadState();
      return;
    }

    if (event.type === TouchType.Cancel || event.touches.length === 0) {
      this.resetTouchpadState();
    }
  }

  private sendKeyPayload(name: string, isDown: boolean): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    const payload: RustDeskKeyPayload = new RustDeskKeyPayload(name, isDown);
    if (this.activeModifiers.has('alt')) {
      payload.alt = true;
    }
    if (this.activeModifiers.has('ctrl')) {
      payload.ctrl = true;
    }
    if (this.activeModifiers.has('shift')) {
      payload.shift = true;
    }
    if (this.activeModifiers.has('command')) {
      payload.command = true;
    }
    try {
      const response = this.parseResponse(native.sessionInputKey(this.activeSessionId, JSON.stringify(payload)));
      if (!response.ok) {
        this.errorText = response.message ?? 'Keyboard input failed';
        return false;
      }
      return true;
    } catch (error) {
      this.errorText = `Keyboard input failed: ${String(error)}`;
      return false;
    }
  }

  private handlePreviewMouseEvent(event: MouseEvent): void {
    if (!this.activeSessionId) {
      return;
    }
    event.stopPropagation();
    const display = this.getCurrentDisplayInfo();
    const contentSize = this.getPreviewContentSize();
    const inputSize = this.getPreviewInputSize();
    const viewSize = this.getPreviewViewSize();
    if (event.action === MouseAction.Move || event.action === MouseAction.Hover) {
      if (this.relativeMouseMode) {
        const rawDeltaXVp = event.rawDeltaX ?? 0;
        const rawDeltaYVp = event.rawDeltaY ?? 0;
        let overlayDeltaX = rawDeltaXVp;
        let overlayDeltaY = rawDeltaYVp;
        let source = 'raw';
        if (overlayDeltaX === 0 && overlayDeltaY === 0 && this.relativeMouseHasLast) {
          overlayDeltaX = event.x - this.relativeMouseLastX;
          overlayDeltaY = event.y - this.relativeMouseLastY;
          source = 'fallback';
        }
        this.relativeMouseLastX = event.x;
        this.relativeMouseLastY = event.y;
        this.relativeMouseHasLast = true;
        if (overlayDeltaX === 0 && overlayDeltaY === 0) {
          return;
        }
        this.relativeMoveLogCounter += 1;
        if (this.relativeMoveLogCounter % RELATIVE_MOVE_LOG_SAMPLE_EVERY === 0) {
          this.logRelativeDebug(
            'move',
            `source=${source} event=(${event.x.toFixed(1)},${event.y.toFixed(1)}) rawVp=(${rawDeltaXVp.toFixed(2)},${rawDeltaYVp.toFixed(2)}) overlayVp=(${overlayDeltaX.toFixed(2)},${overlayDeltaY.toFixed(2)}) localBefore=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`,
          );
        }
        this.moveRelativeCursorBy(overlayDeltaX, overlayDeltaY);
        return;
      }
      this.relativeMouseHasLast = false;
      if (!this.isPointInsidePreviewContent(event.x, event.y)) {
        return;
      }
      const position = mapPointerToRemote(
        event.x,
        event.y,
        viewSize.width,
        viewSize.height,
        contentSize.width,
        contentSize.height,
        inputSize.width,
        inputSize.height,
        display?.x ?? 0,
        display?.y ?? 0,
        this.getPreviewRotationAngle(),
      );
      const payload = new RustDeskMousePayload();
      payload.x = String(position.x);
      payload.y = String(position.y);
      this.sendMousePayload(payload);
      this.clampCursorToPreview(event.x, event.y);
      return;
    }
    if (event.action !== MouseAction.Press && event.action !== MouseAction.Release) {
      return;
    }
    const button = mapMouseButton(event.button);
    if (!button) {
      return;
    }
    if (!this.relativeMouseMode && !this.isPointInsidePreviewContent(event.x, event.y)) {
      return;
    }
    if (this.relativeMouseMode) {
      this.logRelativeDebug('click', `type=${event.action === MouseAction.Press ? 'down' : 'up'} button=${button} local=(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`);
      this.sendAbsoluteButtonAtCurrentCursor(button, event.action === MouseAction.Press);
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = event.action === MouseAction.Press ? 'down' : 'up';
    payload.buttons = button;
    this.sendMousePayload(payload);
  }

  private handlePreviewAxisEvent(event: AxisEvent): void {
    if (!this.activeSessionId) {
      return;
    }
    const scrollStepValue = event.scrollStep ?? 1;
    const scrollStep = scrollStepValue > 0 ? scrollStepValue : 1;
    const deltaY = Math.round(-event.getVerticalAxisValue() / scrollStep * 8);
    const deltaX = Math.round(-event.getHorizontalAxisValue() / scrollStep * 8);
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = 'wheel';
    payload.x = String(deltaX);
    payload.y = String(deltaY);
    this.sendMousePayload(payload);
  }

  private handlePreviewKeyEvent(event: KeyEvent): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    const mapping = mapHarmonyKeyCode(event.keyCode);
    if (!mapping) {
      return false;
    }
    const isDown = event.type === KeyType.Down;
    const isUp = event.type === KeyType.Up;
    if (!isDown && !isUp) {
      return false;
    }
    if (mapping.modifier && isUp) {
      this.activeModifiers.delete(mapping.modifier);
    }
    const sent = this.sendKeyPayload(mapping.name, isDown);
    if (!sent) {
      return false;
    }
    if (mapping.modifier && isDown) {
      this.activeModifiers.add(mapping.modifier);
    }
    return true;
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    this.isPolling = false;
    this.lastRenderStatsPollAt = 0;
  }

  private startPolling(): void {
    if (!this.activeSessionId || this.pollTimer >= 0) {
      return;
    }
    this.isPolling = true;
    this.pollTimer = setInterval(() => {
      this.pollSessionEvents();
      const now = Date.now();
      if (now - this.lastRenderStatsPollAt >= RENDER_STATS_POLL_INTERVAL_MS) {
        this.lastRenderStatsPollAt = now;
        this.pollRenderStats();
      }
    }, EVENT_POLL_INTERVAL_MS);
  }

  private pollRenderStats(): void {
    if (!this.activeSessionId) {
      this.renderFpsText = 'FPS --';
      return;
    }
    try {
      const response = this.parseResponse(native.sessionGetRenderStats(this.activeSessionId, 0));
      const snapshot = response.stats?.stats;
      if (!snapshot || !snapshot.hasRenderedFrame) {
        this.renderFpsText = 'FPS --';
        return;
      }
      this.renderFpsText = `FPS ${snapshot.fps.toFixed(1)} | Frames ${snapshot.totalFrames}`;
    } catch (_) {
    }
  }

  private refreshQualitySummary(): void {
    this.qualitySummary = `Remote fps ${this.remoteFpsText} | delay ${this.remoteDelayText} | codec ${this.remoteCodecText}`;
  }

  private extractRemoteFps(raw: string | undefined): string | undefined {
    if (!raw || raw.length === 0) {
      return undefined;
    }
    try {
      const fpsMap = JSON.parse(raw) as Record<string, number>;
      const current = fpsMap[String(this.currentDisplay)];
      if (typeof current === 'number') {
        return String(current);
      }
      const first = Object.values(fpsMap)[0];
      if (typeof first === 'number') {
        return String(first);
      }
    } catch (_) {
      return raw;
    }
    return undefined;
  }

  private evenSize(value: number): number {
    return Math.max(64, Math.round(value)) & ~1;
  }

  private parseSupportedResolutions(raw: string | undefined): ResolutionInfo[] {
    if (!raw || raw.length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as ResolutionInfo[];
    } catch (_) {
      return [];
    }
  }

  private chooseRemoteResolution(targetWidth: number, targetHeight: number): ResolutionInfo | undefined {
    if (this.supportedResolutions.length === 0) {
      return undefined;
    }
    const targetRatio = targetWidth / Math.max(targetHeight, 1);
    const boundedCandidates = this.supportedResolutions.filter((candidate: ResolutionInfo) =>
      candidate.width > 0 && candidate.height > 0 && candidate.width <= targetWidth && candidate.height <= targetHeight
    );
    const candidates = boundedCandidates.length > 0 ? boundedCandidates : this.supportedResolutions;
    let best: ResolutionInfo | undefined = undefined;
    let bestScore = Number.MAX_SAFE_INTEGER;
    candidates.forEach((candidate: ResolutionInfo) => {
      if (candidate.width <= 0 || candidate.height <= 0) {
        return;
      }
      const ratioPenalty = Math.abs(candidate.width / candidate.height - targetRatio) * 1000;
      const sizePenalty = Math.abs(candidate.width - targetWidth) + Math.abs(candidate.height - targetHeight);
      const score = ratioPenalty + sizePenalty;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    });
    return best;
  }

  private configureDisplayFromPeerInfo(event: NativeEvent): void {
    if (!event.displays) {
      return;
    }
    try {
      this.peerDisplays = JSON.parse(event.displays) as PeerDisplayInfo[];
      this.supportedResolutions = this.parseSupportedResolutions(event.resolutions);
      if (this.peerDisplays.length === 0) {
        return;
      }
      this.currentDisplay = Number(event.current_display ?? '0');
      this.applyDisplayConfiguration();
    } catch (error) {
      this.errorText = `Display setup failed: ${String(error)}`;
    }
  }

  private applyDisplayConfiguration(): void {
    if (!this.activeSessionId || this.peerDisplays.length === 0) {
      return;
    }
    const currentDisplay = Math.min(this.currentDisplay, this.peerDisplays.length - 1);
    const primaryDisplay = this.peerDisplays[currentDisplay];
    const requestedWidth = this.evenSize(
      primaryDisplay.original_width && primaryDisplay.original_width > 0 ? primaryDisplay.original_width : primaryDisplay.width,
    );
    const requestedHeight = this.evenSize(
      primaryDisplay.original_height && primaryDisplay.original_height > 0 ? primaryDisplay.original_height : primaryDisplay.height,
    );
    this.updateSessionState(this.parseResponse(native.sessionSwitchDisplay(this.activeSessionId, JSON.stringify([currentDisplay]))));
    this.updateSessionState(this.parseResponse(native.sessionUpdateSupportedDecodings(this.activeSessionId)));
    this.updateSessionState(this.parseResponse(native.sessionSetSize(
      this.activeSessionId,
      currentDisplay,
      requestedWidth,
      requestedHeight
    )));
    const remoteResolution = this.chooseRemoteResolution(requestedWidth, requestedHeight);
    if (remoteResolution) {
      this.updateSessionState(this.parseResponse(native.sessionChangeResolution(
        this.activeSessionId,
        currentDisplay,
        remoteResolution.width,
        remoteResolution.height
      )));
    }
    this.frameStatus = `Requested remote size ${requestedWidth}x${requestedHeight}`;
    this.requestVideoRefresh();
  }

  private handlePreviewSurfaceCreated(surfaceId: string): void {
    setTimeout(() => {
      this.previewSurfaceId = surfaceId;
      this.frameStatus = `Surface created ${surfaceId}`;
      this.syncSurfaceBinding();
    }, 0);
  }

  private handlePreviewSurfaceChanged(rect: SurfaceRect): void {
    setTimeout(() => {
      this.frameWidth = rect.surfaceWidth;
      this.frameHeight = rect.surfaceHeight;
      this.frameStatus = `Surface ready ${rect.surfaceWidth}x${rect.surfaceHeight}`;
      this.applyDisplayConfiguration();
    }, 0);
  }

  private handlePreviewSurfaceDestroyed(): void {
    setTimeout(() => {
      this.clearSurfaceBinding();
      this.previewSurfaceId = '';
      this.frameWidth = 0;
      this.frameHeight = 0;
      this.frameStatus = 'Surface destroyed';
    }, 0);
  }

  private syncSurfaceBinding(): void {
    if (!this.activeSessionId || this.previewSurfaceId.length === 0) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionBindSurface(this.activeSessionId, 0, this.previewSurfaceId)));
      this.requestVideoRefresh();
    } catch (error) {
      this.errorText = `Surface bind failed: ${String(error)}`;
    }
  }

  private clearSurfaceBinding(): void {
    if (!this.activeSessionId) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionBindSurface(this.activeSessionId, 0, '')));
    } catch (_) {
    }
  }

  private updateSessionState(response: ActionResponse): void {
    if (response.session) {
      this.activeSessionId = response.session.sessionId;
      this.activeCoreSessionId = response.session.coreSessionId ?? '';
      this.sessionPhase = response.session.phase;
    }
    this.sessionMessage = response.message ?? response.action;
    if (!response.ok) {
      this.errorText = response.message ?? 'Native action failed';
    }
  }

  private applyPerformanceTuning(): void {
    if (!this.activeSessionId || this.performanceTuningApplied) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionSetImageQuality(this.activeSessionId, 'low')));
      this.updateSessionState(this.parseResponse(native.sessionSetCustomFps(this.activeSessionId, 90)));
      this.performanceTuningApplied = true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'applyPerformanceTuning failed: %{public}s', String(error));
    }
  }

  private async pollSessionEvents(): Promise<void> {
    if (!this.activeSessionId || this.eventPollInFlight) {
      return;
    }
    this.eventPollInFlight = true;
    try {
      const response = this.parseResponse(native.sessionPollEvents(this.activeSessionId, 20));
      this.updateSessionState(response);
      const events = (response.events ?? []) as NativeEvent[];
      events.forEach((event: NativeEvent) => {
        if (event.name === 'connection_ready') {
          this.connectionSummary = `secure=${String(event.secure)}, direct=${String(event.direct)}, stream=${String(event.stream_type)}`;
          if (this.activeSessionId) {
            this.updateSessionState(this.parseResponse(native.sessionUpdateSupportedDecodings(this.activeSessionId)));
          }
          this.performanceTuningApplied = false;
        }
        if (event.name === 'peer_info') {
          this.connectionSummary = `peer=${String(event.hostname)}, platform=${String(event.platform)}, version=${String(event.version)}`;
          this.applyPerformanceTuning();
          if (!this.showPreviewModal || !this.previewSurfaceVisible) {
            this.enterPreviewMode(event);
          } else {
            this.configureDisplayFromPeerInfo(event);
          }
        }
        if (event.name === 'update_quality_status') {
          const fpsText = this.extractRemoteFps(event.fps);
          if (fpsText) {
            this.remoteFpsText = fpsText;
          }
          if (event.delay && event.delay.length > 0) {
            this.remoteDelayText = String(event.delay);
          }
          if (event.codec_format && event.codec_format.length > 0) {
            this.remoteCodecText = String(event.codec_format);
          }
          this.refreshQualitySummary();
        }
        if (event.name === 'cursor_position') {
          this.updateCursorOverlayFromRemote(Number(event.x ?? '0'), Number(event.y ?? '0'));
        }
        if (event.name === 'msgbox') {
          const message = `${String(event.title)}: ${String(event.text)}`;
          if (event.type === 'success' || event.title === 'Successful') {
            this.sessionMessage = message;
            this.errorText = '';
            return;
          }
          if (event.type === 'input-password' || event.type === 're-input-password') {
            this.connectionSummary = '已建立连接，等待密码验证';
            this.errorText = message;
            this.openPasswordDialog();
            return;
          }
          this.handleRemoteDisconnect(message);
        }
      });
    } catch (error) {
      this.errorText = String(error);
    } finally {
      this.eventPollInFlight = false;
    }
  }

  private requestVideoRefresh(): void {
    if (!this.activeSessionId) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionRefresh(this.activeSessionId, 0)));
    } catch (error) {
      this.errorText = `Refresh error: ${String(error)}`;
    }
  }

  @Builder
  previewModalBuilder() {
    Stack() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.previewSurfaceVisible) {
          XComponent({
            id: `rustdesk-preview-surface-${this.previewSurfaceGeneration.toString()}`,
            type: XComponentType.SURFACE,
            controller: this.previewController
          })
            .width(this.getPreviewRenderSize().width)
            .height(this.getPreviewRenderSize().height)
            .backgroundColor('#000000');
        } else {
          Text('Preparing preview...')
            .fontSize(14)
            .fontColor('#FFFFFF');
        }

        if (this.remoteCursorVisible) {
          Path()
            .width(18)
            .height(24)
            .commands('M1 1 L1 20 L6 15 L9 23 L12 22 L9 14 L16 14 Z')
            .fill('#FFFFFF')
            .stroke('#111111')
            .strokeWidth(1.4)
            .position({ x: this.remoteCursorLeft - 1, y: this.remoteCursorTop - 1 })
            .hitTestBehavior(HitTestMode.None);
        }
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .focusable(true)
        .defaultFocus(true)
        .onKeyEvent((event: KeyEvent) => this.handlePreviewKeyEvent(event))
        .onMouse((event: MouseEvent) => {
          this.handlePreviewMouseEvent(event);
        })
        .onAxisEvent((event: AxisEvent) => {
          this.handlePreviewAxisEvent(event);
        })
        .onTouch((event: TouchEvent) => {
          this.handlePreviewTouchEvent(event);
        })
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.previewViewWidth = newArea.width as number;
          this.previewViewHeight = newArea.height as number;
        });

      Column({ space: 4 }) {
        Text(this.qualitySummary)
          .fontSize(12)
          .fontColor('#FFFFFF');

        Text(this.frameStatus)
          .fontSize(12)
          .fontColor('#FFFFFF');

        Text(`Input: ${this.relativeMouseMode ? 'relative' : 'absolute'}`)
          .fontSize(12)
          .fontColor('#FFFFFF');
      }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#7A111111')
        .borderRadius(12)
        .position({ x: 20, y: 20 });

      Row() {
        Row({ space: 10 }) {
          Button(this.relativeMouseMode ? '相对鼠标' : '绝对鼠标')
            .height(38)
            .backgroundColor(this.relativeMouseMode ? '#3F6FE0' : '#46576B')
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.toggleRelativeMouseMode());

          Button('断开连接')
            .height(38)
            .backgroundColor($r('sys.color.ohos_id_color_alert'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.closeSession('已手动断开连接'));
        }
      }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .padding({ top: 20, right: 20, left: 20 });
    }
    .width('100%')
    .height('100%');
  }

  build() {
    if (this.showPreviewModal) {
      this.previewModalBuilder();
    } else {
      HdsNavigation(this.pageInfos) {
        HdsTabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
          TabContent() {
            ConnectTab({
              target: this.peerTarget,
              connectionSummary: this.connectionSummary,
              sessionMessage: this.sessionMessage,
              sessionPhase: this.sessionPhase,
              rememberPassword: this.rememberPassword,
              canDisconnect: this.activeSessionId.length > 0,
              scroller: this.connectScroller,
              onTargetChange: (value: string) => this.peerTarget = value,
              onConnect: () => this.connectSession(),
              onDisconnect: () => this.closeSession('已手动断开连接')
            })
          }.tabBar(new BottomTabBarStyle($r('app.media.startIcon'), '连接'))

          TabContent() {
            SettingsTab({
              rememberPassword: this.rememberPassword,
              nativeVersion: this.nativeVersion,
              health: this.health,
              integrationStage: this.integrationStage,
              upstreamRepo: this.upstreamRepo,
              apiServer: this.apiServer,
              buildMarker: this.nativeBuildMarker,
              decoderSummary: this.decoderCapabilitiesSummary,
              notes: this.notes,
              errorText: this.errorText,
              scroller: this.settingsScroller,
              onRefresh: () => this.refreshNativeState(),
              onForgetPassword: () => {
                this.rememberPassword = false;
                this.savedPassword = '';
                this.preferences?.clearPassword();
              }
            })
          }.tabBar(new BottomTabBarStyle($r('app.media.startIcon'), '设置'))
        }
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
        .width('100%')
        .height('100%')
      }
      .titleMode(HdsNavigationTitleMode.FREE)
      .titleBar({
        content: {
          title: {
            mainTitle: this.currentTabIndex === 0 ? 'Resk' : '连接设置',
            subTitle: this.currentTabIndex === 0 ? '输入 IP 连接远端设备' : '只保留连接相关设置与原生桥状态。'
          }
        }
      })
      .bindToScrollable([this.currentTabIndex === 0 ? this.connectScroller : this.settingsScroller])
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'));
    }
  }
}
