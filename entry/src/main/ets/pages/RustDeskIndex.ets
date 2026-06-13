import { HdsNavigation, HdsNavigationTitleMode, HdsTabs } from '@kit.UIDesignKit';
import native from 'rustdesk-ohrs';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ConnectTab } from './rustdesk/components/ConnectTab';
import { PasswordPromptDialog } from './rustdesk/components/PasswordPromptDialog';
import { SettingsTab } from './rustdesk/components/SettingsTab';
import { RustDeskPreferences } from './rustdesk/RustDeskPreferences';
import { RustDeskSurfaceController } from './rustdesk/RustDeskSurfaceController';
import {
  isLocalPointInsidePaintRect,
  mapHarmonyKeyCode,
  mapLocalToRemote,
  mapMouseButton,
  mapRemoteToLocal,
  resolveCoordinateSpace,
  RustDeskCoordinateSpace,
  LocalPointerPosition,
  RemotePointerPosition,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskModifierKey,
  RustDeskRect,
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
const TOUCHPAD_MOVE_SENSITIVITY = 1.0;
const TOUCHPAD_SCROLL_SENSITIVITY = 1.6;
const RELATIVE_MOUSE_RAW_SENSITIVITY = 1.0;
const RELATIVE_MOUSE_FALLBACK_SENSITIVITY = 1.0;
const RELATIVE_MOUSE_FLUSH_MS = 8;
const RELATIVE_MOUSE_MAX_DELTA = 10000;
const RELATIVE_MOUSE_BUTTON_SUPPRESS_MS = 120;
const ABSOLUTE_MOUSE_LOG_SAMPLE_EVERY = 10;
const RELATIVE_MOVE_LOG_SAMPLE_EVERY = 8;
const RELATIVE_TOUCH_LOG_SAMPLE_EVERY = 6;
const PREFERRED_CODEC_REAPPLY_MS = 5000;
const REMOTE_CURSOR_OPTION_REAPPLY_MS = 1000;

interface RemoteCursorBitmap {
  id: string;
  pixelMap: image.PixelMap;
  hotX: number;
  hotY: number;
  width: number;
  height: number;
}

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
  @State previewViewWidth: number = 0;
  @State previewViewHeight: number = 0;

  private runtimeInitialized: boolean = false;
  private pollTimer: number = -1;
  private passwordTimeoutId: number = -1;
  private eventPollInFlight: boolean = false;
  private performanceTuningApplied: boolean = false;
  private lastRenderStatsPollAt: number = 0;
  private previewSurfaceId: string = '';
  private currentDisplay: number = 0;
  private peerPlatform: string = '';
  private peerDisplays: PeerDisplayInfo[] = [];
  private supportedResolutions: ResolutionInfo[] = [];
  private remoteFpsText: string = '--';
  private remoteDelayText: string = '--';
  private remoteCodecText: string = '--';
  private preferredCodec: string = 'h264';
  private codecPreferenceApplied: boolean = false;
  private lastCodecPreferenceAppliedAt: number = 0;
  private savedPassword: string = '';
  private passwordDialogVisible: boolean = false;
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
  private relativeMousePendingX: number = 0;
  private relativeMousePendingY: number = 0;
  private relativeMouseFlushTimer: number = -1;
  private relativeMouseSuppressMoveUntil: number = 0;
  private mouseButtonsDown: Set<string> = new Set();
  private sessionFullscreenApplied: boolean = false;
  private relativeMoveLogCounter: number = 0;
  private relativeTouchMoveLogCounter: number = 0;
  private absoluteMoveLogCounter: number = 0;
  private remoteCursorEventLogCounter: number = 0;
  private relativeModeActivatedAt: number = 0;
  private remoteCursorOptionApplied: boolean = false;
  private remoteCursorOptionLastAppliedAt: number = 0;
  private lastRemoteCursorValid: boolean = false;
  private lastRemoteCursorX: number = 0;
  private lastRemoteCursorY: number = 0;
  private lastRemoteCursorAt: number = 0;
  private remoteCursorCurrentId: string = '-1';
  private remoteCursorCache: Map<string, RemoteCursorBitmap> = new Map();
  @State remoteCursorVisible: boolean = false;
  @State remoteCursorLeft: number = 0;
  @State remoteCursorTop: number = 0;
  @State remoteCursorPixelMap: image.PixelMap | undefined = undefined;
  @State remoteCursorBitmapWidth: number = 0;
  @State remoteCursorBitmapHeight: number = 0;
  @State remoteCursorHotX: number = 0;
  @State remoteCursorHotY: number = 0;

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
      this.preferredCodec = this.selectPreferredCodec(capabilityResponse.capabilities);
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
    this.currentDisplay = 0;
    this.peerPlatform = '';
    this.peerDisplays = [];
    this.supportedResolutions = [];
    this.previewSurfaceVisible = false;
    this.previewSurfaceGeneration = 0;
    this.renderFpsText = 'FPS --';
    this.remoteFpsText = '--';
    this.remoteDelayText = '--';
    this.remoteCodecText = '--';
    this.codecPreferenceApplied = false;
    this.lastCodecPreferenceAppliedAt = 0;
    this.relativeMouseMode = false;
    this.resetRelativeMouseState(false);
    this.mouseButtonsDown.clear();
    this.activeModifiers.clear();
    this.resetTouchpadState();
    this.remoteCursorVisible = false;
    this.remoteCursorLeft = 0;
    this.remoteCursorTop = 0;
    this.releaseRemoteCursorCache();
    this.remoteCursorCurrentId = '-1';
    this.remoteCursorOptionApplied = false;
    this.remoteCursorOptionLastAppliedAt = 0;
    this.lastRemoteCursorValid = false;
    this.lastRemoteCursorX = 0;
    this.lastRemoteCursorY = 0;
    this.lastRemoteCursorAt = 0;
    this.relativeModeActivatedAt = 0;
    this.remoteCursorEventLogCounter = 0;
    this.refreshQualitySummary();
  }

  private syncRelativeMouseMode(active: boolean): void {
    if (!active) {
      this.flushRelativeMouseMove();
    }
    this.resetRelativeMouseState(false);
    this.cancelPendingTouchpadTap();
    this.touchpadDragActive = false;
    if (active) {
      this.relativeModeActivatedAt = Date.now();
      this.ensureRemoteCursorEnabled();
      this.showRemoteCursorOverlayFromLastPosition();
      this.sendRawMouseMessage(JSON.stringify({
        relative_mouse_mode: '1',
      }));
      this.logRelativeDebug('mode', `active=true localMarker=sent ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
      return;
    }
    this.relativeModeActivatedAt = 0;
    this.sendRawMouseMessage(JSON.stringify({
      relative_mouse_mode: '0',
    }));
    this.logRelativeDebug('mode', `active=false ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
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
    this.sessionMessage = this.relativeMouseMode ? '已切换为相对鼠标模式' : '已切换为绝对鼠标模式';
  }

  private getRemoteDisplayRect(): RustDeskRect | undefined {
    const peerDisplay = this.getCurrentDisplayInfo();
    if (peerDisplay && peerDisplay.width > 0 && peerDisplay.height > 0) {
      return this.getRawDisplayRect(peerDisplay);
    }
    return undefined;
  }

  private getRawDisplayRect(displayInfo: PeerDisplayInfo): RustDeskRect {
    return new RustDeskRect(displayInfo.x, displayInfo.y, displayInfo.width, displayInfo.height);
  }

  private getCurrentDisplayInfo(): PeerDisplayInfo | undefined {
    if (this.peerDisplays.length === 0) {
      return undefined;
    }
    const index = Math.min(this.currentDisplay, this.peerDisplays.length - 1);
    return this.peerDisplays[index];
  }

  private getDisplayScaleFactor(displayInfo: PeerDisplayInfo): number {
    const scaledWidth = Number(displayInfo.scaled_width ?? 0);
    const scaledHeight = Number(displayInfo.scaled_height ?? 0);
    if (scaledWidth <= 0 || scaledHeight <= 0 || displayInfo.width <= 0 || displayInfo.height <= 0) {
      return 1;
    }
    const widthScale = displayInfo.width / scaledWidth;
    const heightScale = displayInfo.height / scaledHeight;
    if (widthScale <= 1.01 || heightScale <= 1.01) {
      return 1;
    }
    if (Math.abs(widthScale - heightScale) > 0.08) {
      return 1;
    }
    return Math.max(widthScale, heightScale);
  }

  private mapLocalDeltaToRelativePointerDelta(deltaX: number, deltaY: number): RemotePointerPosition {
    return { x: deltaX, y: deltaY };
  }

  private getPreviewRotationAngle(): number {
    return 0;
  }

  private getPreviewViewSize(): RustDeskSize | undefined {
    if (this.previewViewWidth > 0 && this.previewViewHeight > 0) {
      return new RustDeskSize(this.previewViewWidth, this.previewViewHeight);
    }
    return undefined;
  }

  private getCoordinateSpace(): RustDeskCoordinateSpace | undefined {
    const remoteRect = this.getRemoteDisplayRect();
    const viewSize = this.getPreviewViewSize();
    if (!remoteRect || !viewSize) {
      return undefined;
    }
    return resolveCoordinateSpace(
      viewSize.width,
      viewSize.height,
      remoteRect,
      this.getPreviewRotationAngle(),
    );
  }

  private getRemoteCursorScale(): number {
    const space = this.getCoordinateSpace();
    if (!space) {
      return 1;
    }
    const renderScale = space.paintRect.width / Math.max(space.remoteRect.width, 1);
    return Math.min(Math.max(renderScale, 0.75), 2.0);
  }

  private isCurrentDisplayCursorEmbedded(): boolean {
    const displayInfo = this.getCurrentDisplayInfo();
    return Number(displayInfo?.cursor_embedded ?? 0) === 1;
  }

  private shouldDrawRemoteCursorOverlay(): boolean {
    if (!this.remoteCursorVisible) {
      return false;
    }
    return this.relativeMouseMode || !this.isCurrentDisplayCursorEmbedded();
  }

  private releaseRemoteCursorCache(): void {
    this.remoteCursorPixelMap = undefined;
    this.remoteCursorBitmapWidth = 0;
    this.remoteCursorBitmapHeight = 0;
    this.remoteCursorHotX = 0;
    this.remoteCursorHotY = 0;
    this.remoteCursorCache.forEach((cursor: RemoteCursorBitmap) => {
      cursor.pixelMap.release().catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'release cursor pixelmap failed: %{public}s', JSON.stringify(error) ?? '');
      });
    });
    this.remoteCursorCache.clear();
  }

  private getPreviewRenderSize(): RustDeskSize {
    const space = this.getCoordinateSpace();
    if (space) {
      return space.renderSize;
    }
    const remoteRect = this.getRemoteDisplayRect();
    if (remoteRect) {
      return new RustDeskSize(remoteRect.width, remoteRect.height);
    }
    return new RustDeskSize(1, 1);
  }

  private logRelativeDebug(label: string, payload: string): void {
    hilog.info(DOMAIN, TAG, 'RelMouse debug [%{public}s] %{public}s', label, payload);
  }

  private remoteCursorDebugText(): string {
    if (!this.lastRemoteCursorValid) {
      return 'remoteActual=none';
    }
    const modeAgeText = this.relativeMouseMode && this.relativeModeActivatedAt > 0
      ? ` modeAge=${Date.now() - this.relativeModeActivatedAt}ms`
      : '';
    return `remoteActual=(${this.lastRemoteCursorX.toFixed(0)},${this.lastRemoteCursorY.toFixed(0)}) age=${Date.now() - this.lastRemoteCursorAt}ms${modeAgeText}`;
  }

  private overlayCursorDebugText(label: string): string {
    if (!this.remoteCursorVisible) {
      return `${label}=none`;
    }
    return `${label}=actual(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`;
  }

  private clampRelativeMouseDelta(delta: number): number {
    return Math.min(Math.max(delta, -RELATIVE_MOUSE_MAX_DELTA), RELATIVE_MOUSE_MAX_DELTA);
  }

  private truncateRelativeMouseDelta(delta: number): number {
    return delta < 0 ? Math.ceil(delta) : Math.floor(delta);
  }

  private resetRelativeMouseState(flushPending: boolean = true): void {
    if (flushPending) {
      this.flushRelativeMouseMove();
    }
    if (this.relativeMouseFlushTimer !== -1) {
      clearTimeout(this.relativeMouseFlushTimer);
      this.relativeMouseFlushTimer = -1;
    }
    this.relativeMouseLastX = 0;
    this.relativeMouseLastY = 0;
    this.relativeMouseHasLast = false;
    this.relativeMousePendingX = 0;
    this.relativeMousePendingY = 0;
    this.relativeMouseSuppressMoveUntil = 0;
  }

  private discardRelativeMouseMove(): void {
    if (this.relativeMouseFlushTimer !== -1) {
      clearTimeout(this.relativeMouseFlushTimer);
      this.relativeMouseFlushTimer = -1;
    }
    this.relativeMousePendingX = 0;
    this.relativeMousePendingY = 0;
  }

  private rebaseRelativeMouseAtLocalPoint(localX: number, localY: number, discardPending: boolean = true): void {
    if (discardPending) {
      this.discardRelativeMouseMove();
    }
    this.relativeMouseLastX = localX;
    this.relativeMouseLastY = localY;
    this.relativeMouseHasLast = true;
  }

  private mapLocalPointToRemotePosition(localX: number, localY: number): RemotePointerPosition | undefined {
    const space = this.getCoordinateSpace();
    if (!space) {
      return undefined;
    }
    return mapLocalToRemote(space, localX, localY);
  }

  private mapRemotePositionToLocalPoint(remoteX: number, remoteY: number): LocalPointerPosition | undefined {
    const space = this.getCoordinateSpace();
    if (!space) {
      return undefined;
    }
    return mapRemoteToLocal(space, remoteX, remoteY);
  }

  private clampRemoteCursorPosition(x: number, y: number): RemotePointerPosition {
    const rect = this.getRemoteDisplayRect();
    if (!rect) {
      return { x, y };
    }
    const maxX = rect.left + Math.max(rect.width, 1) - 1;
    const maxY = rect.top + Math.max(rect.height, 1) - 1;
    return {
      x: Math.round(Math.min(Math.max(x, rect.left), maxX)),
      y: Math.round(Math.min(Math.max(y, rect.top), maxY)),
    };
  }

  private updatePredictedRemoteCursorBy(deltaX: number, deltaY: number): void {
    if (!this.lastRemoteCursorValid) {
      return;
    }
    const predicted = this.clampRemoteCursorPosition(
      this.lastRemoteCursorX + deltaX,
      this.lastRemoteCursorY + deltaY,
    );
    this.lastRemoteCursorX = predicted.x;
    this.lastRemoteCursorY = predicted.y;
    this.lastRemoteCursorAt = Date.now();
    const local = this.mapRemotePositionToLocalPoint(predicted.x, predicted.y);
    if (local) {
      this.setCursorOverlayLocalPoint(local.x, local.y);
    }
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

  private sendRelativeMouseButton(button: string, isDown: boolean, flushPending: boolean = true): void {
    if (flushPending) {
      this.flushRelativeMouseMove();
    }
    this.logRelativeDebug(
      'button',
      `type=${isDown ? 'down' : 'up'} button=${button} flush=${flushPending} ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`,
    );
    this.sendRawMouseMessage(JSON.stringify({
      type: isDown ? 'down' : 'up',
      buttons: button,
    }));
  }

  private sendRelativeMouseMoveNow(deltaX: number, deltaY: number): void {
    const sent = this.sendRawMouseMessage(JSON.stringify({
      type: 'move_relative',
      x: String(deltaX),
      y: String(deltaY),
    }));
    if (sent) {
      this.updatePredictedRemoteCursorBy(deltaX, deltaY);
    }
  }

  private scheduleRelativeMouseFlush(): void {
    if (this.relativeMouseFlushTimer !== -1) {
      return;
    }
    this.relativeMouseFlushTimer = setTimeout(() => {
      this.relativeMouseFlushTimer = -1;
      this.flushRelativeMouseMove();
    }, RELATIVE_MOUSE_FLUSH_MS) as number;
  }

  private flushRelativeMouseMove(): void {
    if (this.relativeMouseFlushTimer !== -1) {
      clearTimeout(this.relativeMouseFlushTimer);
      this.relativeMouseFlushTimer = -1;
    }
    const moveX = this.truncateRelativeMouseDelta(this.clampRelativeMouseDelta(this.relativeMousePendingX));
    const moveY = this.truncateRelativeMouseDelta(this.clampRelativeMouseDelta(this.relativeMousePendingY));
    if (moveX === 0 && moveY === 0) {
      return;
    }
    this.relativeMousePendingX -= moveX;
    this.relativeMousePendingY -= moveY;
    this.sendRelativeMouseMoveNow(moveX, moveY);
    if (Math.abs(this.relativeMousePendingX) >= 1 || Math.abs(this.relativeMousePendingY) >= 1) {
      this.scheduleRelativeMouseFlush();
    }
  }

  private queueRelativeMouseMove(remoteDeltaX: number, remoteDeltaY: number): void {
    if (Math.abs(remoteDeltaX) < 0.01 && Math.abs(remoteDeltaY) < 0.01) {
      return;
    }
    this.relativeMousePendingX = this.clampRelativeMouseDelta(this.relativeMousePendingX + remoteDeltaX);
    this.relativeMousePendingY = this.clampRelativeMouseDelta(this.relativeMousePendingY + remoteDeltaY);
    this.scheduleRelativeMouseFlush();
  }

  private sendButtonAtCurrentRemoteCursor(button: string, isDown: boolean): void {
    this.logRelativeDebug(
      'cursor_button',
      `type=${isDown ? 'down' : 'up'} button=${button} ${this.remoteCursorDebugText()}`,
    );
    const payload = new RustDeskMousePayload();
    payload.type = isDown ? 'down' : 'up';
    payload.buttons = button;
    this.sendMousePayload(payload);
  }

  private clickCurrentCursor(button: string): void {
    if (this.relativeMouseMode) {
      this.sendRelativeMouseButton(button, true, false);
      this.sendRelativeMouseButton(button, false, false);
      return;
    }
    this.sendButtonAtCurrentRemoteCursor(button, true);
    this.sendButtonAtCurrentRemoteCursor(button, false);
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

  private ensureRemoteCursorEnabled(): void {
    if (!this.activeSessionId) {
      return;
    }
    const hasCursorEvent = this.lastRemoteCursorValid || this.remoteCursorCache.size > 0;
    if (this.remoteCursorOptionApplied && hasCursorEvent) {
      return;
    }
    const now = Date.now();
    if (this.remoteCursorOptionLastAppliedAt > 0 && now - this.remoteCursorOptionLastAppliedAt < REMOTE_CURSOR_OPTION_REAPPLY_MS) {
      return;
    }
    this.remoteCursorOptionLastAppliedAt = now;
    try {
      const response = this.parseResponse(native.sessionSetShowRemoteCursor(this.activeSessionId, true));
      this.remoteCursorOptionApplied = response.ok;
      if (!response.ok && response.message) {
        this.logRelativeDebug('show_remote_cursor', response.message);
      } else {
        this.logRelativeDebug('show_remote_cursor', `sent ok=${response.ok} hasCursorEvent=${hasCursorEvent} message=${String(response.message ?? '')}`);
      }
    } catch (error) {
      this.remoteCursorOptionApplied = false;
      this.logRelativeDebug('show_remote_cursor', `failed=${String(error)}`);
    }
  }

  private setCursorOverlayLocalPoint(x: number, y: number): void {
    const space = this.getCoordinateSpace();
    if (!space) {
      return;
    }
    const minX = space.paintRect.left;
    const maxX = space.paintRect.left + space.paintRect.width;
    const minY = space.paintRect.top;
    const maxY = space.paintRect.top + space.paintRect.height;
    const cursorScale = this.getRemoteCursorScale();
    const marginX = Math.max(this.remoteCursorBitmapWidth * cursorScale, 24);
    const marginY = Math.max(this.remoteCursorBitmapHeight * cursorScale, 24);
    if (!this.relativeMouseMode && (x < minX - marginX || x > maxX + marginX || y < minY - marginY || y > maxY + marginY)) {
      this.remoteCursorVisible = false;
      return;
    }
    this.remoteCursorLeft = x;
    this.remoteCursorTop = y;
    this.remoteCursorVisible = true;
  }

  private showRemoteCursorOverlayFromLastPosition(): void {
    if (!this.lastRemoteCursorValid) {
      this.remoteCursorVisible = false;
      return;
    }
    const position = this.mapRemotePositionToLocalPoint(this.lastRemoteCursorX, this.lastRemoteCursorY);
    if (!position) {
      return;
    }
    this.setCursorOverlayLocalPoint(position.x, position.y);
    this.logRelativeDebug(
      'cursor_anchor',
      `source=lastRemote remote=(${this.lastRemoteCursorX},${this.lastRemoteCursorY}) local=(${position.x.toFixed(1)},${position.y.toFixed(1)}) ${this.remoteCursorDebugText()}`,
    );
  }

  private isPointInsidePreviewContent(x: number, y: number): boolean {
    const space = this.getCoordinateSpace();
    return !!space && isLocalPointInsidePaintRect(space, x, y);
  }

  private updateCursorOverlayFromRemote(remoteX: number, remoteY: number): void {
    this.lastRemoteCursorValid = true;
    this.remoteCursorOptionApplied = true;
    this.lastRemoteCursorX = remoteX;
    this.lastRemoteCursorY = remoteY;
    this.lastRemoteCursorAt = Date.now();
    const position = this.mapRemotePositionToLocalPoint(remoteX, remoteY);
    if (!position) {
      this.logRelativeDebug('cursor_position_no_space', `raw=(${remoteX},${remoteY}) mode=${this.relativeMouseMode ? 'relative' : 'absolute'}`);
      return;
    }
    this.remoteCursorEventLogCounter += 1;
    if (this.relativeMouseMode || this.remoteCursorEventLogCounter % ABSOLUTE_MOUSE_LOG_SAMPLE_EVERY === 0) {
      this.logRelativeDebug(
        'cursor_position',
        `raw=(${remoteX},${remoteY}) local=(${position.x.toFixed(1)},${position.y.toFixed(1)}) ${this.overlayCursorDebugText('overlayBefore')} mode=${this.relativeMouseMode ? 'relative' : 'absolute'}`,
      );
    }
    this.setCursorOverlayLocalPoint(position.x, position.y);
  }

  private applyRemoteCursorBitmap(id: string): boolean {
    const cursor = this.remoteCursorCache.get(id);
    if (!cursor) {
      this.remoteCursorPixelMap = undefined;
      this.remoteCursorBitmapWidth = 0;
      this.remoteCursorBitmapHeight = 0;
      this.remoteCursorHotX = 0;
      this.remoteCursorHotY = 0;
      return false;
    }
    this.remoteCursorPixelMap = cursor.pixelMap;
    this.remoteCursorBitmapWidth = cursor.width;
    this.remoteCursorBitmapHeight = cursor.height;
    this.remoteCursorHotX = cursor.hotX;
    this.remoteCursorHotY = cursor.hotY;
    this.showRemoteCursorOverlayFromLastPosition();
    return true;
  }

  private updateRemoteCursorId(event: NativeEvent): void {
    const id = String(event.id ?? '');
    if (id.length === 0) {
      return;
    }
    this.remoteCursorCurrentId = id;
    this.remoteCursorOptionApplied = true;
    const applied = this.applyRemoteCursorBitmap(id);
    this.logRelativeDebug('cursor_id', `id=${id} bitmap=${applied ? 'hit' : 'miss'} ${this.remoteCursorDebugText()}`);
  }

  private updateRemoteCursorData(event: NativeEvent): void {
    const id = String(event.id ?? '');
    const width = Number(event.width ?? '0');
    const height = Number(event.height ?? '0');
    const hotX = Number(event.hotx ?? '0');
    const hotY = Number(event.hoty ?? '0');
    if (id.length === 0 || width <= 0 || height <= 0 || !event.colors) {
      return;
    }
    let colors: number[] = [];
    try {
      colors = JSON.parse(event.colors) as number[];
    } catch (error) {
      this.logRelativeDebug('cursor_data', `parse_failed id=${id} error=${String(error)}`);
      return;
    }
    const expectedLength = width * height * 4;
    if (colors.length < expectedLength) {
      this.logRelativeDebug('cursor_data', `bad_length id=${id} got=${colors.length} expected=${expectedLength}`);
      return;
    }
    this.remoteCursorCurrentId = id;
    this.remoteCursorOptionApplied = true;
    const buffer = new ArrayBuffer(expectedLength);
    const rgba = new Uint8Array(buffer);
    for (let index = 0; index < expectedLength; index++) {
      rgba[index] = Number(colors[index]) & 0xFF;
    }
    const options: image.InitializationOptions = {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { width, height },
      alphaType: image.AlphaType.UNPREMUL,
    };
    image.createPixelMap(buffer, options)
      .then((pixelMap: image.PixelMap) => {
        const previous = this.remoteCursorCache.get(id);
        const cursor: RemoteCursorBitmap = {
          id,
          pixelMap,
          hotX,
          hotY,
          width,
          height,
        };
        this.remoteCursorCache.set(id, cursor);
        if (this.remoteCursorCurrentId === id) {
          this.applyRemoteCursorBitmap(id);
        }
        if (previous) {
          previous.pixelMap.release().catch((error: BusinessError) => {
            hilog.warn(DOMAIN, TAG, 'replace cursor pixelmap release failed: %{public}s', JSON.stringify(error) ?? '');
          });
        }
        this.logRelativeDebug('cursor_data', `id=${id} size=${width}x${height} hot=(${hotX},${hotY})`);
      })
      .catch((error: BusinessError) => {
        this.logRelativeDebug('cursor_data', `create_failed id=${id} error=${JSON.stringify(error) ?? String(error)}`);
      });
  }

  private moveRelativeCursorBy(deltaX: number, deltaY: number): void {
    const mappedDelta = this.mapLocalDeltaToRelativePointerDelta(deltaX, deltaY);
    const remoteDeltaX = mappedDelta.x * TOUCHPAD_MOVE_SENSITIVITY;
    const remoteDeltaY = mappedDelta.y * TOUCHPAD_MOVE_SENSITIVITY;
    if (Math.abs(remoteDeltaX) < 0.01 && Math.abs(remoteDeltaY) < 0.01) {
      return;
    }
    this.queueRelativeMouseMove(remoteDeltaX, remoteDeltaY);
  }

  private moveRemoteCursorToLocalPoint(localX: number, localY: number): boolean {
    if (!this.isPointInsidePreviewContent(localX, localY)) {
      return false;
    }
    const position = this.mapLocalPointToRemotePosition(localX, localY);
    if (!position) {
      return false;
    }
    this.absoluteMoveLogCounter += 1;
    if (this.absoluteMoveLogCounter % ABSOLUTE_MOUSE_LOG_SAMPLE_EVERY === 0) {
      const space = this.getCoordinateSpace();
      this.logRelativeDebug(
        'abs_move',
        space
          ? `local=(${localX.toFixed(1)},${localY.toFixed(1)}) paintRect=(${space.paintRect.left.toFixed(1)},${space.paintRect.top.toFixed(1)},${space.paintRect.width.toFixed(1)},${space.paintRect.height.toFixed(1)}) remoteRect=(${space.remoteRect.left.toFixed(0)},${space.remoteRect.top.toFixed(0)},${space.remoteRect.width.toFixed(0)},${space.remoteRect.height.toFixed(0)}) remote=(${position.x},${position.y}) ${this.remoteCursorDebugText()}`
          : `local=(${localX.toFixed(1)},${localY.toFixed(1)}) remote=(${position.x},${position.y}) ${this.remoteCursorDebugText()}`,
      );
    }
    const payload = new RustDeskMousePayload();
    payload.x = String(position.x);
    payload.y = String(position.y);
    this.sendMousePayload(payload);
    return true;
  }

  private moveRemoteCursorAndClick(localX: number, localY: number, button: string): void {
    if (!this.moveRemoteCursorToLocalPoint(localX, localY)) {
      return;
    }
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
        this.discardRelativeMouseMove();
        this.touchpadDragActive = true;
        this.sendRelativeMouseButton('left', true, false);
      } else {
        this.moveRemoteCursorAndClick(this.touchpadPrimaryDownX, this.touchpadPrimaryDownY, 'right');
      }
    }, TOUCHPAD_LONG_PRESS_MS);
  }

  private scheduleRelativeSingleTap(): void {
    this.cancelPendingTouchpadTap();
    this.touchpadPendingTapTimer = setTimeout(() => {
      this.touchpadPendingTapTimer = -1;
      this.discardRelativeMouseMove();
      this.logRelativeDebug('single_tap_fire', `${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
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
    event.stopPropagation();
    if (event.sourceTool === SourceTool.MOUSE
      || event.sourceTool === SourceTool.TOUCHPAD
      || event.sourceTool === SourceTool.JOYSTICK) {
      return;
    }
    const changedTouches = event.changedTouches;
    switch (event.type) {
      case TouchType.Down:
        for (let index = 0; index < changedTouches.length; index++) {
          const touch = changedTouches[index];
          if (this.touchpadPrimaryId === -1) {
            if (!this.relativeMouseMode && !this.isPointInsidePreviewContent(touch.x, touch.y)) {
              continue;
            }
            if (this.relativeMouseMode) {
              this.discardRelativeMouseMove();
            }
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
      if (this.touchpadTapMoved) {
        this.moveRemoteCursorToLocalPoint(primaryTouch.x, primaryTouch.y);
      }
      return;
    }

    const primaryTouch = this.findTouchById(event.touches, this.touchpadPrimaryId);
    if (!primaryTouch) {
      return;
    }
    const movedX = primaryTouch.x - this.touchpadPrimaryDownX;
    const movedY = primaryTouch.y - this.touchpadPrimaryDownY;
    const movedDistance = Math.sqrt(movedX * movedX + movedY * movedY);
    if (!this.touchpadTapMoved && !this.touchpadDragActive) {
      if (movedDistance > TOUCHPAD_TAP_MAX_DISTANCE) {
        this.touchpadTapMoved = true;
        this.cancelTouchpadLongPressTimer();
        this.logRelativeDebug(
          'touch_move_start',
          `distance=${movedDistance.toFixed(2)} threshold=${TOUCHPAD_TAP_MAX_DISTANCE} touch=(${primaryTouch.x.toFixed(1)},${primaryTouch.y.toFixed(1)}) ${this.remoteCursorDebugText()}`,
        );
      }
    }
    const deltaX = primaryTouch.x - this.touchpadPrimaryLastX;
    const deltaY = primaryTouch.y - this.touchpadPrimaryLastY;
    this.touchpadPrimaryLastX = primaryTouch.x;
    this.touchpadPrimaryLastY = primaryTouch.y;
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    this.relativeTouchMoveLogCounter += 1;
    if (this.relativeTouchMoveLogCounter % RELATIVE_TOUCH_LOG_SAMPLE_EVERY === 0) {
      const mappedDelta = this.mapLocalDeltaToRelativePointerDelta(deltaX, deltaY);
      const remoteDeltaX = mappedDelta.x * TOUCHPAD_MOVE_SENSITIVITY;
      const remoteDeltaY = mappedDelta.y * TOUCHPAD_MOVE_SENSITIVITY;
      this.logRelativeDebug(
        'touch_move',
        `tool=${String(event.sourceTool)} touch=(${primaryTouch.x.toFixed(1)},${primaryTouch.y.toFixed(1)}) rawVp=(${deltaX.toFixed(2)},${deltaY.toFixed(2)}) remoteDelta=(${remoteDeltaX.toFixed(2)},${remoteDeltaY.toFixed(2)}) ${this.overlayCursorDebugText('overlayBefore')} drag=${this.touchpadDragActive} ${this.remoteCursorDebugText()}`,
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
        `elapsed=${elapsed} moved=${this.touchpadTapMoved} longPress=${this.touchpadLongPressTriggered} drag=${this.touchpadDragActive} ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`,
      );
      if (this.relativeMouseMode && this.touchpadDragActive) {
        this.sendRelativeMouseButton('left', false);
        this.resetTouchpadState();
        return;
      }
      if (!this.touchpadTapMoved && !this.touchpadLongPressTriggered && elapsed <= TOUCHPAD_TAP_MAX_MS) {
        if (this.relativeMouseMode) {
          this.discardRelativeMouseMove();
          const isDoubleTap = this.touchpadLastTapAt > 0
            && Date.now() - this.touchpadLastTapAt <= TOUCHPAD_DOUBLE_TAP_MAX_MS;
          if (isDoubleTap) {
            this.cancelPendingTouchpadTap();
            this.touchpadLastTapAt = 0;
            this.discardRelativeMouseMove();
            this.logRelativeDebug('double_tap', `${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
            this.clickCurrentCursor('right');
          } else {
            this.touchpadLastTapAt = Date.now();
            this.touchpadLastTapX = this.remoteCursorLeft;
            this.touchpadLastTapY = this.remoteCursorTop;
            this.logRelativeDebug('single_tap_schedule', `${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
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
      if (this.relativeMouseMode) {
        this.discardRelativeMouseMove();
      }
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
    if (event.action === MouseAction.Move || event.action === MouseAction.Hover) {
      if (this.relativeMouseMode) {
        if (Date.now() < this.relativeMouseSuppressMoveUntil) {
          this.relativeMouseLastX = event.x;
          this.relativeMouseLastY = event.y;
          this.relativeMouseHasLast = true;
          this.discardRelativeMouseMove();
          return;
        }
        const rawDeltaX = event.rawDeltaX ?? 0;
        const rawDeltaY = event.rawDeltaY ?? 0;
        const fallbackDeltaX = this.relativeMouseHasLast ? event.x - this.relativeMouseLastX : 0;
        const fallbackDeltaY = this.relativeMouseHasLast ? event.y - this.relativeMouseLastY : 0;
        const hasRawDelta = rawDeltaX !== 0 || rawDeltaY !== 0;
        let remoteDeltaX = 0;
        let remoteDeltaY = 0;
        let source = 'none';

        if (hasRawDelta) {
          const mappedDelta = this.mapLocalDeltaToRelativePointerDelta(rawDeltaX, rawDeltaY);
          remoteDeltaX = mappedDelta.x * RELATIVE_MOUSE_RAW_SENSITIVITY;
          remoteDeltaY = mappedDelta.y * RELATIVE_MOUSE_RAW_SENSITIVITY;
          source = 'raw';
        } else if (this.relativeMouseHasLast) {
          const mappedDelta = this.mapLocalDeltaToRelativePointerDelta(fallbackDeltaX, fallbackDeltaY);
          remoteDeltaX = mappedDelta.x * RELATIVE_MOUSE_FALLBACK_SENSITIVITY;
          remoteDeltaY = mappedDelta.y * RELATIVE_MOUSE_FALLBACK_SENSITIVITY;
          source = 'fallback';
        }

        this.relativeMouseLastX = event.x;
        this.relativeMouseLastY = event.y;
        this.relativeMouseHasLast = true;
        if (remoteDeltaX === 0 && remoteDeltaY === 0) {
          return;
        }
        this.relativeMoveLogCounter += 1;
        if (this.relativeMoveLogCounter % RELATIVE_MOVE_LOG_SAMPLE_EVERY === 0) {
          this.logRelativeDebug(
            'move',
            `source=${source} event=(${event.x.toFixed(1)},${event.y.toFixed(1)}) raw=(${rawDeltaX.toFixed(2)},${rawDeltaY.toFixed(2)}) fallbackVp=(${fallbackDeltaX.toFixed(2)},${fallbackDeltaY.toFixed(2)}) remoteDelta=(${remoteDeltaX.toFixed(2)},${remoteDeltaY.toFixed(2)}) pending=(${this.relativeMousePendingX.toFixed(2)},${this.relativeMousePendingY.toFixed(2)}) ${this.overlayCursorDebugText('overlayBefore')} ${this.remoteCursorDebugText()}`,
          );
        }
        this.queueRelativeMouseMove(remoteDeltaX, remoteDeltaY);
        return;
      }
      this.relativeMouseHasLast = false;
      if (!this.isPointInsidePreviewContent(event.x, event.y)) {
        return;
      }
      const position = this.mapLocalPointToRemotePosition(event.x, event.y);
      if (!position) {
        return;
      }
      this.absoluteMoveLogCounter += 1;
      if (this.absoluteMoveLogCounter % ABSOLUTE_MOUSE_LOG_SAMPLE_EVERY === 0) {
        const space = this.getCoordinateSpace();
        this.logRelativeDebug(
          'abs_move',
          space
            ? `local=(${event.x.toFixed(1)},${event.y.toFixed(1)}) paintRect=(${space.paintRect.left.toFixed(1)},${space.paintRect.top.toFixed(1)},${space.paintRect.width.toFixed(1)},${space.paintRect.height.toFixed(1)}) remoteRect=(${space.remoteRect.left.toFixed(0)},${space.remoteRect.top.toFixed(0)},${space.remoteRect.width.toFixed(0)},${space.remoteRect.height.toFixed(0)}) remote=(${position.x},${position.y}) ${this.remoteCursorDebugText()}`
            : `local=(${event.x.toFixed(1)},${event.y.toFixed(1)}) remote=(${position.x},${position.y}) ${this.remoteCursorDebugText()}`,
        );
      }
      const payload = new RustDeskMousePayload();
      payload.x = String(position.x);
      payload.y = String(position.y);
      this.sendMousePayload(payload);
      return;
    }
    if (event.action !== MouseAction.Press && event.action !== MouseAction.Release) {
      return;
    }
    const button = mapMouseButton(event.button);
    if (!button) {
      return;
    }
    const isPress = event.action === MouseAction.Press;
    const insidePreviewContent = this.isPointInsidePreviewContent(event.x, event.y);
    if (this.relativeMouseMode) {
      if (isPress && !insidePreviewContent) {
        return;
      }
      if (!isPress && !this.mouseButtonsDown.has(button) && !insidePreviewContent) {
        return;
      }
      this.rebaseRelativeMouseAtLocalPoint(event.x, event.y, false);
      this.logRelativeDebug('click', `type=${isPress ? 'down' : 'up'} button=${button} ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
      if (isPress) {
        this.discardRelativeMouseMove();
        this.mouseButtonsDown.add(button);
      } else {
        this.flushRelativeMouseMove();
      }
      this.relativeMouseSuppressMoveUntil = Date.now() + RELATIVE_MOUSE_BUTTON_SUPPRESS_MS;
      this.sendRelativeMouseButton(button, isPress, false);
      if (!isPress) {
        this.mouseButtonsDown.delete(button);
      }
      return;
    }
    if (isPress && !insidePreviewContent) {
      return;
    }
    if (insidePreviewContent) {
      this.moveRemoteCursorToLocalPoint(event.x, event.y);
    }
    if (isPress) {
      this.mouseButtonsDown.add(button);
    } else if (!this.mouseButtonsDown.has(button) && !insidePreviewContent) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = isPress ? 'down' : 'up';
    payload.buttons = button;
    this.sendMousePayload(payload);
    if (!isPress) {
      this.mouseButtonsDown.delete(button);
    }
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

  private shortRemoteStatusText(): string {
    return `fps ${this.remoteFpsText} | delay ${this.remoteDelayText} | codec ${this.remoteCodecText} | ${this.relativeMouseMode ? 'relative' : 'absolute'}`;
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

  private selectPreferredCodec(capabilities: DecoderCapability[]): string {
    const h264 = capabilities.find((item: DecoderCapability) => item.codec === 'H264');
    if (h264 && (h264.recommendedAvailable || h264.hardwareAvailable || h264.softwareAvailable)) {
      return 'h264';
    }
    const h265 = capabilities.find((item: DecoderCapability) => item.codec === 'H265');
    if (h265 && (h265.recommendedAvailable || h265.hardwareAvailable || h265.softwareAvailable)) {
      return 'h265';
    }
    return 'auto';
  }

  private configureDisplayFromPeerInfo(event: NativeEvent): void {
    if (event.platform && event.platform.length > 0) {
      this.peerPlatform = String(event.platform);
    }
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
      this.ensureRemoteCursorEnabled();
      hilog.info(
        DOMAIN,
        TAG,
        'Display setup peer platform=%{public}s current=%{public}d displays=%{public}s resolutions=%{public}s',
        this.peerPlatform,
        this.currentDisplay,
        JSON.stringify(this.peerDisplays),
        JSON.stringify(this.supportedResolutions),
      );
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
    const rawRect = this.getRawDisplayRect(primaryDisplay);
    const displayScale = this.getDisplayScaleFactor(primaryDisplay);
    const renderWidth = Math.max(Math.round(rawRect.width), 1);
    const renderHeight = Math.max(Math.round(rawRect.height), 1);
    this.updateSessionState(this.parseResponse(native.sessionSwitchDisplay(this.activeSessionId, JSON.stringify([currentDisplay]))));
    this.updateSessionState(this.parseResponse(native.sessionSetSize(
      this.activeSessionId,
      currentDisplay,
      renderWidth,
      renderHeight
    )));
    hilog.info(
      DOMAIN,
      TAG,
      'Display config peer platform=%{public}s display=%{public}d raw=%{public}dx%{public}d rawRect=(%{public}s,%{public}s,%{public}s,%{public}s) scale=%{public}s original=%{public}s scaled=%{public}s',
      this.peerPlatform,
      currentDisplay,
      primaryDisplay.width,
      primaryDisplay.height,
      rawRect.left.toFixed(0),
      rawRect.top.toFixed(0),
      rawRect.width.toFixed(0),
      rawRect.height.toFixed(0),
      displayScale.toFixed(2),
      primaryDisplay.original_width && primaryDisplay.original_height
        ? `${primaryDisplay.original_width}x${primaryDisplay.original_height}`
        : 'none',
      primaryDisplay.scaled_width && primaryDisplay.scaled_height
        ? `${primaryDisplay.scaled_width}x${primaryDisplay.scaled_height}`
        : 'none',
    );
    this.frameStatus = `Remote raw ${renderWidth}x${renderHeight}`;
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
      this.applyCodecPreference(false);
      this.updateSessionState(this.parseResponse(native.sessionSetImageQuality(this.activeSessionId, 'low')));
      this.updateSessionState(this.parseResponse(native.sessionSetCustomFps(this.activeSessionId, 90)));
      this.performanceTuningApplied = true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'applyPerformanceTuning failed: %{public}s', String(error));
    }
  }

  private applyCodecPreference(force: boolean): void {
    if (!this.activeSessionId || this.preferredCodec === 'auto') {
      return;
    }
    const now = Date.now();
    if (!force && this.codecPreferenceApplied) {
      return;
    }
    if (force && this.lastCodecPreferenceAppliedAt > 0 && now - this.lastCodecPreferenceAppliedAt < PREFERRED_CODEC_REAPPLY_MS) {
      return;
    }
    try {
      const response = this.parseResponse(native.sessionSetCodecPreference(this.activeSessionId, this.preferredCodec));
      this.codecPreferenceApplied = response.ok;
      this.lastCodecPreferenceAppliedAt = now;
      if (!response.ok && response.message) {
        this.logRelativeDebug('codec_preference', response.message);
      }
    } catch (error) {
      this.logRelativeDebug('codec_preference', `failed=${String(error)}`);
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
          this.ensureRemoteCursorEnabled();
          this.applyCodecPreference(true);
          this.performanceTuningApplied = false;
        }
        if (event.name === 'peer_info') {
          if (event.platform && event.platform.length > 0) {
            this.peerPlatform = String(event.platform);
          }
          this.connectionSummary = `peer=${String(event.hostname)}, platform=${String(event.platform)}, version=${String(event.version)}`;
          this.applyPerformanceTuning();
          this.ensureRemoteCursorEnabled();
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
            if (this.remoteCodecText.toLowerCase().includes('vp9') && this.preferredCodec !== 'auto') {
              this.applyCodecPreference(true);
            }
          }
          this.refreshQualitySummary();
        }
        if (event.name === 'cursor_data') {
          this.updateRemoteCursorData(event);
        }
        if (event.name === 'cursor_id') {
          this.updateRemoteCursorId(event);
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
      this.ensureRemoteCursorEnabled();
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
            type: XComponentType.TEXTURE,
            controller: this.previewController
          })
            .width(this.getPreviewRenderSize().width)
            .height(this.getPreviewRenderSize().height)
            .backgroundColor('#000000')
            .zIndex(0);
        } else {
          Text('Preparing preview...')
            .fontSize(14)
            .fontColor('#FFFFFF');
        }

        Column() {
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Block)
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
          const width = Number(newArea.width);
          const height = Number(newArea.height);
          if (width > 0) {
            this.previewViewWidth = width;
          }
          if (height > 0) {
            this.previewViewHeight = height;
          }
          this.showRemoteCursorOverlayFromLastPosition();
        })
        .zIndex(10);

        if (this.shouldDrawRemoteCursorOverlay() && this.remoteCursorPixelMap) {
          Image(this.remoteCursorPixelMap)
            .width(this.remoteCursorBitmapWidth * this.getRemoteCursorScale())
            .height(this.remoteCursorBitmapHeight * this.getRemoteCursorScale())
            .objectFit(ImageFit.Fill)
            .position({
              x: this.remoteCursorLeft - this.remoteCursorHotX * this.getRemoteCursorScale(),
              y: this.remoteCursorTop - this.remoteCursorHotY * this.getRemoteCursorScale()
            })
            .hitTestBehavior(HitTestMode.None)
            .zIndex(20);
        } else if (this.shouldDrawRemoteCursorOverlay()) {
          Path()
            .width(18)
            .height(24)
            .commands('M1 1 L1 20 L6 15 L9 23 L12 22 L9 14 L16 14 Z')
            .fill('#FFFFFF')
            .stroke('#111111')
            .strokeWidth(1.4)
            .opacity(1)
            .position({ x: this.remoteCursorLeft - 1, y: this.remoteCursorTop - 1 })
            .hitTestBehavior(HitTestMode.None)
            .zIndex(20);
        }
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#000000');

      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Circle()
            .width(7)
            .height(7)
            .fill(this.relativeMouseMode ? '#2F6BFF' : '#2DD17A');

          Text(this.renderFpsText)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Text(this.shortRemoteStatusText())
          .fontSize(11)
          .fontColor('#D7DDE7')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');

        Text(this.frameStatus)
          .fontSize(11)
          .fontColor('#B9C1CF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
        .width(320)
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor('#C0111724')
        .borderRadius(8)
        .border({ width: 1, color: '#33FFFFFF' })
        .hitTestBehavior(HitTestMode.None)
        .position({ x: 16, y: 16 })
        .zIndex(30);

      Row() {
        Row({ space: 8 }) {
          Button(this.relativeMouseMode ? '相对模式' : '绝对模式')
            .height(34)
            .width(92)
            .backgroundColor(this.relativeMouseMode ? '#2F6BFF' : '#263246')
            .fontColor('#FFFFFF')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .borderRadius(8)
            .onClick(() => this.toggleRelativeMouseMode());

          Button('断开')
            .height(34)
            .width(74)
            .backgroundColor('#FFF0EE')
            .fontColor('#C7372F')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .borderRadius(8)
            .onClick(() => this.closeSession('已手动断开连接'));
        }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor('#C0111724')
        .borderRadius(8)
        .border({ width: 1, color: '#33FFFFFF' });
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ top: 20, right: 20, left: 20 })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(30);
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
              qualitySummary: this.qualitySummary,
              frameStatus: this.frameStatus,
              renderFpsText: this.renderFpsText,
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
            mainTitle: this.currentTabIndex === 0 ? 'RustDesk HMOS' : 'Native Bridge',
            subTitle: this.currentTabIndex === 0 ? '远控工作台' : '桥接与解码状态'
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
