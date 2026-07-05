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
import { RustDeskInputController } from './rustdesk/RustDeskInputController';
import { RustDeskCursorModel } from './rustdesk/RustDeskCursorModel';
import {
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskSize,
} from './rustdesk/RustDeskInputMapper';
import { RustDeskViewportModel } from './rustdesk/RustDeskViewportModel';
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

const REMOTE_CURSOR_LOG_SAMPLE_EVERY = 10;
const REMOTE_CURSOR_MIN_VISIBLE_SIZE = 12;
const FALLBACK_CURSOR_BASE_WIDTH = 18;
const FALLBACK_CURSOR_BASE_HEIGHT = 24;
const PREFERRED_CODEC_REAPPLY_MS = 5000;
const REMOTE_CURSOR_OPTION_REAPPLY_MS = 1000;
const RENDER_STALL_THRESHOLD_MS = 3500;
const RENDER_STALL_RECOVERY_COOLDOWN_MS = 5000;
const RENDER_STALL_RECONNECT_AFTER_RECOVERIES = 2;
const PREVIEW_ROOT_FOCUS_ID = 'rustdesk-preview-root-layer';
const PREVIEW_INPUT_FOCUS_ID = 'rustdesk-preview-input-layer';

@Entry
@Component
struct RustDeskIndex {
  private previewController: RustDeskSurfaceController = new RustDeskSurfaceController();
  private viewportModel: RustDeskViewportModel = new RustDeskViewportModel();
  private cursorModel: RustDeskCursorModel = new RustDeskCursorModel();
  private inputController?: RustDeskInputController;
  private preferences?: RustDeskPreferences;
  private passwordDialogController?: CustomDialogController;
  private connectScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private keyboardEnteredSessionId: string = '';
  private lastKeyboardFocusLogAt: number = 0;

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
  private lastRenderTotalFrames: number = 0;
  private renderStallFirstDetectedAt: number = 0;
  private lastRenderRecoveryAt: number = 0;
  private renderStallRecoveryAttempts: number = 0;
  private previewSurfaceId: string = '';
  private currentDisplay: number = 0;
  private lastAppliedDisplay: number = -1;
  private lastAppliedVideoWidth: number = 0;
  private lastAppliedVideoHeight: number = 0;
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
  private sessionFullscreenApplied: boolean = false;
  private remoteCursorEventLogCounter: number = 0;
  private relativeModeActivatedAt: number = 0;
  private remoteCursorOptionApplied: boolean = false;
  private remoteCursorOptionLastAppliedAt: number = 0;
  private remoteCursorOptionFirstAppliedAt: number = 0;
  private remoteCursorEnableAttempts: number = 0;
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
    this.setSessionKeyboardEntered(false);
    this.clearSurfaceBinding();
    this.stopPolling();
    this.applySessionFullscreen(false);
  }

  private getInputController(): RustDeskInputController {
    if (!this.inputController) {
      this.inputController = new RustDeskInputController({
        isSessionActive: () => this.activeSessionId.length > 0,
        isRelativeMode: () => this.relativeMouseMode,
        isPeerMacOS: () => this.isPeerMacOS(),
        getCoordinateSpace: () => this.getCoordinateSpace(),
        sendMouse: (payload: RustDeskMousePayload) => this.sendMousePayload(payload),
        sendFlutterKey: (payload: RustDeskFlutterKeyPayload) => this.sendFlutterKeyPayloadObject(payload),
        sendKey: (payload: RustDeskKeyPayload) => this.sendKeyPayloadObject(payload),
        log: (label: string, payload: string) => this.logRelativeDebug(label, payload),
        remoteCursorDebugText: () => this.remoteCursorDebugText(),
        overlayCursorDebugText: (label: string) => this.overlayCursorDebugText(label),
        onVirtualCursorMoved: (remoteX: number, remoteY: number) => this.updateOverlayFromVirtualCursor(remoteX, remoteY),
      });
    }
    return this.inputController;
  }

  private isPeerMacOS(): boolean {
    const normalized = this.peerPlatform.toLowerCase().replace(/[\s_-]/g, '');
    return normalized === 'macos' || normalized === 'macosx' || normalized === 'darwin' || normalized === 'mac';
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
    this.setSessionKeyboardEntered(false);
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
    this.viewportModel.reset();
    this.inputController?.reset();
    this.keyboardEnteredSessionId = '';
    this.frameStatus = 'Surface not ready';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.previewViewWidth = 0;
    this.previewViewHeight = 0;
    this.currentDisplay = 0;
    this.lastAppliedDisplay = -1;
    this.lastAppliedVideoWidth = 0;
    this.lastAppliedVideoHeight = 0;
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
    this.lastRenderTotalFrames = 0;
    this.renderStallFirstDetectedAt = 0;
    this.lastRenderRecoveryAt = 0;
    this.renderStallRecoveryAttempts = 0;
    this.relativeMouseMode = false;
    this.resetRemoteCursorVisualState();
    this.cursorModel.reset();
    this.remoteCursorOptionApplied = false;
    this.remoteCursorOptionLastAppliedAt = 0;
    this.remoteCursorOptionFirstAppliedAt = 0;
    this.remoteCursorEnableAttempts = 0;
    this.relativeModeActivatedAt = 0;
    this.remoteCursorEventLogCounter = 0;
    this.refreshQualitySummary();
  }

  private syncRelativeMouseMode(active: boolean): void {
    this.getInputController().setRelativeMode(active);
    if (active) {
      this.relativeModeActivatedAt = Date.now();
      this.ensureRelativeCursorOverlay();
      return;
    }
    this.relativeModeActivatedAt = 0;
    this.remoteCursorVisible = false;
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
        this.setSessionKeyboardEntered(true);
        this.requestPreviewInputFocus();
        setTimeout(() => this.requestPreviewInputFocus(), 120);
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

  private async toggleRelativeMouseMode(): Promise<void> {
    const nextMode = !this.relativeMouseMode;
    this.relativeMouseMode = nextMode;
    this.syncRelativeMouseMode(nextMode);
    this.sessionMessage = `已切换到${this.getPointerModeName(nextMode)}`;
  }

  private getPointerModeName(relativeMode: boolean = this.relativeMouseMode): string {
    return relativeMode ? '触摸板' : '模拟鼠标';
  }

  private getCoordinateSpace(): RustDeskCoordinateSpace | undefined {
    return this.viewportModel.getCoordinateSpace();
  }

  private normalizeCursorRotation(rotation: number): number {
    const normalized = rotation % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  private getRemoteCursorScaleX(): number {
    const space = this.getCoordinateSpace();
    if (!space) {
      return 1;
    }
    const rotation = this.normalizeCursorRotation(space.rotation);
    if (rotation === 90 || rotation === 270) {
      return space.paintRect.height / Math.max(space.remoteRect.width, 1);
    }
    return space.paintRect.width / Math.max(space.remoteRect.width, 1);
  }

  private getRemoteCursorScaleY(): number {
    const space = this.getCoordinateSpace();
    if (!space) {
      return 1;
    }
    const rotation = this.normalizeCursorRotation(space.rotation);
    if (rotation === 90 || rotation === 270) {
      return space.paintRect.width / Math.max(space.remoteRect.height, 1);
    }
    return space.paintRect.height / Math.max(space.remoteRect.height, 1);
  }

  private getRemoteCursorBaseScale(): number {
    const scaleX = this.getRemoteCursorScaleX();
    const scaleY = this.getRemoteCursorScaleY();
    return Math.max(Math.min(scaleX, scaleY), 0.0001);
  }

  private getRemoteCursorVisualScale(): number {
    const maxBitmapSide = Math.max(this.remoteCursorBitmapWidth, this.remoteCursorBitmapHeight, 1);
    const minScale = REMOTE_CURSOR_MIN_VISIBLE_SIZE / maxBitmapSide;
    return Math.max(this.getRemoteCursorBaseScale(), minScale);
  }

  private getFallbackCursorScale(): number {
    const minScale = REMOTE_CURSOR_MIN_VISIBLE_SIZE / FALLBACK_CURSOR_BASE_HEIGHT;
    return Math.max(this.getRemoteCursorBaseScale(), minScale);
  }

  private getFallbackCursorWidth(): number {
    return FALLBACK_CURSOR_BASE_WIDTH * this.getFallbackCursorScale();
  }

  private getFallbackCursorHeight(): number {
    return FALLBACK_CURSOR_BASE_HEIGHT * this.getFallbackCursorScale();
  }

  private getFallbackCursorCommands(): string {
    const scaleX = this.getFallbackCursorWidth() / FALLBACK_CURSOR_BASE_WIDTH;
    const scaleY = this.getFallbackCursorHeight() / FALLBACK_CURSOR_BASE_HEIGHT;
    return `M${1 * scaleX} ${1 * scaleY} L${1 * scaleX} ${20 * scaleY} L${6 * scaleX} ${15 * scaleY} L${9 * scaleX} ${23 * scaleY} L${12 * scaleX} ${22 * scaleY} L${9 * scaleX} ${14 * scaleY} L${16 * scaleX} ${14 * scaleY} Z`;
  }

  private shouldDrawRemoteCursorOverlay(): boolean {
    return this.relativeMouseMode && this.remoteCursorVisible;
  }

  private resetRemoteCursorVisualState(): void {
    this.remoteCursorPixelMap = undefined;
    this.remoteCursorBitmapWidth = 0;
    this.remoteCursorBitmapHeight = 0;
    this.remoteCursorHotX = 0;
    this.remoteCursorHotY = 0;
    this.remoteCursorVisible = false;
    this.remoteCursorLeft = 0;
    this.remoteCursorTop = 0;
  }

  private applyCursorSnapshotToVisualState(): void {
    const snapshot = this.cursorModel.getSnapshot();
    this.remoteCursorPixelMap = snapshot.pixelMap;
    this.remoteCursorBitmapWidth = snapshot.bitmapWidth;
    this.remoteCursorBitmapHeight = snapshot.bitmapHeight;
    this.remoteCursorHotX = snapshot.hotX;
    this.remoteCursorHotY = snapshot.hotY;
  }

  // Flutter-mobile: the local virtual cursor (in remote coords, driven by input)
  // is mapped to the local paint rect and becomes the overlay position. The cursor
  // image comes from the remote cursor_data bitmap; if none yet, a fallback arrow is drawn.
  private updateOverlayFromVirtualCursor(remoteX: number, remoteY: number): void {
    const position = this.viewportModel.mapRemoteToLocal(remoteX, remoteY);
    if (!position) {
      this.remoteCursorVisible = false;
      return;
    }
    this.applyCursorSnapshotToVisualState();
    this.remoteCursorLeft = position.x;
    this.remoteCursorTop = position.y;
    this.remoteCursorVisible = true;
  }

  // Re-map the virtual cursor (remote coords) to the local paint rect after a
  // viewport/rotation change so the overlay stays anchored to the same remote point.
  private reprojectVirtualCursorOverlay(): void {
    const controller = this.getInputController();
    if (controller.hasVirtualCursor()) {
      this.updateOverlayFromVirtualCursor(controller.getVirtualCursorX(), controller.getVirtualCursorY());
    }
  }

  private getPreviewRenderSize(): RustDeskSize {
    return this.viewportModel.getRenderSize();
  }

  private logRelativeDebug(label: string, payload: string): void {
    hilog.info(DOMAIN, TAG, 'RelMouse debug [%{public}s] %{public}s', label, payload);
  }

  private setSessionKeyboardEntered(enter: boolean): void {
    const sessionId = this.activeSessionId;
    if (enter) {
      if (!sessionId || this.keyboardEnteredSessionId === sessionId) {
        return;
      }
    } else if (!this.keyboardEnteredSessionId) {
      return;
    }
    const targetSessionId = enter ? sessionId : this.keyboardEnteredSessionId;
    try {
      const response = this.parseResponse(native.sessionEnterOrLeave(targetSessionId, enter));
      if (response.ok) {
        this.keyboardEnteredSessionId = enter ? targetSessionId : '';
      }
      this.logRelativeDebug('keyboard_enter', `enter=${enter} ok=${response.ok} session=${targetSessionId} message=${String(response.message ?? '')}`);
    } catch (error) {
      this.logRelativeDebug('keyboard_enter', `enter=${enter} session=${targetSessionId} failed=${String(error)}`);
    }
  }

  private remoteCursorDebugText(): string {
    return this.cursorModel.describe(this.relativeMouseMode, this.relativeModeActivatedAt);
  }

  private overlayCursorDebugText(label: string): string {
    if (!this.remoteCursorVisible) {
      return `${label}=none`;
    }
    return `${label}=actual(${this.remoteCursorLeft.toFixed(1)},${this.remoteCursorTop.toFixed(1)})`;
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

  private ensureRemoteCursorEnabled(force: boolean = false): void {
    if (!this.activeSessionId) {
      return;
    }
    const snapshot = this.cursorModel.getSnapshot();
    const hasCursorEvent = snapshot.hasRemotePosition;
    if (hasCursorEvent) {
      return;
    }
    if (!force && this.remoteCursorOptionApplied) {
      return;
    }
    const now = Date.now();
    if (!force && this.remoteCursorOptionLastAppliedAt > 0 && now - this.remoteCursorOptionLastAppliedAt < REMOTE_CURSOR_OPTION_REAPPLY_MS) {
      return;
    }
    if (this.remoteCursorOptionFirstAppliedAt === 0) {
      this.remoteCursorOptionFirstAppliedAt = now;
    }
    this.remoteCursorOptionLastAppliedAt = now;
    try {
      const response = this.parseResponse(native.sessionSetShowRemoteCursor(this.activeSessionId, true));
      this.remoteCursorOptionApplied = response.ok;
      this.remoteCursorEnableAttempts += 1;
      if (!response.ok && response.message) {
        this.logRelativeDebug('show_remote_cursor', response.message);
      } else {
        this.logRelativeDebug('show_remote_cursor', `sent ok=${response.ok} attempt=${this.remoteCursorEnableAttempts} hasCursorEvent=${hasCursorEvent} message=${String(response.message ?? '')}`);
      }
    } catch (error) {
      this.remoteCursorOptionApplied = false;
      this.logRelativeDebug('show_remote_cursor', `failed=${String(error)}`);
    }
  }

  private ensureRelativeCursorOverlay(): void {
    const controller = this.getInputController();
    let seedSource = controller.hasVirtualCursor() ? 'existing' : 'none';
    if (!controller.hasVirtualCursor()) {
      const snapshot = this.cursorModel.getSnapshot();
      if (snapshot.hasRemotePosition) {
        controller.syncVirtualCursorToRemote(snapshot.remoteX, snapshot.remoteY);
        seedSource = 'remote';
      }
    }
    if (!controller.hasVirtualCursor()) {
      controller.initVirtualCursorToCenter();
      seedSource = 'center';
    }
    this.reprojectVirtualCursorOverlay();
    this.ensureRemoteCursorEnabled(true);
    this.logRelativeDebug('cursor_anchor', `source=${seedSource} ${this.overlayCursorDebugText('overlay')} ${this.remoteCursorDebugText()}`);
  }

  private updateCursorOverlayFromRemote(remoteX: number, remoteY: number): void {
    const hadVirtualCursor = this.getInputController().hasVirtualCursor();
    this.cursorModel.updatePosition(remoteX, remoteY);
    this.remoteCursorOptionApplied = true;
    // Flutter-mobile: the local virtual cursor is the authority for the overlay.
    // A remote cursor_position only seeds it before any local input has moved it.
    this.getInputController().syncVirtualCursorToRemote(remoteX, remoteY);
    this.remoteCursorEventLogCounter += 1;
    if (this.remoteCursorEventLogCounter <= 20
      || this.remoteCursorEventLogCounter % REMOTE_CURSOR_LOG_SAMPLE_EVERY === 0) {
      this.logRelativeDebug(
        'cursor_position',
        `raw=(${remoteX},${remoteY}) seeded=${hadVirtualCursor ? 'no' : 'yes'} mode=${this.relativeMouseMode ? 'relative' : 'absolute'}`,
      );
    }
  }

  private applyRemoteCursorBitmap(id: string): boolean {
    const applied = this.cursorModel.updateCursorId(id);
    // Position/visibility is owned by the local virtual cursor; only refresh the image.
    this.applyCursorSnapshotToVisualState();
    return applied;
  }

  private updateRemoteCursorId(event: NativeEvent): void {
    const id = String(event.id ?? '');
    if (id.length === 0) {
      return;
    }
    this.remoteCursorOptionApplied = true;
    const applied = this.applyRemoteCursorBitmap(id);
    this.logRelativeDebug('cursor_id', `id=${id} bitmap=${applied ? 'hit' : 'miss'} ${this.remoteCursorDebugText()}`);
  }

  private updateRemoteCursorData(event: NativeEvent): void {
    this.remoteCursorOptionApplied = true;
    this.cursorModel.updateCursorData(
      event,
      (message: string) => this.logRelativeDebug('cursor_data', message),
      () => {
        this.applyCursorSnapshotToVisualState();
        this.reprojectVirtualCursorOverlay();
      },
    );
  }

  private handlePreviewTouchEvent(event: TouchEvent): void {
    this.requestPreviewInputFocus();
    this.getInputController().handleTouchEvent(event);
  }

  private sendKeyPayloadObject(payload: RustDeskKeyPayload): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionInputKey(this.activeSessionId, JSON.stringify(payload)));
      this.logRelativeDebug('keyboard_send_legacy', `ok=${response.ok} name=${payload.name} down=${payload.down} press=${payload.press}`);
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

  private sendFlutterKeyPayloadObject(payload: RustDeskFlutterKeyPayload): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionHandleFlutterKeyEvent(this.activeSessionId, JSON.stringify(payload)));
      this.logRelativeDebug('keyboard_send_flutter', `ok=${response.ok} usb=${payload.usb_hid} down=${payload.down_or_up} charLen=${payload.character.length}`);
      if (!response.ok) {
        this.errorText = response.message ?? 'Flutter keyboard input failed';
        return false;
      }
      return true;
    } catch (error) {
      this.errorText = `Flutter keyboard input failed: ${String(error)}`;
      hilog.error(DOMAIN, TAG, 'sendFlutterKeyPayloadObject failed: %{public}s', String(error));
      return false;
    }
  }

  private handlePreviewMouseEvent(event: MouseEvent): void {
    this.requestPreviewInputFocus();
    this.getInputController().handleMouseEvent(event);
  }

  private handlePreviewAxisEvent(event: AxisEvent): void {
    this.requestPreviewInputFocus();
    this.getInputController().handleAxisEvent(event);
  }

  private handlePreviewKeyEvent(event: KeyEvent): boolean {
    this.requestPreviewInputFocus();
    this.logRelativeDebug('keyboard_event', `keyCode=${event.keyCode} type=${String(event.type)} keyText=${String(event.keyText ?? '')} unicode=${String(event.unicode ?? '')}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private handlePreviewRootKeyEvent(event: KeyEvent): boolean {
    this.logRelativeDebug('keyboard_root_event', `keyCode=${event.keyCode} type=${String(event.type)} keyText=${String(event.keyText ?? '')} unicode=${String(event.unicode ?? '')}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private requestPreviewInputFocus(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(PREVIEW_INPUT_FOCUS_ID);
      this.getUIContext().getFocusController().requestFocus(PREVIEW_ROOT_FOCUS_ID);
      this.logKeyboardFocusRequest('requested');
    } catch (_error) {
      this.logKeyboardFocusRequest('request_failed');
    }
  }

  private logKeyboardFocusRequest(status: string): void {
    const now = Date.now();
    if (now - this.lastKeyboardFocusLogAt < 1000) {
      return;
    }
    this.lastKeyboardFocusLogAt = now;
    this.logRelativeDebug('keyboard_focus', `${status} id=${PREVIEW_INPUT_FOCUS_ID}`);
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
    const now = Date.now();
    try {
      const response = this.parseResponse(native.sessionGetRenderStats(this.activeSessionId, 0));
      const snapshot = response.stats?.stats;
      if (!snapshot || !snapshot.hasRenderedFrame) {
        this.renderFpsText = 'FPS --';
        this.handleRenderStall(now, 0, 0, false);
        return;
      }
      this.renderFpsText = `FPS ${snapshot.fps.toFixed(1)} | Frames ${snapshot.totalFrames}`;
      const totalFrames = Number(snapshot.totalFrames);
      const lastFrameAgeMs = Number(snapshot.lastFrameAgeMs);
      if (this.lastRenderTotalFrames === 0 || totalFrames > this.lastRenderTotalFrames) {
        this.lastRenderTotalFrames = totalFrames;
        this.renderStallFirstDetectedAt = 0;
        this.renderStallRecoveryAttempts = 0;
        return;
      }
      this.handleRenderStall(now, totalFrames, lastFrameAgeMs, true);
    } catch (_) {
    }
  }

  private handleRenderStall(now: number, totalFrames: number, lastFrameAgeMs: number, hasRenderedFrame: boolean): void {
    if (!this.activeSessionId || !this.previewSurfaceVisible || this.previewSurfaceId.length === 0) {
      this.renderStallFirstDetectedAt = 0;
      return;
    }
    const staleByAge = hasRenderedFrame && lastFrameAgeMs >= RENDER_STALL_THRESHOLD_MS;
    const staleByCounter = hasRenderedFrame && totalFrames > 0 && totalFrames === this.lastRenderTotalFrames;
    const hasNoFrame = !hasRenderedFrame && this.lastAppliedVideoWidth > 0 && this.lastAppliedVideoHeight > 0;
    if (!staleByAge && !staleByCounter && !hasNoFrame) {
      this.renderStallFirstDetectedAt = 0;
      return;
    }
    if (this.renderStallFirstDetectedAt === 0) {
      this.renderStallFirstDetectedAt = now;
      return;
    }
    if (now - this.renderStallFirstDetectedAt < RENDER_STALL_THRESHOLD_MS
      || now - this.lastRenderRecoveryAt < RENDER_STALL_RECOVERY_COOLDOWN_MS) {
      return;
    }
    this.lastRenderRecoveryAt = now;
    this.renderStallRecoveryAttempts += 1;
    this.logRelativeDebug(
      'render_stall',
      `frames=${totalFrames} lastAge=${lastFrameAgeMs} hasFrame=${hasRenderedFrame} recoveries=${this.renderStallRecoveryAttempts} display=${this.viewportModel.getCurrentDisplayIndex()} surface=${this.previewSurfaceId}`,
    );
    if (this.renderStallRecoveryAttempts >= RENDER_STALL_RECONNECT_AFTER_RECOVERIES) {
      this.reconnectAfterRenderStall(totalFrames, lastFrameAgeMs);
      return;
    }
    this.syncSurfaceBinding();
  }

  private reconnectAfterRenderStall(totalFrames: number, lastFrameAgeMs: number): void {
    if (!this.activeSessionId) {
      return;
    }
    this.renderStallRecoveryAttempts = 0;
    this.renderStallFirstDetectedAt = 0;
    this.lastRenderTotalFrames = 0;
    this.remoteCursorOptionApplied = false;
    this.remoteCursorOptionLastAppliedAt = 0;
    this.remoteCursorEnableAttempts = 0;
    try {
      const response = this.parseResponse(native.sessionReconnect(this.activeSessionId, false));
      this.updateSessionState(response);
      this.logRelativeDebug(
        'render_stall_reconnect',
        `ok=${response.ok} frames=${totalFrames} lastAge=${lastFrameAgeMs} message=${String(response.message ?? '')}`,
      );
      this.requestVideoRefresh();
      this.ensureRemoteCursorEnabled(true);
    } catch (error) {
      this.logRelativeDebug('render_stall_reconnect', `failed=${String(error)}`);
    }
  }

  private refreshQualitySummary(): void {
    this.qualitySummary = `Remote fps ${this.remoteFpsText} | delay ${this.remoteDelayText} | codec ${this.remoteCodecText}`;
  }

  private shortRemoteStatusText(): string {
    return `fps ${this.remoteFpsText} | delay ${this.remoteDelayText} | codec ${this.remoteCodecText} | ${this.getPointerModeName()}`;
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
      this.viewportModel.setPeerDisplays(this.peerDisplays, this.currentDisplay);
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
    const plan = this.viewportModel.buildRenderPlan();
    if (!plan) {
      this.frameStatus = 'Display geometry not ready';
      return;
    }
    const currentDisplay = plan.display;
    const primaryDisplay = this.peerDisplays[currentDisplay];
    const rawRect = plan.remoteRect;
    const videoWidth = Math.max(Math.round(plan.videoSize.width), 1);
    const videoHeight = Math.max(Math.round(plan.videoSize.height), 1);
    const surfaceWidth = Math.max(Math.round(plan.surfaceSize.width > 0 ? plan.surfaceSize.width : plan.renderSize.width), 1);
    const surfaceHeight = Math.max(Math.round(plan.surfaceSize.height > 0 ? plan.surfaceSize.height : plan.renderSize.height), 1);
    if (this.lastAppliedDisplay === currentDisplay
      && this.lastAppliedVideoWidth === videoWidth
      && this.lastAppliedVideoHeight === videoHeight) {
      this.frameStatus = `Remote ${videoWidth}x${videoHeight} -> surface ${surfaceWidth}x${surfaceHeight}`;
      return;
    }
    this.updateSessionState(this.parseResponse(native.sessionSwitchDisplay(this.activeSessionId, JSON.stringify([currentDisplay]))));
    this.updateSessionState(this.parseResponse(native.sessionSetSize(
      this.activeSessionId,
      currentDisplay,
      videoWidth,
      videoHeight
    )));
    this.lastAppliedDisplay = currentDisplay;
    this.lastAppliedVideoWidth = videoWidth;
    this.lastAppliedVideoHeight = videoHeight;
    hilog.info(
      DOMAIN,
      TAG,
      'Display config peer platform=%{public}s display=%{public}d raw=%{public}dx%{public}d video=%{public}dx%{public}d surface=%{public}dx%{public}d rawRect=(%{public}s,%{public}s,%{public}s,%{public}s) scale=%{public}s original=%{public}s scaled=%{public}s',
      this.peerPlatform,
      currentDisplay,
      primaryDisplay.width,
      primaryDisplay.height,
      videoWidth,
      videoHeight,
      surfaceWidth,
      surfaceHeight,
      rawRect.left.toFixed(0),
      rawRect.top.toFixed(0),
      rawRect.width.toFixed(0),
      rawRect.height.toFixed(0),
      plan.scale.toFixed(2),
      primaryDisplay.original_width && primaryDisplay.original_height
        ? `${primaryDisplay.original_width}x${primaryDisplay.original_height}`
        : 'none',
      primaryDisplay.scaled_width && primaryDisplay.scaled_height
        ? `${primaryDisplay.scaled_width}x${primaryDisplay.scaled_height}`
        : 'none',
    );
    this.frameStatus = `Remote ${videoWidth}x${videoHeight} -> surface ${surfaceWidth}x${surfaceHeight}`;
    this.requestVideoRefresh();
    // Show the local virtual cursor at the display center as soon as geometry is ready.
    if (!this.getInputController().hasVirtualCursor()) {
      this.getInputController().initVirtualCursorToCenter();
    }
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
      this.viewportModel.setSurfaceSize(rect.surfaceWidth, rect.surfaceHeight);
      this.frameStatus = `Surface ready ${rect.surfaceWidth}x${rect.surfaceHeight}`;
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
      this.requestVideoRefresh();
    }, 0);
  }

  private handlePreviewSurfaceDestroyed(): void {
    setTimeout(() => {
      this.clearSurfaceBinding();
      this.previewSurfaceId = '';
      this.frameWidth = 0;
      this.frameHeight = 0;
      this.viewportModel.setSurfaceSize(0, 0);
      this.frameStatus = 'Surface destroyed';
    }, 0);
  }

  private syncSurfaceBinding(): void {
    if (!this.activeSessionId || this.previewSurfaceId.length === 0) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionBindSurface(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
        this.previewSurfaceId
      )));
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
      this.updateSessionState(this.parseResponse(native.sessionBindSurface(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
        ''
      )));
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

  private pollSessionEventsOnce(limit: number): NativeEvent[] {
    if (!this.activeSessionId) {
      return [];
    }
    const response = this.parseResponse(native.sessionPollEvents(this.activeSessionId, limit));
    this.updateSessionState(response);
    const events = (response.events ?? []) as NativeEvent[];
    this.logCursorEventBatch(events, 'poll_once');
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
          this.connectionSummary = 'Password verification required';
          this.errorText = message;
          this.openPasswordDialog();
          return;
        }
        this.handleRemoteDisconnect(message);
      }
    });
    return events;
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
      this.logCursorEventBatch(events, 'poll');
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

  private logCursorEventBatch(events: NativeEvent[], source: string): void {
    let dataCount = 0;
    let idCount = 0;
    let positionCount = 0;
    events.forEach((event: NativeEvent) => {
      if (event.name === 'cursor_data') {
        dataCount += 1;
      } else if (event.name === 'cursor_id') {
        idCount += 1;
      } else if (event.name === 'cursor_position') {
        positionCount += 1;
      }
    });
    if (dataCount === 0 && idCount === 0 && positionCount === 0) {
      return;
    }
    this.logRelativeDebug(
      'cursor_events',
      `source=${source} data=${dataCount} id=${idCount} position=${positionCount} total=${events.length}`,
    );
  }

  private requestVideoRefresh(): void {
    if (!this.activeSessionId) {
      return;
    }
    try {
      this.updateSessionState(this.parseResponse(native.sessionRefresh(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex()
      )));
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
        .id(PREVIEW_INPUT_FOCUS_ID)
        .width('100%')
        .height('100%')
        .backgroundColor('#00000000')
        .hitTestBehavior(HitTestMode.Block)
        .focusable(true)
        .defaultFocus(true)
        .focusOnTouch(true)
        .onFocus(() => {
          this.logRelativeDebug('keyboard_focus', `focused id=${PREVIEW_INPUT_FOCUS_ID}`);
        })
        .onBlur(() => {
          this.logRelativeDebug('keyboard_focus', `blurred id=${PREVIEW_INPUT_FOCUS_ID}`);
        })
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
          this.viewportModel.setViewportSize(width, height);
          this.applyDisplayConfiguration();
          this.reprojectVirtualCursorOverlay();
        })
        .zIndex(10);

        if (this.shouldDrawRemoteCursorOverlay() && this.remoteCursorPixelMap) {
          Image(this.remoteCursorPixelMap)
            .width(this.remoteCursorBitmapWidth * this.getRemoteCursorVisualScale())
            .height(this.remoteCursorBitmapHeight * this.getRemoteCursorVisualScale())
            .objectFit(ImageFit.Fill)
            .position({
              x: this.remoteCursorLeft - this.remoteCursorHotX * this.getRemoteCursorVisualScale(),
              y: this.remoteCursorTop - this.remoteCursorHotY * this.getRemoteCursorVisualScale()
            })
            .hitTestBehavior(HitTestMode.None)
            .zIndex(20);
        } else if (this.shouldDrawRemoteCursorOverlay()) {
          Path()
            .width(this.getFallbackCursorWidth())
            .height(this.getFallbackCursorHeight())
            .commands(this.getFallbackCursorCommands())
            .fill('#FFFFFF')
            .stroke('#111111')
            .strokeWidth(1.4)
            .opacity(1)
            .position({
              x: this.remoteCursorLeft - this.getFallbackCursorWidth() / 2,
              y: this.remoteCursorTop - this.getFallbackCursorHeight() / 2
            })
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
          Button(this.getPointerModeName())
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
    .id(PREVIEW_ROOT_FOCUS_ID)
    .width('100%')
    .height('100%')
    .focusable(true)
    .defaultFocus(true)
    .focusOnTouch(true)
    .onFocus(() => {
      this.logRelativeDebug('keyboard_focus', `focused id=${PREVIEW_ROOT_FOCUS_ID}`);
    })
    .onBlur(() => {
      this.logRelativeDebug('keyboard_focus', `blurred id=${PREVIEW_ROOT_FOCUS_ID}`);
    })
    .onKeyEvent((event: KeyEvent) => this.handlePreviewRootKeyEvent(event));
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
