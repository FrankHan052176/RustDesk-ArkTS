import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  IconStyleMode,
  ScrollEffectType,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { rustDeskNativeApi as native } from './rustdesk/RustDeskNativeApi';
import { common, OpenLinkOptions } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError, Callback, deviceInfo } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  LuminousNeoTokens,
  LuminousSurface,
} from 'luminous_neo';
import { ConnectTab } from './rustdesk/components/ConnectTab';
import { DeviceDirectoryPanel } from './rustdesk/components/DeviceDirectoryPanel';
import { PasswordDialog } from './rustdesk/components/PasswordDialog';
import { ConnectionAttemptOverlay } from './rustdesk/components/ConnectionAttemptOverlay';
import { SettingsTab } from './rustdesk/components/SettingsTab';
import { SessionToolbar } from './rustdesk/components/SessionToolbar';
import {
  ANDROID_NAVIGATION_BAR_HEIGHT,
  ANDROID_NAVIGATION_BAR_WIDTH,
  AndroidNavigationBar,
} from './rustdesk/components/AndroidNavigationBar';
import {
  REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT,
  RemoteSoftKeyboard,
} from './rustdesk/components/RemoteSoftKeyboard';
import { ChatDrawer } from './rustdesk/components/ChatDrawer';
import { DisplaySelectorSheet } from './rustdesk/components/DisplaySelectorSheet';
import { QualityControlSheet, QualityPreset } from './rustdesk/components/QualityControlSheet';
import { SessionPanelFrame } from './rustdesk/components/SessionPanelFrame';
import { TransferDrawer } from './rustdesk/components/TransferDrawer';
import { ChatStore } from './rustdesk/ChatStore';
import { RustDeskPreferences } from './rustdesk/RustDeskPreferences';
import { RustDeskLayoutTokens } from './rustdesk/RustDeskLayoutTokens';
import { RustDeskMainBridge } from './rustdesk/RustDeskMainBridge';
import {
  AccountActionResult,
  AccountLoginProvider,
  AccountState,
  DirectorySnapshot,
  PeerRecord,
  ServerConfig,
  SessionDefaults,
} from './rustdesk/RustDeskDirectoryTypes';
import { RustDeskSurfaceController } from './rustdesk/RustDeskSurfaceController';
import { RustDeskInputController } from './rustdesk/RustDeskInputController';
import { RustDeskCursorModel } from './rustdesk/RustDeskCursorModel';
import { RustDeskClipboardController } from './rustdesk/RustDeskClipboardController';
import {
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskSize,
} from './rustdesk/RustDeskInputMapper';
import { RustDeskViewportModel } from './rustdesk/RustDeskViewportModel';
import {
  RemoteSessionOrientationMode,
  RemoteSessionOrientationPolicy,
} from './rustdesk/RemoteSessionOrientationPolicy';
import { RustDeskNativeSessionBridge } from './rustdesk/NativeSessionBridge';
import { DownloadRootManager } from './rustdesk/DownloadRootManager';
import { TransferManager } from './rustdesk/TransferManager';
import { RemoteFilePath } from './rustdesk/RemoteFilePath';
import { TransferProgress } from './rustdesk/TransferProgress';
import {
  FloatingActionSurface,
  FloatingGlassSurface,
} from './rustdesk/components/FloatingSurface';
import { SessionDisplayController } from './rustdesk/SessionDisplayController';
import { SessionOverlayPanel, SessionOverlayState } from './rustdesk/SessionOverlayState';
import { formatSessionToolbarMetrics, SessionToolbarMetrics } from './rustdesk/SessionToolbarMetrics';
import {
  ChatMessage,
  DownloadRoot,
  LocalFileEntry,
  QualityTelemetry,
  RemoteAudioState,
  RemoteFileEntry,
  TransferItem,
} from './rustdesk/RustDeskSessionTypes';
import {
  DATA_TRANSFER_BACKGROUND_BIND_EVENT,
  DATA_TRANSFER_BACKGROUND_CHANGE_EVENT,
  DATA_TRANSFER_BACKGROUND_UNBIND_EVENT,
  DataTransferBackgroundBinding,
} from '../services/DataTransferBackgroundService';
import {
  ActionResponse,
  BridgeSummary,
  DecoderCapability,
  DOMAIN,
  EVENT_POLL_INTERVAL_MS,
  NativeEvent,
  PASSWORD_TIMEOUT_MS,
  PeerDisplayInfo,
  RENDER_STATS_POLL_INTERVAL_MS,
  RenderStatsSnapshot,
  ResolutionInfo,
  SavedConnectionSettings,
  TAG,
} from './rustdesk/RustDeskTypes';

const REMOTE_CURSOR_LOG_SAMPLE_EVERY = 10;
const REMOTE_CURSOR_MIN_VISIBLE_SIZE = 12;
const FALLBACK_CURSOR_BASE_WIDTH = 18;
const FALLBACK_CURSOR_BASE_HEIGHT = 24;
const REMOTE_CURSOR_OPTION_REAPPLY_MS = 1000;
const RENDER_STALL_THRESHOLD_MS = 3500;
const RENDER_STALL_RECOVERY_COOLDOWN_MS = 5000;
const WAITING_FOR_IMAGE_TEXT = 'Connected, waiting for image...';
const PREVIEW_INPUT_FOCUS_ID = 'rustdesk-preview-input-layer';
const SESSION_OVERLAY_TRANSITION_CHAT = 'rustdesk-session-overlay-chat';
const SESSION_OVERLAY_TRANSITION_DISPLAY = 'rustdesk-session-overlay-display';
const SESSION_OVERLAY_TRANSITION_QUALITY = 'rustdesk-session-overlay-quality';
const MAIN_PAGE_TRANSITION_DURATION_MS = 280;
const MAIN_PAGE_TRANSITION_DISTANCE_VP = 20;
const FREE_WINDOW_TITLE_BAR_HEIGHT_VP = 42;
const WIDE_RAIL_EDGE_INSET_VP = 33;
const ROTATION_TRANSITION_OUT_DURATION_MS = 100;
const ROTATION_TRANSITION_IN_DURATION_MS = 200;
const ROTATION_TRANSITION_MID_OPACITY = 0.86;
const ROTATION_TRANSITION_MID_SCALE = 0.985;
const TRANSFER_POLL_INTERVAL_MS = 250;
const REMOTE_AUDIO_POLL_INTERVAL_MS = 1000;
const CONNECTION_TIMEOUT_MS = 45000;
const PREVIEW_MIN_USER_SCALE = 0.5;
const PREVIEW_MAX_USER_SCALE = 4.0;
const PREVIEW_SURFACE_WAIT_ATTEMPTS = 100;
const PREVIEW_SURFACE_WAIT_INTERVAL_MS = 50;
const ANDROID_NAVIGATION_BOTTOM_OFFSET = 80;
const ANDROID_NAVIGATION_EDGE_MARGIN = 12;
const ANDROID_RECENT_PRESS_DURATION_MS = 500;

type PrimarySessionKind = 'remote_control' | 'view_only' | 'view_camera';
type PasswordSessionKind = 'primary' | 'file_transfer';
type PeerLaunchKind = 'remote_control' | 'view_only' | 'view_camera' | 'file_transfer';
type ConnectionUiPhase = 'idle' | 'connecting' | 'awaiting_password' | 'authenticating' | 'connected' | 'failed';

interface RuntimeDirectoryResponse {
  ok: boolean;
  action: string;
  message?: string;
  entries?: string[];
}

interface InterceptedKeyEvent {
  type: string;
  action: number;
  keyCode: number;
}

interface InputInterceptorResponse {
  ok: boolean;
  action: string;
  message?: string;
  active?: boolean;
  result?: number;
  events?: InterceptedKeyEvent[];
}

@Entry
@ComponentV2
struct RustDeskIndex {
  private previewController: RustDeskSurfaceController = new RustDeskSurfaceController();
  private viewportModel: RustDeskViewportModel = new RustDeskViewportModel();
  private nativeSessionBridge: RustDeskNativeSessionBridge = new RustDeskNativeSessionBridge();
  private downloadRootManager: DownloadRootManager = new DownloadRootManager();
  private transferManager: TransferManager = new TransferManager(
    this.nativeSessionBridge,
    () => this.nextTransferSessionId(),
  );
  private chatStore: ChatStore = new ChatStore();
  private sessionDisplayController: SessionDisplayController = new SessionDisplayController(
    this.viewportModel,
    this.nativeSessionBridge,
    () => { this.invalidatePreviewFrames(); },
    (response: ActionResponse) => this.updateSessionState(response),
  );
  private cursorModel: RustDeskCursorModel = new RustDeskCursorModel();
  private mainBridge: RustDeskMainBridge = new RustDeskMainBridge();
  private activeSessionDefaults: SessionDefaults = new SessionDefaults();
  private inputController?: RustDeskInputController;
  private clipboardController?: RustDeskClipboardController;
  private preferences?: RustDeskPreferences;
  private connectScroller: Scroller = new Scroller();
  private deviceRecentScroller: Scroller = new Scroller();
  private deviceAddressBookScroller: Scroller = new Scroller();
  private deviceLanScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private transferScroller: Scroller = new Scroller();
  private keyboardEnteredSessionId: string = '';
  private lastKeyboardFocusLogAt: number = 0;
  @Local pageVisible: boolean = true;
  private remoteInteractionReady: boolean = false;
  private inputInterceptorActive: boolean = false;
  private previewKeyboardCaptureFocused: boolean = false;
  private previewKeyboardBlurTimer: number = -1;
  private softKeyboardPressedKeys: string[] = [];
  private softKeyboardAltActive: boolean = false;
  private softKeyboardCtrlActive: boolean = false;
  private softKeyboardShiftActive: boolean = false;
  private softKeyboardCommandActive: boolean = false;
  private lanScanTimer: number = -1;
  private accountPollTimer: number = -1;
  private accountOptionsPollTimer: number = -1;
  private addressBookPollTimer: number = -1;
  private accountOidcActive: boolean = false;
  private accountOidcOpenedUrl: string = '';

  @Local currentTabIndex: number = 0;
  @Local mainTabTransitionDirection: number = 1;
  @Local mainViewportWidth: number = 390;
  @Local mainViewportHeight: number = 844;
  @Local rotationTransitionOpacity: number = 1;
  @Local rotationTransitionScale: number = 1;
  @Local windowTopAvoidInset: number = 0;
  @Local windowBottomAvoidInset: number = 0;
  @Local rootFocusedControl: string = '';
  private viewportOrientationInitialized: boolean = false;
  private lastViewportPortrait: boolean = true;

  @Local nativeVersion: string = 'loading...';
  @Local health: string = 'waiting...';
  @Local integrationStage: string = 'unknown';
  @Local upstreamRepo: string = '';
  @Local notes: string = '';
  @Local apiServer: string = '';
  @Local nativeBuildMarker: string = '';
  @Local decoderCapabilities: DecoderCapability[] = [];
  @Local errorText: string = '';
  @Local serverConfig: ServerConfig = new ServerConfig();
  @Local serverValidating: boolean = false;
  @Local serverSaving: boolean = false;
  @Local directorySnapshot: DirectorySnapshot = new DirectorySnapshot();
  @Local sessionDefaults: SessionDefaults = new SessionDefaults();
  @Local accountState: AccountState = new AccountState();
  @Local accountLoginProviders: AccountLoginProvider[] = [];
  @Local clipboardSyncEnabled: boolean = true;

  @Local peerTarget: string = '';
  @Local passwordDraft: string = '';
  @Local rememberPassword: boolean = false;

  @Local activeSessionId: string = '';
  @Local activeCoreSessionId: string = '';
  @Local activeSessionKind: PrimarySessionKind = 'remote_control';
  @Local sessionPhase: string = 'idle';
  @Local sessionMessage: string = '未连接';
  @Local connectionSummary: string = '未连接';
  @Local connectionUiPhase: ConnectionUiPhase = 'idle';
  @Local connectionUiTarget: string = '';
  @Local connectionUiMessage: string = '';
  @Local qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @Local toolbarRenderStats: RenderStatsSnapshot = {
    fps: 0,
    totalFrames: 0,
    lastFrameAgeMs: 0,
    hasRenderedFrame: false,
  };
  @Local isPolling: boolean = false;
  @Local frameStatus: string = 'Surface not ready';
  @Local frameWidth: number = 0;
  @Local frameHeight: number = 0;
  @Local renderFpsText: string = 'FPS --';
  @Local showPreviewModal: boolean = false;
  @Local showTransferWorkspace: boolean = false;
  @Local previewSurfaceVisible: boolean = false;
  @Local previewSurfaceGeneration: number = 0;
  @Local relativeMouseMode: boolean = false;
  @Local previewViewWidth: number = 0;
  @Local previewViewHeight: number = 0;
  @Local previewTransformMode: boolean = false;
  @Local previewUserScale: number = 1;
  @Local previewUserOffsetX: number = 0;
  @Local previewUserOffsetY: number = 0;
  @Local previewUserRotation: number = 0;
  @Local previewFramePixelMap: image.PixelMap | undefined = undefined;
  @Local rgbaFallbackActive: boolean = false;
  @Local isFoldHoverMode: boolean = false;
  @Local softKeyboardVisible: boolean = false;
  @Local softKeyboardDockTop: boolean = false;
  @Local foldHoverUpperHeight: number = 0;
  @Local foldHoverCreaseHeight: number = 0;

  private runtimeInitialized: boolean = false;
  private connectionGeneration: number = 0;
  private connectionTimeoutId: number = -1;
  private lastConnectionKind: PrimarySessionKind = 'remote_control';
  private connectionAttemptKind: PasswordSessionKind = 'primary';
  private sessionCloseInFlight: boolean = false;
  private pollTimer: number = -1;
  private passwordTimeoutId: number = -1;
  private eventPollInFlight: boolean = false;
  private previewFrameInFlight: boolean = false;
  private performanceTuningApplied: boolean = false;
  private lastRenderStatsPollAt: number = 0;
  private lastRenderTotalFrames: number = 0;
  private renderStallFirstDetectedAt: number = 0;
  private lastRenderRecoveryAt: number = 0;
  private renderStallRecoveryAttempts: number = 0;
  private previewSurfaceId: string = '';
  private previewSurfaceSetupInFlight: boolean = false;
  private previewSurfaceSetupGeneration: number = -1;
  private pendingPreviewPeerInfo?: NativeEvent;
  private previewGestureStartScale: number = 1;
  private previewGestureStartOffsetX: number = 0;
  private previewGestureStartOffsetY: number = 0;
  private previewGestureStartRotation: number = 0;
  private androidNavigationPositionInitialized: boolean = false;
  private androidNavigationDragStartX: number = 0;
  private androidNavigationDragStartY: number = 0;
  private lastAppliedDisplay: number = -1;
  private lastAppliedVideoWidth: number = 0;
  private lastAppliedVideoHeight: number = 0;
  private peerPlatform: string = '';
  private peerVersion: string = '';
  private peerDisplays: PeerDisplayInfo[] = [];
  private supportedResolutions: ResolutionInfo[] = [];
  private qualityTelemetry: QualityTelemetry = {
    fps: '--',
    delay: '--',
    codec: '--',
    speed: '--',
    targetBitrate: '--',
    chroma: '--',
  };
  private preferredCodec: string = 'auto';
  private codecPreferenceApplied: boolean = false;
  @Local passwordDialogVisible: boolean = false;
  private passwordSessionKind: PasswordSessionKind = 'primary';
  private sessionFullscreenApplied: boolean = false;
  private sessionOrientationMode: RemoteSessionOrientationMode = RemoteSessionOrientationMode.FOLLOW_DESKTOP;
  private landscapeMultiWindowEnabled: boolean = false;
  private sessionWindowUpdatePromise: Promise<void> = Promise.resolve();
  private immersiveWindow?: window.Window;
  private avoidAreaChangeRegistered: boolean = false;
  private onWindowAvoidAreaChange: Callback<window.AvoidAreaOptions> = (options: window.AvoidAreaOptions) => {
    this.updateWindowAvoidArea(options.type, options.area);
  };
  private remoteCursorEventLogCounter: number = 0;
  private relativeModeActivatedAt: number = 0;
  private remoteCursorOptionApplied: boolean = false;
  private remoteCursorOptionLastAppliedAt: number = 0;
  private remoteCursorOptionFirstAppliedAt: number = 0;
  private remoteCursorEnableAttempts: number = 0;
  private foldStatusChangeRegistered: boolean = false;
  private windowSizeChangeRegistered: boolean = false;
  private previewWindow?: window.Window;
  private onFoldStatusChange: Callback<display.FoldStatus> = (_status: display.FoldStatus) => {
    this.refreshFoldHoverMode();
  };
  private onPreviewWindowSizeChange: Callback<window.Size> = (_size: window.Size) => {
    this.refreshFoldHoverMode();
  };
  private freeWindow?: window.Window;
  private freeWindowDragExpected: boolean = false;
  private freeWindowStatusChangeRegistered: boolean = false;
  private freeWindowChromeOwned: boolean = false;
  private onFreeWindowStatusChange: Callback<window.WindowStatusType> = (status: window.WindowStatusType) => {
    this.applyFreeMultiWindowChrome(status);
  };
  @Local freeMultiWindow: boolean = false;
  private pcSessionWindowStatusBeforeImmersive: window.WindowStatusType = window.WindowStatusType.UNDEFINED;
  private pcSessionImmersiveRequested: boolean = false;
  private pcSessionImmersiveApplied: boolean = false;
  @Local remoteCursorVisible: boolean = false;
  @Local remoteCursorLeft: number = 0;
  @Local remoteCursorTop: number = 0;
  @Local remoteCursorPixelMap: image.PixelMap | undefined = undefined;
  @Local remoteCursorBitmapWidth: number = 0;
  @Local remoteCursorBitmapHeight: number = 0;
  @Local remoteCursorHotX: number = 0;
  @Local remoteCursorHotY: number = 0;
  @Local isMiniBarExpanded: boolean = false;
  @Local androidNavigationVisible: boolean = true;
  @Local androidNavigationX: number = 0;
  @Local androidNavigationY: number = 0;
  @Local remoteKeyboardPermissionAllowed: boolean = true;
  private overlayState: SessionOverlayState = new SessionOverlayState();
  @Local activeOverlayPanel: SessionOverlayPanel = 'home';
  @Local chatDraft: string = '';
  @Local chatRevision: number = 0;
  @Local selectedQualityPreset: QualityPreset = 'balanced';
  @Local customQualityDraft: number = 50;
  @Local customFpsDraft: number = 30;
  @Local transferRootPath: string = '';
  @Local transferRootStatus: string = '选择下载位置后可传输';
  @Local transferConnectionStatus: string = '文件传输未连接';
  @Local transferLocalEntries: LocalFileEntry[] = [];
  @Local transferRemoteEntries: RemoteFileEntry[] = [];
  @Local transferRemoteDirectory: string = '/';
  @Local selectedTransferLocalName: string = '';
  @Local selectedTransferRemoteName: string = '';
  @Local transferItems: TransferItem[] = [];
  @Local transferSessionReady: boolean = false;
  @Local remoteAudioState: RemoteAudioState = {
    available: false,
    muted: false,
    rendererActive: false,
    errorText: '',
  };
  private remoteAudioPollTimer: number = -1;
  private remoteAudioDefaultApplied: boolean = false;
  private transferRoot: DownloadRoot | undefined = undefined;
  private transferSessionTarget: string = '';
  private transferPollTimer: number = -1;
  private transferPollInFlight: boolean = false;
  private transferConnectionPending: boolean = false;
  private transferSessionSequence: number = 0;
  private initialDisplayCommandIssued: boolean = false;
  private pendingDisplayIndex: number = -1;
  private pendingResolutionDisplay: number = -1;
  private pendingResolutionWidth: number = 0;
  private pendingResolutionHeight: number = 0;
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  aboutToAppear(): void {
    this.pageVisible = true;
    this.previewController.onCreated = (surfaceId: string) => this.handlePreviewSurfaceCreated(surfaceId);
    this.previewController.onChanged = (surfaceId: string, rect: SurfaceRect) =>
      this.handlePreviewSurfaceChanged(surfaceId, rect);
    this.previewController.onDestroyed = (surfaceId: string) => this.handlePreviewSurfaceDestroyed(surfaceId);
    this.initializeRuntime();
    this.registerWindowAvoidAreaListener();
    this.applySessionFullscreen(false, true);
    this.registerFreeWindowChrome();
    this.publishDataTransferBinding();
  }

  aboutToDisappear(): void {
    this.connectionGeneration += 1;
    this.clearConnectionTimeout();
    this.clearPasswordTimeout();
    this.clearPreviewKeyboardBlurTimer();
    this.clearLanScanTimer();
    this.clearAccountPollTimer();
    this.clearAccountOptionsPollTimer();
    this.clearAddressBookPollTimer();
    if (this.accountOidcActive) {
      this.mainBridge.cancelAccountOidc();
      this.accountOidcActive = false;
      this.accountOidcOpenedUrl = '';
    }
    this.previewKeyboardCaptureFocused = false;
    this.releaseSoftKeyboardKeys();
    this.stopInputInterceptor();
    this.clipboardController?.reset();
    this.setSessionKeyboardEntered(false);
    this.unregisterWindowAvoidAreaListener();
    this.unregisterFoldHoverListeners();
    this.clearSurfaceBinding();
    this.stopPolling();
    this.closeTransferSession();
    this.closeRemoteAudio();
    this.publishDataTransferUnbind();
    void this.applySessionFullscreen(false)
      .finally((): void => {
        this.unregisterFreeWindowChrome();
      });
  }

  onPageShow(): void {
    this.pageVisible = true;
    this.syncClipboardController();
    this.syncInputInterceptor();
    this.refreshFreeWindowChrome();
    this.refreshSessionOrientation();
    if (this.accountOidcActive) {
      this.scheduleAccountPoll(200);
    }
  }

  onPageHide(): void {
    this.pageVisible = false;
    this.clipboardController?.stop();
    this.stopInputInterceptor();
  }

  private getInputController(): RustDeskInputController {
    if (!this.inputController) {
      this.inputController = new RustDeskInputController({
        isSessionActive: () => this.isRemoteControlSessionActive(),
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

  private isPeerAndroid(): boolean {
    return this.peerPlatform.toLowerCase().replace(/[\s_-]/g, '') === 'android';
  }

  private isPeerVersionAtLeast(major: number, minor: number, patch: number): boolean {
    if (this.peerVersion.length === 0) {
      return false;
    }
    const parts = this.peerVersion.split('.');
    const currentMajor = Number.parseInt(parts.length > 0 ? parts[0] : '0', 10);
    const currentMinor = Number.parseInt(parts.length > 1 ? parts[1] : '0', 10);
    const currentPatch = Number.parseInt(parts.length > 2 ? parts[2] : '0', 10);
    const normalizedMajor = Number.isFinite(currentMajor) ? currentMajor : 0;
    const normalizedMinor = Number.isFinite(currentMinor) ? currentMinor : 0;
    const normalizedPatch = Number.isFinite(currentPatch) ? currentPatch : 0;
    if (normalizedMajor !== major) {
      return normalizedMajor > major;
    }
    if (normalizedMinor !== minor) {
      return normalizedMinor > minor;
    }
    return normalizedPatch >= patch;
  }

  private androidNavigationAvailable(): boolean {
    return this.isRemoteControlSessionActive()
      && this.isPeerAndroid()
      && this.isPeerVersionAtLeast(1, 2, 7)
      && this.remoteKeyboardPermissionAllowed;
  }

  private clampAndroidNavigationX(value: number, viewportWidth: number = this.previewViewWidth): number {
    const maxX = Math.max(
      ANDROID_NAVIGATION_EDGE_MARGIN,
      viewportWidth - ANDROID_NAVIGATION_BAR_WIDTH - ANDROID_NAVIGATION_EDGE_MARGIN,
    );
    return Math.min(Math.max(value, ANDROID_NAVIGATION_EDGE_MARGIN), maxX);
  }

  private clampAndroidNavigationY(value: number, viewportHeight: number = this.previewViewHeight): number {
    const maxY = Math.max(
      ANDROID_NAVIGATION_EDGE_MARGIN,
      viewportHeight - ANDROID_NAVIGATION_BAR_HEIGHT - ANDROID_NAVIGATION_EDGE_MARGIN,
    );
    return Math.min(Math.max(value, ANDROID_NAVIGATION_EDGE_MARGIN), maxY);
  }

  private updateAndroidNavigationViewport(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    if (!this.androidNavigationPositionInitialized) {
      this.androidNavigationX = this.clampAndroidNavigationX(
        (width - ANDROID_NAVIGATION_BAR_WIDTH) / 2,
        width,
      );
      this.androidNavigationY = this.clampAndroidNavigationY(
        height - ANDROID_NAVIGATION_BAR_HEIGHT - ANDROID_NAVIGATION_BOTTOM_OFFSET,
        height,
      );
      this.androidNavigationPositionInitialized = true;
      this.saveAndroidNavigationPosition();
      return;
    }
    const nextX = this.clampAndroidNavigationX(this.androidNavigationX, width);
    const nextY = this.clampAndroidNavigationY(this.androidNavigationY, height);
    if (nextX !== this.androidNavigationX || nextY !== this.androidNavigationY) {
      this.androidNavigationX = nextX;
      this.androidNavigationY = nextY;
      this.saveAndroidNavigationPosition();
    }
  }

  private saveAndroidNavigationPosition(): void {
    this.preferences?.saveAndroidNavigationPosition(
      this.androidNavigationX,
      this.androidNavigationY,
    );
  }

  private sendAndroidNavigationButton(button: string, down: boolean): void {
    if (!this.androidNavigationAvailable()) {
      return;
    }
    this.sendAndroidNavigationButtonToSession(this.activeSessionId, button, down, true);
  }

  private sendAndroidNavigationButtonToSession(
    sessionId: string,
    button: string,
    down: boolean,
    reportFailure: boolean,
  ): void {
    const payload = new RustDeskMousePayload();
    payload.type = down ? 'down' : 'up';
    payload.buttons = button;
    this.sendMousePayloadToSession(sessionId, payload, reportFailure);
  }

  private tapAndroidNavigationButton(button: string): void {
    this.sendAndroidNavigationButton(button, true);
    this.sendAndroidNavigationButton(button, false);
  }

  private sendAndroidBack(): void {
    const button = this.isPeerVersionAtLeast(1, 3, 8) ? 'back' : 'right';
    this.tapAndroidNavigationButton(button);
  }

  private sendAndroidHome(): void {
    this.tapAndroidNavigationButton('wheel');
  }

  private sendAndroidRecentApps(): void {
    if (!this.androidNavigationAvailable()) {
      return;
    }
    const sessionId = this.activeSessionId;
    this.sendAndroidNavigationButtonToSession(sessionId, 'wheel', true, true);
    setTimeout((): void => {
      this.sendAndroidNavigationButtonToSession(sessionId, 'wheel', false, false);
    }, ANDROID_RECENT_PRESS_DURATION_MS);
  }

  private initializeRuntime(): void {
    if (this.runtimeInitialized) {
      this.refreshNativeState();
      this.refreshDirectorySnapshot();
      if (!this.accountState.loggedIn) {
        this.loadAccountLoginOptions();
      }
      return;
    }
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.preferences = new RustDeskPreferences(hostContext);
      this.clipboardController = new RustDeskClipboardController(hostContext, {
        sendText: (content: string) => this.sendClipboardText(content),
        log: (label: string, payload: string) => this.logRelativeDebug(label, payload),
      });
      this.applySavedSettings(this.preferences.load());
      this.sessionDefaults = this.preferences.loadSessionDefaults();
      const androidNavigationState = this.preferences.loadAndroidNavigationState();
      this.androidNavigationVisible = androidNavigationState.visible;
      this.androidNavigationPositionInitialized = androidNavigationState.positionInitialized;
      this.androidNavigationX = androidNavigationState.x;
      this.androidNavigationY = androidNavigationState.y;
      this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
      this.clipboardSyncEnabled = this.sessionDefaults.clipboardEnabled;

      const response = JSON.parse(native.runtimeInit(hostContext.filesDir, 'RustDesk HMOS')) as Record<string, string>;
      this.runtimeInitialized = true;
      this.apiServer = native.runtimeGetApiServer();
      this.nativeBuildMarker = native.buildMarker();
      let decoderCapabilityResponse: ESObject = JSON.parse(native.runtimeGetDecoderCapabilities());
      let decoderCapabilityRows: ESObject = decoderCapabilityResponse.capabilities;
      const decoderCapabilities = this.copyDecoderCapabilities(decoderCapabilityRows);
      this.decoderCapabilities = decoderCapabilities;
      this.applySessionDefaultsToIdleState(decoderCapabilities);
      this.serverConfig = this.mainBridge.loadServerConfig();
      this.refreshAccountState();
      this.refreshDirectorySnapshot();
      if (this.accountState.loggedIn) {
        this.startAddressBookSync(true);
      }
      this.sessionMessage = String(response['message'] ?? 'Runtime initialized');
      this.refreshNativeState();
      if (!this.accountState.loggedIn) {
        this.loadAccountLoginOptions();
      }
    } catch (error) {
      this.errorText = `Runtime init failed: ${String(error)}`;
      hilog.error(DOMAIN, TAG, 'initializeRuntime failed: %{public}s', this.errorText);
    }
  }

  private copyDecoderCapabilities(source: ESObject): DecoderCapability[] {
    const capabilities: DecoderCapability[] = [];
    for (let index = 0; index < source.length; index += 1) {
      let sourceCapability: ESObject = source[index];
      const capability = new DecoderCapability();
      capability.codec = String(sourceCapability.codec ?? '').trim();
      capability.mime = String(sourceCapability.mime ?? '').trim();
      capability.recommendedAvailable = Boolean(sourceCapability.recommendedAvailable);
      capability.mimeAvailable = Boolean(sourceCapability.mimeAvailable ?? sourceCapability.recommendedAvailable);
      capability.recommendedName = String(sourceCapability.recommendedName ?? '').trim();
      capability.recommendedIsHardware = Boolean(sourceCapability.recommendedIsHardware);
      capability.hardwareAvailable = Boolean(sourceCapability.hardwareAvailable);
      capability.hardwareName = String(sourceCapability.hardwareName ?? '').trim();
      capability.softwareAvailable = Boolean(sourceCapability.softwareAvailable);
      capability.softwareName = String(sourceCapability.softwareName ?? '').trim();
      capabilities.push(capability);
    }
    return capabilities;
  }

  private applySavedSettings(settings: SavedConnectionSettings): void {
    this.peerTarget = settings.target;
    this.rememberPassword = settings.rememberPassword;
  }

  private copySessionDefaults(source: SessionDefaults): SessionDefaults {
    const defaults = new SessionDefaults();
    defaults.relativeMouseMode = source.relativeMouseMode;
    defaults.audioEnabled = source.audioEnabled;
    defaults.clipboardEnabled = source.clipboardEnabled;
    defaults.qualityPreset = source.qualityPreset;
    defaults.customQuality = source.customQuality;
    defaults.customFps = source.customFps;
    defaults.preferredCodec = source.preferredCodec;
    defaults.gesturesEnabled = source.gesturesEnabled;
    defaults.toolbarExpanded = source.toolbarExpanded;
    return defaults;
  }

  private resolvePreferredCodec(requested: string, capabilities: DecoderCapability[]): string {
    const normalized = requested.trim().toLowerCase();
    if (normalized === 'auto') {
      return this.selectPreferredCodec(capabilities);
    }
    const supported = ['h264', 'h265', 'vp8', 'vp9', 'av1'];
    if (!supported.includes(normalized)) {
      return this.selectPreferredCodec(capabilities);
    }
    for (let index = 0; index < capabilities.length; index += 1) {
      const capability = capabilities[index];
      if (capability.codec.toLowerCase() !== normalized) {
        continue;
      }
      if (capability.mimeAvailable || capability.recommendedAvailable || capability.hardwareAvailable || capability.softwareAvailable) {
        return normalized;
      }
    }
    return this.selectPreferredCodec(capabilities);
  }

  private qualityPresetFor(defaults: SessionDefaults): QualityPreset {
    const preset = defaults.qualityPreset.trim().toLowerCase();
    if (preset === 'best') {
      return 'best';
    }
    if (preset === 'speed' || preset === 'low') {
      return 'low';
    }
    if (preset === 'custom') {
      return 'custom';
    }
    return 'balanced';
  }

  private defaultQualityPreset(): QualityPreset {
    return this.qualityPresetFor(this.sessionDefaults);
  }

  private applySessionDefaultsToIdleState(capabilities: DecoderCapability[]): void {
    this.relativeMouseMode = this.sessionDefaults.relativeMouseMode;
    this.clipboardSyncEnabled = this.sessionDefaults.clipboardEnabled;
    this.selectedQualityPreset = this.defaultQualityPreset();
    this.preferredCodec = this.resolvePreferredCodec(this.sessionDefaults.preferredCodec, capabilities);
    this.isMiniBarExpanded = this.sessionDefaults.toolbarExpanded;
  }

  private saveSessionDefaults(defaults: SessionDefaults): void {
    const nextDefaults = this.copySessionDefaults(defaults);
    this.sessionDefaults = nextDefaults;
    this.preferences?.saveSessionDefaults(nextDefaults);
    if (!this.activeSessionId) {
      this.activeSessionDefaults = this.copySessionDefaults(nextDefaults);
      this.applySessionDefaultsToIdleState(this.decoderCapabilities);
    }
  }

  private copyAccountState(source: AccountState): AccountState {
    const state = new AccountState();
    state.loggedIn = source.loggedIn;
    state.apiServer = source.apiServer;
    state.name = source.name;
    state.displayName = source.displayName;
    state.email = source.email;
    state.busy = source.busy;
    state.syncing = source.syncing;
    state.challengeId = source.challengeId;
    state.challengeType = source.challengeType;
    state.emailHint = source.emailHint;
    state.oidcProvider = source.oidcProvider;
    state.message = source.message;
    return state;
  }

  private updateServerAccountAvailability(loggedIn: boolean): void {
    const config = new ServerConfig();
    config.mode = this.serverConfig.mode;
    config.idServer = this.serverConfig.idServer;
    config.relayServer = this.serverConfig.relayServer;
    config.apiServer = this.serverConfig.apiServer;
    config.key = this.serverConfig.key;
    config.effectiveApiServer = this.serverConfig.effectiveApiServer;
    config.usingPublicServer = this.serverConfig.usingPublicServer;
    config.remoteReachable = this.serverConfig.remoteReachable;
    config.accountAvailable = loggedIn;
    config.message = this.serverConfig.message;
    this.serverConfig = config;
  }

  private refreshAccountState(preserveTransient: boolean = true): void {
    const previous = this.accountState;
    const state = this.mainBridge.loadAccountState();
    if (preserveTransient) {
      state.busy = previous.busy;
      state.syncing = previous.syncing;
      state.challengeId = previous.challengeId;
      state.challengeType = previous.challengeType;
      state.emailHint = previous.emailHint;
      state.oidcProvider = previous.oidcProvider;
      if (state.message.length === 0) {
        state.message = previous.message;
      }
    }
    this.accountState = state;
    this.updateServerAccountAvailability(state.loggedIn);
  }

  private loadAccountLoginOptions(): void {
    this.clearAccountOptionsPollTimer();
    if (!this.runtimeInitialized || this.accountState.loggedIn) {
      this.accountLoginProviders = [];
      return;
    }
    const result = this.mainBridge.startAccountLoginOptions();
    if (!result.ok || result.state !== 'pending') {
      this.accountLoginProviders = [];
      const state = this.copyAccountState(this.accountState);
      state.message = result.message || '无法获取浏览器登录方式';
      this.accountState = state;
      return;
    }
    this.scheduleAccountOptionsPoll();
  }

  private scheduleAccountOptionsPoll(): void {
    this.clearAccountOptionsPollTimer();
    this.accountOptionsPollTimer = setTimeout(() => {
      this.accountOptionsPollTimer = -1;
      this.pollAccountLoginOptions();
    }, 350) as number;
  }

  private pollAccountLoginOptions(): void {
    const result = this.mainBridge.pollAccountLoginOptions();
    if (result.state === 'pending') {
      this.scheduleAccountOptionsPoll();
      return;
    }
    if (result.ok && result.state === 'ready') {
      this.accountLoginProviders = result.providers;
      return;
    }
    this.accountLoginProviders = [];
    if (!this.accountOidcActive) {
      const state = this.copyAccountState(this.accountState);
      state.message = result.message || '当前账户服务未提供浏览器登录方式';
      this.accountState = state;
    }
  }

  private clearAccountOptionsPollTimer(): void {
    if (this.accountOptionsPollTimer < 0) {
      return;
    }
    clearTimeout(this.accountOptionsPollTimer);
    this.accountOptionsPollTimer = -1;
  }

  private isAccountProviderAvailable(provider: string): boolean {
    const normalizedProvider = provider.trim().toLowerCase();
    for (let index = 0; index < this.accountLoginProviders.length; index += 1) {
      if (this.accountLoginProviders[index].name.trim().toLowerCase() === normalizedProvider) {
        return true;
      }
    }
    return false;
  }

  private oidcStateMessage(stateMessage: string, hasUrl: boolean): string {
    const normalized = stateMessage.trim().toLowerCase();
    if (normalized === 'requesting account auth') {
      return '正在向账户服务申请授权链接…';
    }
    if (normalized === 'login account auth') {
      return '授权已确认，正在完成登录…';
    }
    if (normalized === 'waiting account auth' || hasUrl) {
      return '已打开系统浏览器，请完成授权后返回。';
    }
    return '正在等待浏览器授权…';
  }

  private failAccountOidcAuthorization(message: string): void {
    this.clearAccountPollTimer();
    if (this.accountOidcActive) {
      this.mainBridge.cancelAccountOidc();
    }
    this.accountOidcActive = false;
    this.accountOidcOpenedUrl = '';
    const state = this.copyAccountState(this.accountState);
    state.busy = false;
    state.oidcProvider = '';
    state.message = message;
    this.accountState = state;
  }

  private openAccountAuthorizationUrl(url: string): void {
    const normalizedUrl = url.trim();
    if (normalizedUrl.length === 0 || normalizedUrl === this.accountOidcOpenedUrl) {
      return;
    }
    this.accountOidcOpenedUrl = normalizedUrl;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const options: OpenLinkOptions = {
      appLinkingOnly: false,
    };
    try {
      void context.openLink(normalizedUrl, options).catch((error: BusinessError) => {
        if (!this.accountOidcActive || this.accountOidcOpenedUrl !== normalizedUrl) {
          return;
        }
        this.failAccountOidcAuthorization(`无法打开系统浏览器：${error.message}`);
      });
    } catch (error) {
      this.failAccountOidcAuthorization(`无法打开系统浏览器：${String(error)}`);
    }
  }

  private startAccountOidc(provider: string): void {
    const normalizedProvider = provider.trim().toLowerCase();
    if (this.accountState.busy || this.accountState.syncing ||
      !this.isAccountProviderAvailable(normalizedProvider)) {
      return;
    }
    this.clearAccountPollTimer();
    const result = this.mainBridge.startAccountOidc(normalizedProvider);
    if (!result.ok || result.state !== 'pending') {
      const failed = this.copyAccountState(this.accountState);
      failed.message = result.message || '无法启动浏览器授权';
      this.accountState = failed;
      return;
    }
    this.accountOidcActive = true;
    this.accountOidcOpenedUrl = '';
    const state = this.copyAccountState(this.accountState);
    state.busy = true;
    state.challengeId = '';
    state.challengeType = '';
    state.emailHint = '';
    state.oidcProvider = normalizedProvider;
    state.message = '正在向账户服务申请授权链接…';
    this.accountState = state;
    this.scheduleAccountPoll(500);
  }

  private pollAccountOidcAction(): void {
    const result = this.mainBridge.pollAccountOidc();
    if (result.ok && result.state === 'pending') {
      this.openAccountAuthorizationUrl(result.url);
      const state = this.copyAccountState(this.accountState);
      state.busy = true;
      state.message = this.oidcStateMessage(result.stateMessage, result.url.length > 0);
      this.accountState = state;
      this.scheduleAccountPoll(800);
      return;
    }
    this.accountOidcActive = false;
    this.accountOidcOpenedUrl = '';
    const state = this.copyAccountState(this.accountState);
    state.busy = false;
    state.oidcProvider = '';
    if (result.ok && result.state === 'authenticated') {
      this.accountState = state;
      this.refreshAccountState(false);
      if (!this.accountState.loggedIn) {
        const failed = this.copyAccountState(this.accountState);
        failed.message = '浏览器授权完成，但登录状态读取失败';
        this.accountState = failed;
        return;
      }
      const authenticated = this.copyAccountState(this.accountState);
      authenticated.message = '登录成功，正在同步通讯簿';
      this.accountState = authenticated;
      this.startAddressBookSync(true);
      return;
    }
    state.message = result.message || '浏览器授权失败';
    this.accountState = state;
  }

  private cancelAccountOidc(): void {
    this.clearAccountPollTimer();
    const cancelled = !this.accountOidcActive || this.mainBridge.cancelAccountOidc();
    this.accountOidcActive = false;
    this.accountOidcOpenedUrl = '';
    const state = this.copyAccountState(this.accountState);
    state.busy = false;
    state.oidcProvider = '';
    state.message = cancelled ? '已取消浏览器授权' : '无法取消浏览器授权';
    this.accountState = state;
  }

  private startAccountLogin(username: string, password: string): void {
    if (this.accountState.busy || this.accountState.syncing) {
      return;
    }
    const result = this.mainBridge.startAccountLogin(username, password);
    if (!result.ok || result.state !== 'pending') {
      const state = this.copyAccountState(this.accountState);
      state.message = result.message || '无法启动登录请求';
      this.accountState = state;
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.busy = true;
    state.challengeId = '';
    state.challengeType = '';
    state.emailHint = '';
    state.message = '';
    this.accountState = state;
    this.scheduleAccountPoll();
  }

  private startAccountVerification(code: string): void {
    if (this.accountState.busy || this.accountState.challengeId.length === 0) {
      return;
    }
    const result = this.mainBridge.startAccountVerification(this.accountState.challengeId, code);
    if (!result.ok || result.state !== 'pending') {
      const state = this.copyAccountState(this.accountState);
      state.message = result.message || '无法提交验证码';
      this.accountState = state;
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.busy = true;
    state.message = '';
    this.accountState = state;
    this.scheduleAccountPoll();
  }

  private cancelAccountChallenge(): void {
    if (!this.mainBridge.cancelAccountChallenge()) {
      const failed = this.copyAccountState(this.accountState);
      failed.message = '无法取消本次账户验证';
      this.accountState = failed;
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.challengeId = '';
    state.challengeType = '';
    state.emailHint = '';
    state.message = '';
    this.accountState = state;
  }

  private scheduleAccountPoll(delayMs: number = 300): void {
    this.clearAccountPollTimer();
    this.accountPollTimer = setTimeout(() => {
      this.accountPollTimer = -1;
      this.pollAccountAction();
    }, delayMs) as number;
  }

  private pollAccountAction(): void {
    if (this.accountOidcActive) {
      this.pollAccountOidcAction();
      return;
    }
    const result = this.mainBridge.pollAccountAction();
    if (result.state === 'pending') {
      this.scheduleAccountPoll();
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.busy = false;
    if (result.state === 'authenticated' && result.ok) {
      this.accountState = state;
      this.refreshAccountState(false);
      if (!this.accountState.loggedIn) {
        const failed = this.copyAccountState(this.accountState);
        failed.message = failed.message || '登录状态读取失败';
        this.accountState = failed;
        return;
      }
      const authenticated = this.copyAccountState(this.accountState);
      authenticated.message = '登录成功，正在同步通讯簿';
      this.accountState = authenticated;
      this.startAddressBookSync(true);
      return;
    }
    if (result.state === 'challenge' && result.ok) {
      state.challengeId = result.challengeId;
      state.challengeType = result.challengeType;
      state.emailHint = result.emailHint;
      state.message = result.challengeType === 'totp'
        ? '请输入双重验证动态码'
        : '请输入邮箱验证码';
      this.accountState = state;
      return;
    }
    state.message = result.message || '账户请求失败';
    this.accountState = state;
  }

  private clearAccountPollTimer(): void {
    if (this.accountPollTimer < 0) {
      return;
    }
    clearTimeout(this.accountPollTimer);
    this.accountPollTimer = -1;
  }

  private logoutAccount(): void {
    if (!this.mainBridge.logoutAccount()) {
      const failed = this.copyAccountState(this.accountState);
      failed.message = '退出账户失败';
      this.accountState = failed;
      return;
    }
    this.clearAccountPollTimer();
    this.clearAddressBookPollTimer();
    this.refreshAccountState(false);
    const state = this.copyAccountState(this.accountState);
    state.message = '已退出账户';
    this.accountState = state;
    this.refreshDirectorySnapshot();
    this.loadAccountLoginOptions();
  }

  private startAddressBookSync(silent: boolean = false): void {
    if (!this.accountState.loggedIn || this.accountState.syncing) {
      return;
    }
    const result = this.mainBridge.startAddressBookSync();
    if (!result.ok || result.state !== 'pending') {
      const state = this.copyAccountState(this.accountState);
      const message = result.message || '无法启动通讯簿同步';
      state.message = silent ? `通讯簿自动同步未启动：${message}` : message;
      this.accountState = state;
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.syncing = true;
    if (!silent) {
      state.message = '';
    }
    this.accountState = state;
    this.scheduleAddressBookPoll();
  }

  private scheduleAddressBookPoll(): void {
    this.clearAddressBookPollTimer();
    this.addressBookPollTimer = setTimeout(() => {
      this.addressBookPollTimer = -1;
      this.pollAddressBookSync();
    }, 350) as number;
  }

  private pollAddressBookSync(): void {
    const result = this.mainBridge.pollAddressBookSync();
    if (result.state === 'pending') {
      this.scheduleAddressBookPoll();
      return;
    }
    const state = this.copyAccountState(this.accountState);
    state.syncing = false;
    if (result.state === 'synced' && result.ok) {
      state.message = `已同步 ${result.addressBookCount} 个通讯簿、${result.peerCount} 台设备`;
      this.accountState = state;
      this.refreshDirectorySnapshot();
      return;
    }
    state.message = result.message || '通讯簿同步失败';
    this.accountState = state;
    this.refreshAccountState(true);
  }

  private clearAddressBookPollTimer(): void {
    if (this.addressBookPollTimer < 0) {
      return;
    }
    clearTimeout(this.addressBookPollTimer);
    this.addressBookPollTimer = -1;
  }

  private testServerConfiguration(config: ServerConfig): void {
    this.serverValidating = true;
    try {
      this.serverConfig = this.mainBridge.testServerConfig(config);
    } finally {
      this.serverValidating = false;
    }
  }

  private saveServerConfiguration(config: ServerConfig): void {
    const previousApiServer = this.serverConfig.effectiveApiServer;
    this.serverSaving = true;
    try {
      const result = this.mainBridge.saveServerConfig(config);
      this.serverConfig = result;
      if (!result.remoteReachable) {
        return;
      }
      const accountResetRequired = previousApiServer !== result.effectiveApiServer;
      if (accountResetRequired) {
        this.clearAccountPollTimer();
        this.clearAccountOptionsPollTimer();
        this.clearAddressBookPollTimer();
        this.accountOidcActive = false;
        this.accountOidcOpenedUrl = '';
        this.accountLoginProviders = [];
      }
      this.apiServer = result.effectiveApiServer;
      this.refreshAccountState(!accountResetRequired);
      this.refreshDirectorySnapshot();
      if (accountResetRequired && !this.accountState.loggedIn) {
        this.loadAccountLoginOptions();
      }
    } finally {
      this.serverSaving = false;
    }
  }

  private refreshDirectorySnapshot(): void {
    if (!this.runtimeInitialized) {
      return;
    }
    const snapshot = new DirectorySnapshot();
    this.mainBridge.resetDirectoryMessage();
    snapshot.favorites = this.mainBridge.listFavorites();
    snapshot.recent = this.mainBridge.listRecentPeers();
    snapshot.addressBook = this.mainBridge.listAddressBookPeers();
    snapshot.lan = this.mainBridge.listLanPeers();
    snapshot.message = this.mainBridge.getDirectoryMessage();
    this.directorySnapshot = snapshot;
  }

  private directoryScanSnapshot(scanning: boolean, message: string): DirectorySnapshot {
    const snapshot = new DirectorySnapshot();
    snapshot.recent = this.directorySnapshot.recent.slice();
    snapshot.addressBook = this.directorySnapshot.addressBook.slice();
    snapshot.lan = this.directorySnapshot.lan.slice();
    snapshot.favorites = this.directorySnapshot.favorites.slice();
    snapshot.lanScanning = scanning;
    snapshot.message = message;
    return snapshot;
  }

  private scanLanPeers(): void {
    this.clearLanScanTimer();
    this.directorySnapshot = this.directoryScanSnapshot(true, '正在扫描局域网设备');
    if (!this.mainBridge.scanLan()) {
      this.directorySnapshot = this.directoryScanSnapshot(false, '无法启动局域网扫描');
      return;
    }
    this.lanScanTimer = setTimeout(() => {
      this.lanScanTimer = -1;
      this.refreshDirectorySnapshot();
    }, 3800) as number;
  }

  private clearLanScanTimer(): void {
    if (this.lanScanTimer < 0) {
      return;
    }
    clearTimeout(this.lanScanTimer);
    this.lanScanTimer = -1;
  }

  private setPeerFavorite(peerId: string, favorite: boolean): void {
    const previous = this.directorySnapshot;
    this.directorySnapshot = this.directorySnapshotWithFavorite(peerId, favorite);
    if (!this.mainBridge.setFavorite(peerId, favorite)) {
      this.directorySnapshot = previous;
      this.errorText = '无法更新收藏状态';
      return;
    }
    this.refreshDirectorySnapshot();
  }

  private copyPeerWithFavorite(source: PeerRecord, peerId: string, favorite: boolean): PeerRecord {
    const peer = new PeerRecord();
    peer.id = source.id;
    peer.username = source.username;
    peer.hostname = source.hostname;
    peer.platform = source.platform;
    peer.alias = source.alias;
    peer.source = source.source;
    peer.addressBookName = source.addressBookName;
    peer.tags = source.tags.slice();
    peer.online = source.online;
    peer.favorite = source.id === peerId ? favorite : source.favorite;
    return peer;
  }

  private copyPeerListWithFavorite(source: PeerRecord[], peerId: string, favorite: boolean): PeerRecord[] {
    const peers: PeerRecord[] = [];
    for (let index = 0; index < source.length; index += 1) {
      peers.push(this.copyPeerWithFavorite(source[index], peerId, favorite));
    }
    return peers;
  }

  private directorySnapshotWithFavorite(peerId: string, favorite: boolean): DirectorySnapshot {
    const snapshot = new DirectorySnapshot();
    snapshot.recent = this.copyPeerListWithFavorite(this.directorySnapshot.recent, peerId, favorite);
    snapshot.addressBook = this.copyPeerListWithFavorite(this.directorySnapshot.addressBook, peerId, favorite);
    snapshot.lan = this.copyPeerListWithFavorite(this.directorySnapshot.lan, peerId, favorite);
    snapshot.favorites = this.directorySnapshot.favorites.filter((item: string) => item !== peerId);
    if (favorite) {
      snapshot.favorites.push(peerId);
    }
    snapshot.lanScanning = this.directorySnapshot.lanScanning;
    snapshot.message = this.directorySnapshot.message;
    return snapshot;
  }

  private removeRecentPeer(peerId: string): void {
    if (!this.mainBridge.removeRecentPeer(peerId)) {
      this.errorText = '无法移除最近设备';
      return;
    }
    this.refreshDirectorySnapshot();
  }

  private updatePeerTarget(value: string): void {
    if (value !== this.peerTarget) {
      this.passwordDraft = '';
      this.rememberPassword = false;
    }
    this.peerTarget = value;
  }

  private launchPeer(peerId: string, kind: PeerLaunchKind): void {
    this.updatePeerTarget(peerId);
    this.preferences?.saveTarget(peerId);
    if (kind === 'view_camera') {
      this.connectCameraSession();
      return;
    }
    if (kind === 'view_only') {
      this.connectViewOnlySession();
      return;
    }
    if (kind === 'file_transfer') {
      this.openTransferWorkspace();
      return;
    }
    this.connectRemoteSession();
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
      let decoderCapabilityResponse: ESObject = JSON.parse(native.runtimeGetDecoderCapabilities());
      let decoderCapabilityRows: ESObject = decoderCapabilityResponse.capabilities;
      const decoderCapabilities = this.copyDecoderCapabilities(decoderCapabilityRows);
      if (!this.activeSessionId) {
        this.preferredCodec = this.resolvePreferredCodec(this.sessionDefaults.preferredCodec, decoderCapabilities);
      }
      this.decoderCapabilities = decoderCapabilities;
      this.serverConfig = this.mainBridge.loadServerConfig();
      this.refreshAccountState();
      this.errorText = '';
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'refreshNativeState failed: %{public}s', this.errorText);
    }
  }

  private nextSessionId(): string {
    return `hm-session-${Date.now().toString()}`;
  }

  private nextTransferSessionId(): string {
    this.transferSessionSequence = (this.transferSessionSequence + 1) % 0x100000000;
    const timestamp = Date.now().toString(16).padStart(12, '0').substring(-12);
    const suffix = this.transferSessionSequence.toString(16).padStart(12, '0');
    return `00000000-0000-4000-8000-${timestamp}${suffix}`.substring(0, 36);
  }

  private parseResponse(raw: string): ActionResponse {
    try {
      return JSON.parse(raw) as ActionResponse;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'parseResponse failed: %{public}s raw=%{public}s', String(error), raw);
      throw new Error(String(error));
    }
  }

  private beginConnectionAttempt(kind: PrimarySessionKind, target: string): void {
    this.clearConnectionTimeout();
    this.connectionAttemptKind = 'primary';
    this.lastConnectionKind = kind;
    this.connectionUiTarget = target;
    this.connectionUiPhase = 'connecting';
    this.connectionUiMessage = kind === 'view_camera'
      ? '正在协商摄像头会话，成功后再进入预览。'
      : (kind === 'view_only'
        ? '正在建立只观看会话，不会发送键鼠输入。'
        : '正在建立安全连接，成功后再进入远控。');
  }

  private beginTransferConnectionAttempt(target: string): void {
    this.clearConnectionTimeout();
    this.connectionAttemptKind = 'file_transfer';
    this.connectionUiTarget = target;
    this.connectionUiPhase = 'connecting';
    this.connectionUiMessage = this.transferManager.getStatusMessage();
    this.transferConnectionPending = true;
  }

  private clearConnectionTimeout(): void {
    if (this.connectionTimeoutId < 0) {
      return;
    }
    clearTimeout(this.connectionTimeoutId);
    this.connectionTimeoutId = -1;
  }

  private scheduleConnectionTimeout(): void {
    this.clearConnectionTimeout();
    this.connectionTimeoutId = setTimeout(() => {
      this.connectionTimeoutId = -1;
      if (this.connectionUiPhase === 'connecting' || this.connectionUiPhase === 'authenticating') {
        this.failConnectionAttempt('连接超时。请确认远端在线、网络可用后重试。');
      }
    }, CONNECTION_TIMEOUT_MS) as number;
  }

  private failConnectionAttempt(message: string): void {
    const normalizedMessage = message.trim().length > 0 ? message.trim() : '连接未完成';
    this.clearConnectionTimeout();
    this.connectionUiPhase = 'failed';
    this.connectionUiMessage = normalizedMessage;
    this.errorText = normalizedMessage;
    if (this.connectionAttemptKind === 'file_transfer') {
      this.transferConnectionPending = false;
      this.closeTransferSession(true, true);
      return;
    }
    void this.closeSession(normalizedMessage, true);
  }

  private cancelConnectionAttempt(): void {
    const attemptKind = this.connectionAttemptKind;
    this.clearConnectionTimeout();
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    if (attemptKind === 'file_transfer') {
      this.transferConnectionPending = false;
      this.closeTransferSession();
      return;
    }
    void this.closeSession('已取消连接');
  }

  private retryConnectionAttempt(): void {
    const target = this.connectionUiTarget.trim();
    if (target.length === 0) {
      this.dismissConnectionAttempt();
      return;
    }
    this.peerTarget = target;
    if (this.connectionAttemptKind === 'file_transfer') {
      void this.openTransferWorkspace();
      return;
    }
    void this.connectSession(this.lastConnectionKind);
  }

  private dismissConnectionAttempt(): void {
    this.clearConnectionTimeout();
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    this.connectionAttemptKind = 'primary';
  }

  private async connectRemoteSession(): Promise<void> {
    await this.connectSession('remote_control');
  }

  private async connectCameraSession(): Promise<void> {
    await this.connectSession('view_camera');
  }

  private async connectViewOnlySession(): Promise<void> {
    await this.connectSession('view_only');
  }

  private async connectSession(kind: PrimarySessionKind): Promise<void> {
    if (this.sessionCloseInFlight) {
      return;
    }
    if (!this.runtimeInitialized) {
      this.initializeRuntime();
    }
    const target = this.peerTarget.trim();
    if (target.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    this.peerTarget = target;
    this.preferences?.saveTarget(target);
    if (this.activeSessionId.length > 0) {
      await this.closeSession('正在切换会话');
    }
    await this.applySessionFullscreen(false, true);
    this.beginConnectionAttempt(kind, target);
    this.activeSessionKind = kind;
    this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
    this.clipboardSyncEnabled = this.activeSessionDefaults.clipboardEnabled;
    this.preferredCodec = this.resolvePreferredCodec(
      this.activeSessionDefaults.preferredCodec,
      this.decoderCapabilities,
    );
    this.remoteInteractionReady = false;
    this.syncClipboardController();
    this.syncInputInterceptor();
    this.errorText = '';
    this.connectionSummary = kind === 'view_camera'
      ? '正在连接远端摄像头...'
      : (kind === 'view_only' ? '正在连接远端屏幕（只观看）...' : '正在建立远控连接...');
    this.sessionMessage = kind === 'view_camera'
      ? '正在连接摄像头'
      : (kind === 'view_only' ? '正在连接远端屏幕' : '正在连接远端');
    hilog.info(DOMAIN, TAG, 'connectSession kind=%{public}s target=%{public}s', kind, target);
    this.showTransferWorkspace = false;
    this.showPreviewModal = false;
    this.performanceTuningApplied = false;
    this.resetPreviewState();
    const connectionGeneration = this.connectionGeneration + 1;
    this.connectionGeneration = connectionGeneration;
    const sessionCreated = await this.createSession(target, kind);
    if (connectionGeneration !== this.connectionGeneration) {
      return;
    }
    if (!sessionCreated) {
      this.failConnectionAttempt(this.errorText || '无法创建连接会话');
      return;
    }
    // Set the codec preference before the first LoginRequest is created.  The
    // peer chooses its encoder from that request; waiting for peer_info means
    // the default (often VP9) may already be active and can leave the first
    // frames black while the later preference update takes effect.
    this.applyCodecPreference();
    const sessionStarted = await this.startSession();
    if (connectionGeneration !== this.connectionGeneration || !sessionStarted) {
      if (connectionGeneration === this.connectionGeneration) {
        this.failConnectionAttempt(this.errorText || '无法启动连接');
      }
      return;
    }
    this.connectionUiPhase = 'connecting';
    this.connectionUiMessage = '正在等待远端响应；可随时取消。';
    this.scheduleConnectionTimeout();
    this.publishDataTransferChanged();
    if (kind === 'remote_control') {
      this.refreshRemoteAudioState();
      this.startRemoteAudioPolling();
    } else {
      this.closeRemoteAudio();
    }
    this.startPolling();
    void this.pollSessionEvents();
  }

  private async createSession(target: string, kind: PrimarySessionKind): Promise<boolean> {
    try {
      const response = this.nativeSessionBridge.addSession(this.nextSessionId(), target, {
        password: '',
        forceRelay: false,
        isFileTransfer: false,
        isViewCamera: kind === 'view_camera',
        isViewOnly: kind === 'view_only',
      });
      this.updateSessionState(response);
      if (!response.ok || this.activeSessionId.length === 0) {
        return false;
      }
      if (kind === 'view_camera') {
        return true;
      }
      const policy = this.nativeSessionBridge.setViewOnly(
        this.activeSessionId,
        kind === 'view_only',
      );
      this.updateSessionState(policy);
      return policy.ok;
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'createSession failed target=%{public}s error=%{public}s', target, this.errorText);
      return false;
    }
  }

  private async startSession(): Promise<boolean> {
    if (!this.activeSessionId) {
      return false;
    }
    try {
      const response = this.nativeSessionBridge.startSession(this.activeSessionId);
      this.updateSessionState(response);
      return response.ok && this.activeSessionId.length > 0;
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'startSession failed sessionId=%{public}s error=%{public}s', this.activeSessionId, this.errorText);
      return false;
    }
  }

  private openPasswordDialog(kind: PasswordSessionKind = 'primary', message: string = ''): void {
    if (this.passwordDialogVisible) {
      return;
    }
    this.passwordSessionKind = kind;
    this.passwordDraft = '';
    this.passwordDialogVisible = true;
    if (kind === 'file_transfer') {
      this.transferRootStatus = message.length > 0 ? message : '文件传输等待密码验证';
      this.clearConnectionTimeout();
      this.connectionAttemptKind = 'file_transfer';
      this.connectionUiPhase = 'awaiting_password';
      this.connectionUiMessage = this.transferRootStatus;
    } else {
      this.clearConnectionTimeout();
      this.connectionUiPhase = 'awaiting_password';
      this.connectionUiMessage = message.length > 0 ? message : '请输入远端设备密码后继续连接。';
      this.sessionPhase = 'awaiting_password';
      this.sessionMessage = '等待输入密码';
      this.connectionSummary = '等待密码验证';
      void this.applySessionFullscreen(false, true);
    }
    this.clearPasswordTimeout();
    this.passwordTimeoutId = setTimeout(() => {
      if (this.passwordDialogVisible) {
        this.passwordDialogVisible = false;
        if (this.passwordSessionKind === 'file_transfer') {
          this.failConnectionAttempt('文件传输密码输入超时');
        } else {
          this.handleRemoteDisconnect('密码输入超时');
        }
      }
    }, PASSWORD_TIMEOUT_MS) as number;
  }

  private clearPasswordTimeout(): void {
    if (this.passwordTimeoutId >= 0) {
      clearTimeout(this.passwordTimeoutId);
      this.passwordTimeoutId = -1;
    }
  }

  private async submitPassword(passwordInput?: string, rememberPasswordInput?: boolean): Promise<void> {
    if (this.passwordSessionKind === 'primary' && !this.activeSessionId) {
      return;
    }
    if (this.passwordSessionKind === 'file_transfer' && !this.transferManager.isReady()) {
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
    this.passwordDraft = '';
    this.passwordDialogVisible = false;
    this.clearPasswordTimeout();
    try {
      if (this.passwordSessionKind === 'file_transfer') {
        if (!this.transferManager.login(password, this.rememberPassword)) {
          this.errorText = '文件传输密码提交失败';
          return;
        }
        this.transferRootStatus = '正在验证文件传输密码';
        this.connectionAttemptKind = 'file_transfer';
        this.connectionUiPhase = 'authenticating';
        this.connectionUiMessage = this.transferRootStatus;
        this.scheduleConnectionTimeout();
        return;
      }
      this.connectionUiPhase = 'authenticating';
      this.connectionUiMessage = '密码已提交，正在等待远端验证。';
      this.scheduleConnectionTimeout();
      const response = this.nativeSessionBridge.login(this.activeSessionId, password, this.rememberPassword);
      hilog.info(DOMAIN, TAG, 'submitPassword sessionId=%{public}s remember=%{public}s ok=%{public}s', this.activeSessionId, String(this.rememberPassword), String(response.ok));
      this.updateSessionState(response);
      if (!response.ok) {
        this.failConnectionAttempt(response.message ?? '密码提交失败');
      }
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'submitPassword failed sessionId=%{public}s error=%{public}s', this.activeSessionId, this.errorText);
      if (this.passwordSessionKind === 'primary') {
        this.failConnectionAttempt(this.errorText);
      }
    }
  }

  private cancelPasswordDialog(): void {
    const kind = this.passwordSessionKind;
    this.passwordDialogVisible = false;
    this.clearPasswordTimeout();
    if (kind === 'file_transfer') {
      this.clearConnectionTimeout();
      this.connectionUiPhase = 'idle';
      this.connectionUiMessage = '';
      this.transferConnectionPending = false;
      this.closeTransferSession();
      return;
    }
    this.closeSession('已取消密码输入');
  }

  private async closeSession(reason?: string, preserveConnectionFailure: boolean = false): Promise<void> {
    if (this.sessionCloseInFlight) {
      return;
    }
    this.sessionCloseInFlight = true;
    try {
      this.connectionGeneration += 1;
      this.clearConnectionTimeout();
      if (!preserveConnectionFailure) {
        this.connectionUiPhase = 'idle';
        this.connectionUiMessage = '';
      }
      const sessionId = this.activeSessionId;
      hilog.info(DOMAIN, TAG, 'closeSession sessionId=%{public}s reason=%{public}s', sessionId, reason ?? '');
      this.releaseSoftKeyboardKeys();
      if (this.relativeMouseMode && sessionId) {
        this.syncRelativeMouseMode(false);
      }
      this.remoteInteractionReady = false;
      this.stopInputInterceptor();
      this.clipboardController?.reset();
      this.clearPreviewKeyboardBlurTimer();
      this.previewKeyboardCaptureFocused = false;
      this.setSessionKeyboardEntered(false);
      await this.applySessionFullscreen(false, true);
      this.unregisterFoldHoverListeners();
      this.passwordDialogVisible = false;
      this.showPreviewModal = false;
      this.clearPasswordTimeout();
      this.inputController?.releasePressedButtons();
      this.clearSurfaceBinding();
      this.stopPolling();
      this.closeRemoteAudio();
      this.resetPreviewState();
      this.connectionSummary = preserveConnectionFailure
        ? `连接失败 · ${this.connectionUiTarget || this.peerTarget}`
        : '未连接';
      if (reason) {
        this.sessionMessage = reason;
      }
      if (!sessionId) {
        this.chatStore.clear();
        this.refreshChatState();
        this.sessionPhase = preserveConnectionFailure ? 'failed' : 'idle';
        this.activeSessionKind = 'remote_control';
        this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
        this.applySessionDefaultsToIdleState(this.decoderCapabilities);
        this.refreshDirectorySnapshot();
        return;
      }
      try {
        const response = this.nativeSessionBridge.closeSession(sessionId);
        this.updateSessionState(response);
      } catch (error) {
        this.errorText = String(error);
      } finally {
        this.chatStore.clear();
        this.refreshChatState();
        this.activeSessionId = '';
        this.activeCoreSessionId = '';
        this.sessionPhase = preserveConnectionFailure ? 'failed' : 'idle';
        this.activeSessionKind = 'remote_control';
        this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
        this.applySessionDefaultsToIdleState(this.decoderCapabilities);
        this.refreshDirectorySnapshot();
        this.publishDataTransferChanged();
      }
    } finally {
      this.sessionCloseInFlight = false;
    }
  }

  private handleRemoteDisconnect(message: string): void {
    if (this.sessionCloseInFlight) {
      return;
    }
    hilog.warn(DOMAIN, TAG, 'handleRemoteDisconnect sessionId=%{public}s message=%{public}s', this.activeSessionId, message);
    this.failConnectionAttempt(message);
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
    this.previewTransformMode = false;
    this.previewUserScale = 1;
    this.previewUserOffsetX = 0;
    this.previewUserOffsetY = 0;
    this.previewUserRotation = 0;
    this.softKeyboardVisible = false;
    this.softKeyboardDockTop = false;
    this.clearSoftKeyboardKeyState();
    this.previewGestureStartScale = 1;
    this.previewGestureStartOffsetX = 0;
    this.previewGestureStartOffsetY = 0;
    this.previewGestureStartRotation = 0;
    this.androidNavigationDragStartX = 0;
    this.androidNavigationDragStartY = 0;
    this.remoteKeyboardPermissionAllowed = true;
    this.isFoldHoverMode = false;
    this.foldHoverUpperHeight = 0;
    this.foldHoverCreaseHeight = 0;
    this.lastAppliedDisplay = -1;
    this.lastAppliedVideoWidth = 0;
    this.lastAppliedVideoHeight = 0;
    this.peerPlatform = '';
    this.peerVersion = '';
    this.peerDisplays = [];
    this.supportedResolutions = [];
    this.previewSurfaceVisible = false;
    this.previewSurfaceGeneration = 0;
    this.previewSurfaceSetupInFlight = false;
    this.previewSurfaceSetupGeneration = -1;
    this.pendingPreviewPeerInfo = undefined;
    this.releasePreviewFramePixelMap();
    this.renderFpsText = 'FPS --';
    this.toolbarRenderStats = {
      fps: 0,
      totalFrames: 0,
      lastFrameAgeMs: 0,
      hasRenderedFrame: false,
    };
    this.qualityTelemetry = {
      fps: '--',
      delay: '--',
      codec: '--',
      speed: '--',
      targetBitrate: '--',
      chroma: '--',
    };
    this.codecPreferenceApplied = false;
    this.lastRenderTotalFrames = 0;
    this.renderStallFirstDetectedAt = 0;
    this.lastRenderRecoveryAt = 0;
    this.renderStallRecoveryAttempts = 0;
    this.relativeMouseMode = this.activeSessionDefaults.relativeMouseMode;
    this.resetRemoteCursorVisualState();
    this.cursorModel.reset();
    this.remoteCursorOptionApplied = false;
    this.remoteCursorOptionLastAppliedAt = 0;
    this.remoteCursorOptionFirstAppliedAt = 0;
    this.remoteCursorEnableAttempts = 0;
    this.relativeModeActivatedAt = 0;
    this.remoteCursorEventLogCounter = 0;
    this.chatDraft = '';
    this.overlayState.close();
    this.activeOverlayPanel = 'home';
    this.selectedQualityPreset = this.qualityPresetFor(this.activeSessionDefaults);
    this.customQualityDraft = this.activeSessionDefaults.customQuality;
    this.customFpsDraft = this.activeSessionDefaults.customFps;
    this.remoteAudioState = this.unavailableRemoteAudioState();
    this.remoteAudioDefaultApplied = false;
    this.isMiniBarExpanded = this.activeSessionDefaults.toolbarExpanded;
    this.initialDisplayCommandIssued = false;
    this.pendingDisplayIndex = -1;
    this.pendingResolutionDisplay = -1;
    this.pendingResolutionWidth = 0;
    this.pendingResolutionHeight = 0;
    this.refreshQualitySummary();
  }

  private refreshChatState(): void {
    this.chatRevision += 1;
  }

  private chatMessages(): ChatMessage[] {
    return this.chatRevision >= 0 ? this.chatStore.messages() : [];
  }

  private openOverlayPanel(panel: SessionOverlayPanel): void {
    if (!this.overlayState.open(panel)) {
      return;
    }
    this.hideSoftKeyboard();
    this.previewKeyboardCaptureFocused = false;
    this.syncInputInterceptor();
    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.activeOverlayPanel = this.overlayState.getActivePanel();
    });
  }

  private closeOverlayPanel(): void {
    if (!this.overlayState.close()) {
      return;
    }
    this.syncInputInterceptor();
    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.activeOverlayPanel = 'home';
    });
    setTimeout(() => this.requestPreviewInputFocus(), 320);
  }

  private isOverlayPanelOpen(panel: SessionOverlayPanel): boolean {
    return this.activeOverlayPanel === panel;
  }

  private openChatDrawer(): void {
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    this.chatStore.markRead();
    this.refreshChatState();
    this.openOverlayPanel('chat');
  }

  private unavailableRemoteAudioState(): RemoteAudioState {
    return {
      available: false,
      muted: false,
      rendererActive: false,
      errorText: '',
    };
  }

  private isRemoteControlSessionActive(): boolean {
    return this.activeSessionKind === 'remote_control' && this.activeSessionId.length > 0;
  }

  private isRemoteViewerSessionActive(): boolean {
    return this.activeSessionKind === 'view_only' && this.activeSessionId.length > 0;
  }

  private isRemoteDesktopSessionActive(): boolean {
    return this.isRemoteControlSessionActive() || this.isRemoteViewerSessionActive();
  }

  private softKeyboardAvailable(): boolean {
    return !this.isPcDevice()
      && this.isRemoteControlSessionActive()
      && this.showPreviewModal
      && !this.isFoldHoverMode
      && !this.showTransferWorkspace;
  }

  private toggleSoftKeyboard(): void {
    if (!this.softKeyboardAvailable()) {
      this.hideSoftKeyboard();
      return;
    }
    if (this.softKeyboardVisible) {
      this.hideSoftKeyboard();
      setTimeout(() => this.requestPreviewInputFocus(), 80);
      return;
    }
    this.softKeyboardVisible = true;
  }

  private moveSoftKeyboardToOtherEdge(): void {
    this.softKeyboardDockTop = !this.softKeyboardDockTop;
  }

  private sendSoftKeyboardKey(
    name: string,
    down: boolean,
    alt: boolean,
    ctrl: boolean,
    shift: boolean,
    command: boolean,
  ): void {
    if (!this.isRemoteControlSessionActive()) {
      this.clearSoftKeyboardKeyState();
      return;
    }
    if (down && !this.remoteInteractionReady) {
      return;
    }
    if (!down && this.softKeyboardPressedKeys.indexOf(name) < 0) {
      return;
    }
    const payload = new RustDeskKeyPayload(name, down);
    payload.alt = alt;
    payload.ctrl = ctrl;
    payload.shift = shift;
    payload.command = command;
    if (this.sendKeyPayloadObject(payload)) {
      this.rememberSoftKeyboardKey(name, down, alt, ctrl, shift, command);
    }
  }

  private isSoftKeyboardModifier(name: string): boolean {
    return name === 'VK_CONTROL' || name === 'VK_MENU' || name === 'VK_SHIFT' || name === 'Meta';
  }

  private rememberSoftKeyboardKey(
    name: string,
    down: boolean,
    alt: boolean,
    ctrl: boolean,
    shift: boolean,
    command: boolean,
  ): void {
    this.softKeyboardAltActive = alt;
    this.softKeyboardCtrlActive = ctrl;
    this.softKeyboardShiftActive = shift;
    this.softKeyboardCommandActive = command;
    if (name === 'VK_CONTROL') {
      this.softKeyboardCtrlActive = down;
    } else if (name === 'VK_MENU') {
      this.softKeyboardAltActive = down;
    } else if (name === 'VK_SHIFT') {
      this.softKeyboardShiftActive = down;
    } else if (name === 'Meta') {
      this.softKeyboardCommandActive = down;
    }
    const index = this.softKeyboardPressedKeys.indexOf(name);
    if (down && index < 0) {
      this.softKeyboardPressedKeys.push(name);
    } else if (!down && index >= 0) {
      this.softKeyboardPressedKeys.splice(index, 1);
    }
  }

  private releaseSoftKeyboardKey(name: string): void {
    const payload = new RustDeskKeyPayload(name, false);
    payload.alt = this.softKeyboardAltActive;
    payload.ctrl = this.softKeyboardCtrlActive;
    payload.shift = this.softKeyboardShiftActive;
    payload.command = this.softKeyboardCommandActive;
    this.sendKeyPayloadObject(payload);
    this.rememberSoftKeyboardKey(
      name,
      false,
      this.softKeyboardAltActive,
      this.softKeyboardCtrlActive,
      this.softKeyboardShiftActive,
      this.softKeyboardCommandActive,
    );
  }

  private releaseSoftKeyboardKeys(): void {
    if (!this.isRemoteControlSessionActive()) {
      this.clearSoftKeyboardKeyState();
      return;
    }
    const pressedKeys = this.softKeyboardPressedKeys.slice();
    for (let index = 0; index < pressedKeys.length; index += 1) {
      const name = pressedKeys[index];
      if (!this.isSoftKeyboardModifier(name)) {
        this.releaseSoftKeyboardKey(name);
      }
    }
    const modifiers: string[] = ['VK_CONTROL', 'VK_MENU', 'VK_SHIFT', 'Meta'];
    for (let index = 0; index < modifiers.length; index += 1) {
      const name = modifiers[index];
      if (this.softKeyboardPressedKeys.indexOf(name) >= 0) {
        this.releaseSoftKeyboardKey(name);
      }
    }
    this.clearSoftKeyboardKeyState();
  }

  private clearSoftKeyboardKeyState(): void {
    this.softKeyboardPressedKeys = [];
    this.softKeyboardAltActive = false;
    this.softKeyboardCtrlActive = false;
    this.softKeyboardShiftActive = false;
    this.softKeyboardCommandActive = false;
  }

  private hideSoftKeyboard(): void {
    if (this.softKeyboardVisible) {
      this.releaseSoftKeyboardKeys();
    }
    this.softKeyboardVisible = false;
  }

  private softKeyboardWidth(): number {
    if (this.previewViewWidth <= 0) {
      return 320;
    }
    return Math.max(280, Math.min(this.previewViewWidth - 16, 760));
  }

  private softKeyboardOffsetY(): number {
    if (this.softKeyboardDockTop || this.previewViewHeight <= 0) {
      return 12;
    }
    return Math.max(12, this.previewViewHeight - REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT - 16);
  }

  private sendClipboardText(content: string): boolean {
    if (!this.remoteInteractionReady || !this.isRemoteControlSessionActive()) {
      return false;
    }
    const response = this.nativeSessionBridge.sendClipboard(this.activeSessionId, content);
    if (!response.ok) {
      this.logRelativeDebug('clipboard_local', `native failed=${String(response.message ?? '')}`);
    }
    return response.ok;
  }

  private syncClipboardController(): void {
    if (this.clipboardSyncEnabled && this.pageVisible && this.remoteInteractionReady && this.isRemoteControlSessionActive()) {
      this.clipboardController?.start();
      return;
    }
    this.clipboardController?.stop();
  }

  private shouldEnableInputInterceptor(): boolean {
    return this.pageVisible &&
      this.remoteInteractionReady &&
      this.isRemoteControlSessionActive() &&
      this.showPreviewModal &&
      !this.showTransferWorkspace &&
      !this.passwordDialogVisible &&
      this.overlayState.getActivePanel() === 'home';
  }

  private syncInputInterceptor(): void {
    if (!this.shouldEnableInputInterceptor()) {
      this.stopInputInterceptor();
      return;
    }
    if (this.inputInterceptorActive) {
      return;
    }
    try {
      const response = JSON.parse(native.inputInterceptorStart()) as InputInterceptorResponse;
      this.inputInterceptorActive = response.active === true;
      this.logRelativeDebug(
        'input_interceptor',
        `start ok=${response.ok} active=${this.inputInterceptorActive} result=${String(response.result ?? '')} message=${String(response.message ?? '')}`,
      );
    } catch (error) {
      this.inputInterceptorActive = false;
      this.logRelativeDebug('input_interceptor', `start failed=${String(error)}`);
    }
  }

  private stopInputInterceptor(): void {
    if (!this.inputInterceptorActive) {
      return;
    }
    this.inputController?.releaseInterceptedKeys();
    try {
      const response = JSON.parse(native.inputInterceptorStop()) as InputInterceptorResponse;
      this.inputInterceptorActive = response.active === true;
      this.logRelativeDebug(
        'input_interceptor',
        `stop ok=${response.ok} active=${this.inputInterceptorActive} result=${String(response.result ?? '')} message=${String(response.message ?? '')}`,
      );
    } catch (error) {
      this.logRelativeDebug('input_interceptor', `stop failed=${String(error)}`);
    }
  }

  private pollInputInterceptorEvents(): void {
    if (!this.inputInterceptorActive) {
      return;
    }
    try {
      const response = JSON.parse(native.inputInterceptorPollEvents(32)) as InputInterceptorResponse;
      this.inputInterceptorActive = response.active === true;
      const events = response.events ?? [];
      for (let index = 0; index < events.length; index++) {
        const event = events[index];
        if (event.type === 'key') {
          this.getInputController().handleInterceptedKeyEvent(event.keyCode, event.action);
        }
      }
    } catch (error) {
      this.logRelativeDebug('input_interceptor', `poll failed=${String(error)}`);
    }
  }

  private handlePreviewKeyboardFocus(): void {
    this.clearPreviewKeyboardBlurTimer();
    this.previewKeyboardCaptureFocused = true;
    this.syncInputInterceptor();
  }

  private handlePreviewKeyboardBlur(): void {
    this.clearPreviewKeyboardBlurTimer();
    this.previewKeyboardBlurTimer = setTimeout(() => {
      this.previewKeyboardBlurTimer = -1;
      this.previewKeyboardCaptureFocused = false;
      this.syncInputInterceptor();
    }, 1) as number;
  }

  private clearPreviewKeyboardBlurTimer(): void {
    if (this.previewKeyboardBlurTimer >= 0) {
      clearTimeout(this.previewKeyboardBlurTimer);
      this.previewKeyboardBlurTimer = -1;
    }
  }

  private isRemoteAudioSessionActive(): boolean {
    return this.isRemoteControlSessionActive() &&
      this.sessionPhase !== 'idle' &&
      this.sessionPhase !== 'closed' &&
      this.sessionPhase !== 'start_failed' &&
      this.sessionPhase !== 'blocked_transport_bootstrap' &&
      this.sessionPhase !== 'invalid_core_session_id' &&
      this.sessionPhase !== 'reconnect_failed';
  }

  private refreshRemoteAudioState(): void {
    if (!this.isRemoteAudioSessionActive()) {
      this.closeRemoteAudio();
      return;
    }
    let state = this.nativeSessionBridge.getRemoteAudioState(this.activeSessionId);
    if (state.available && !this.remoteAudioDefaultApplied) {
      this.remoteAudioDefaultApplied = true;
      const shouldMute = !this.activeSessionDefaults.audioEnabled;
      if (state.muted !== shouldMute) {
        this.nativeSessionBridge.setRemoteAudioMuted(this.activeSessionId, shouldMute);
        state = this.nativeSessionBridge.getRemoteAudioState(this.activeSessionId);
      }
    }
    this.remoteAudioState = state;
  }

  private startRemoteAudioPolling(): void {
    if (!this.isRemoteAudioSessionActive() || this.remoteAudioPollTimer >= 0) {
      return;
    }
    this.remoteAudioPollTimer = setInterval(() => this.refreshRemoteAudioState(), REMOTE_AUDIO_POLL_INTERVAL_MS) as number;
  }

  private stopRemoteAudioPolling(): void {
    if (this.remoteAudioPollTimer < 0) {
      return;
    }
    clearInterval(this.remoteAudioPollTimer);
    this.remoteAudioPollTimer = -1;
  }

  private closeRemoteAudio(): void {
    this.stopRemoteAudioPolling();
    this.remoteAudioDefaultApplied = false;
    this.remoteAudioState = this.unavailableRemoteAudioState();
  }

  private setRemoteAudioEnabled(enabled: boolean): void {
    if (!this.isRemoteAudioSessionActive()) {
      return;
    }
    if (!this.nativeSessionBridge.setRemoteAudioMuted(this.activeSessionId, !enabled)) {
      this.errorText = '无法切换远端音频状态';
      return;
    }
    this.refreshRemoteAudioState();
  }

  private openDisplaySheet(): void {
    if (!this.isRemoteDesktopSessionActive()) {
      this.sessionMessage = '请先建立远程桌面连接';
      return;
    }
    this.openOverlayPanel('display');
  }

  private openQualitySheet(): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    this.selectedQualityPreset = this.sessionDisplayController.getImageQuality();
    this.customQualityDraft = this.sessionDisplayController.getCustomImageQuality();
    this.customFpsDraft = this.sessionDisplayController.getCustomFps();
    this.openOverlayPanel('quality');
  }

  private async openTransferWorkspace(): Promise<void> {
    if (!this.runtimeInitialized) {
      this.initializeRuntime();
    }
    const target = this.peerTarget.trim();
    if (target.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    this.peerTarget = target;
    this.preferences?.saveTarget(target);
    if (this.transferManager.isReady()
      && this.transferSessionTarget.length > 0
      && this.transferSessionTarget !== target) {
      this.errorText = `已有 ${this.transferSessionTarget} 的文件传输会话，请先结束该会话再切换设备`;
      if (this.transferManager.canTransfer()) {
        this.showTransferWorkspace = true;
      }
      return;
    }
    if (!this.transferRoot) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const root = await this.downloadRootManager.acquire(context);
      if (!root) {
        this.transferRootStatus = '未能获得 DOWNLOAD 目录';
        this.errorText = this.transferRootStatus;
        return;
      }
      if (!this.verifyTransferRoot(root)) {
        return;
      }
      this.transferRoot = root;
      this.transferRootPath = root.path;
      this.preferences?.saveDownloadRootUri(root.uri);
      this.loadTransferLocalEntries();
    }
    if (this.transferManager.isReady()) {
      if (this.transferManager.canTransfer()) {
        this.transferConnectionPending = false;
        this.connectionUiPhase = 'idle';
        this.connectionUiMessage = '';
        this.showTransferWorkspace = true;
        this.syncTransferState();
        return;
      }
      this.beginTransferConnectionAttempt(target);
      this.startTransferPolling();
      this.scheduleConnectionTimeout();
      this.showTransferWorkspace = false;
      this.syncTransferState();
      return;
    }
    this.beginTransferConnectionAttempt(target);
    if (!this.transferManager.open(target, '', false, this.transferRoot)) {
      this.transferRootStatus = this.transferManager.getStatusMessage();
      this.failConnectionAttempt(this.transferRootStatus || '无法启动独立文件传输会话');
      return;
    }
    this.transferSessionTarget = target;
    this.startTransferPolling();
    this.scheduleConnectionTimeout();
    this.transferSessionReady = this.transferManager.canTransfer();
    this.transferConnectionStatus = this.transferManager.getStatusMessage();
    this.showTransferWorkspace = false;
    this.previewKeyboardCaptureFocused = false;
    this.syncInputInterceptor();
    this.syncTransferState();
    this.publishDataTransferChanged();
  }

  private closeTransferWorkspace(): void {
    if (!this.hasRunningTransferTask()) {
      this.closeTransferSession();
    } else {
      this.showTransferWorkspace = false;
    }
    setTimeout(() => this.requestPreviewInputFocus(), 80);
  }

  private hasRunningTransferTask(): boolean {
    for (let index = 0; index < this.transferItems.length; index += 1) {
      const state = this.transferItems[index].state;
      if (state === 'queued' || state === 'running' || state === 'awaiting_override') {
        return true;
      }
    }
    return false;
  }

  private verifyTransferRoot(root: DownloadRoot): boolean {
    const probeName = `rustdesk-transfer-gate-${Date.now()}.txt`;
    const probePath = this.downloadRootManager.buildChildPath(root.path, probeName);
    if (!probePath) {
      this.transferRootStatus = 'DOWNLOAD 路径无效';
      this.errorText = this.transferRootStatus;
      return false;
    }
    let created = false;
    try {
      const file = fileIo.openSync(probePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      created = true;
      fileIo.closeSync(file.fd);
      const localNames = fileIo.listFileSync(root.path);
      if (!this.containsFileName(localNames, probeName)) {
        this.transferRootStatus = 'ArkTS 无法列出 DOWNLOAD 探测文件';
        this.errorText = this.transferRootStatus;
        return false;
      }
      const response = JSON.parse(native.runtimeListLocalDir(root.path)) as RuntimeDirectoryResponse;
      if (!response.ok || !this.containsFileName(response.entries ?? [], probeName)) {
        this.transferRootStatus = response.message?.trim() || 'Rust 无法访问 DOWNLOAD 目录';
        this.errorText = this.transferRootStatus;
        return false;
      }
      this.transferRootStatus = 'DOWNLOAD 路径已通过 ArkTS 与 Rust 访问门禁';
      return true;
    } catch (error) {
      this.transferRootStatus = `DOWNLOAD 路径门禁失败：${String(error)}`;
      this.errorText = this.transferRootStatus;
      return false;
    } finally {
      if (created) {
        try {
          fileIo.unlinkSync(probePath);
        } catch (_) {
        }
      }
    }
  }

  private containsFileName(names: string[], expected: string): boolean {
    for (let index = 0; index < names.length; index += 1) {
      if (names[index] === expected) {
        return true;
      }
    }
    return false;
  }

  private loadTransferLocalEntries(): void {
    const root = this.transferRoot;
    if (!root) {
      this.transferLocalEntries = [];
      return;
    }
    const entries: LocalFileEntry[] = [];
    try {
      const names = fileIo.listFileSync(root.path);
      for (let index = 0; index < names.length; index += 1) {
        const name = names[index];
        const path = this.downloadRootManager.buildChildPath(root.path, name);
        if (!path) {
          continue;
        }
        const stat = fileIo.statSync(path);
        if (!stat.isFile()) {
          continue;
        }
        entries.push({ name, path, size: Number(stat.size) });
      }
    } catch (error) {
      this.errorText = `读取本地文件失败：${String(error)}`;
    }
    this.transferLocalEntries = entries;
    if (!this.hasLocalTransferEntry(this.selectedTransferLocalName)) {
      this.selectedTransferLocalName = '';
    }
  }

  private hasLocalTransferEntry(name: string): boolean {
    for (let index = 0; index < this.transferLocalEntries.length; index += 1) {
      if (this.transferLocalEntries[index].name === name) {
        return true;
      }
    }
    return false;
  }

  private startTransferPolling(): void {
    if (this.transferPollTimer >= 0) {
      return;
    }
    this.transferPollTimer = setInterval(() => this.pollTransferSession(), TRANSFER_POLL_INTERVAL_MS) as number;
  }

  private stopTransferPolling(): void {
    if (this.transferPollTimer < 0) {
      return;
    }
    clearInterval(this.transferPollTimer);
    this.transferPollTimer = -1;
  }

  private pollTransferSession(): void {
    if (this.transferPollInFlight || !this.transferManager.isReady()) {
      return;
    }
    this.transferPollInFlight = true;
    try {
      this.transferManager.poll();
      const passwordMessage = this.transferManager.consumePasswordRequest();
      if (passwordMessage !== undefined) {
        this.openPasswordDialog('file_transfer', passwordMessage);
      }
      this.syncTransferState();
      if (this.transferManager.canTransfer() && this.transferConnectionPending) {
        this.clearConnectionTimeout();
        this.transferConnectionPending = false;
        this.connectionUiPhase = 'idle';
        this.connectionUiMessage = '';
        this.showTransferWorkspace = true;
        this.previewKeyboardCaptureFocused = false;
        this.syncInputInterceptor();
      } else if (this.transferManager.hasFailed()) {
        this.failConnectionAttempt(this.transferManager.getStatusMessage());
      } else if (this.transferConnectionPending && this.connectionUiPhase === 'connecting') {
        this.connectionUiMessage = this.transferManager.getStatusMessage();
      }
      this.publishDataTransferChanged();
    } finally {
      this.transferPollInFlight = false;
    }
  }

  private syncTransferState(): void {
    this.transferItems = this.transferManager.snapshot();
    this.transferRemoteEntries = this.transferManager.getRemoteEntries();
    this.transferRemoteDirectory = this.transferManager.getRemoteDirectory();
    this.transferSessionReady = this.transferManager.canTransfer();
    this.transferConnectionStatus = this.transferManager.getStatusMessage();
    if (!this.hasRemoteTransferEntry(this.selectedTransferRemoteName)) {
      this.selectedTransferRemoteName = '';
    }
  }

  private hasRemoteTransferEntry(name: string): boolean {
    for (let index = 0; index < this.transferRemoteEntries.length; index += 1) {
      const entry = this.transferRemoteEntries[index];
      if (entry.name === name && RemoteFilePath.isFileType(entry.entry_type)) {
        return true;
      }
    }
    return false;
  }

  private selectTransferLocal(name: string): void {
    this.selectedTransferLocalName = name;
  }

  private selectTransferRemote(name: string): void {
    this.selectedTransferRemoteName = name;
  }

  private uploadSelectedTransferFile(): void {
    const local = this.findLocalTransferEntry(this.selectedTransferLocalName);
    if (!local || !this.transferManager.isReady()) {
      return;
    }
    const remotePath = this.joinRemoteTransferPath(this.transferRemoteDirectory, local.name);
    if (this.transferManager.upload(local.path, remotePath, local.size)) {
      this.syncTransferState();
      this.publishDataTransferChanged();
    }
  }

  private downloadSelectedTransferFile(): void {
    const remote = this.findRemoteTransferEntry(this.selectedTransferRemoteName);
    const root = this.transferRoot;
    if (!remote || !root || !RemoteFilePath.isFileType(remote.entry_type) || !this.transferManager.isReady()) {
      return;
    }
    const localPath = this.downloadRootManager.buildChildPath(root.path, remote.name);
    if (!localPath) {
      this.errorText = '本地下载文件名无效';
      return;
    }
    const remotePath = this.joinRemoteTransferPath(this.transferRemoteDirectory, remote.name);
    if (this.transferManager.download(remotePath, localPath, remote.size)) {
      this.syncTransferState();
      this.publishDataTransferChanged();
    }
  }

  private findLocalTransferEntry(name: string): LocalFileEntry | undefined {
    for (let index = 0; index < this.transferLocalEntries.length; index += 1) {
      if (this.transferLocalEntries[index].name === name) {
        return this.transferLocalEntries[index];
      }
    }
    return undefined;
  }

  private findRemoteTransferEntry(name: string): RemoteFileEntry | undefined {
    for (let index = 0; index < this.transferRemoteEntries.length; index += 1) {
      if (this.transferRemoteEntries[index].name === name) {
        return this.transferRemoteEntries[index];
      }
    }
    return undefined;
  }

  private joinRemoteTransferPath(directory: string, name: string): string {
    return RemoteFilePath.join(directory, name);
  }

  private openTransferRemoteDirectory(name: string): void {
    const remote = this.findRemoteTransferEntry(name);
    if (!remote || !RemoteFilePath.isDirectoryType(remote.entry_type)) {
      return;
    }
    if (this.transferManager.readRemoteDirectory(this.joinRemoteTransferPath(this.transferRemoteDirectory, remote.name))) {
      this.selectedTransferRemoteName = '';
    }
  }

  private openTransferParentDirectory(): void {
    const parent = RemoteFilePath.parent(this.transferRemoteDirectory);
    if (this.transferManager.readRemoteDirectory(parent)) {
      this.selectedTransferRemoteName = '';
    }
  }

  private resolveTransferOverride(id: number, needOverride: boolean): void {
    if (this.transferManager.resolveOverride(id, needOverride)) {
      this.syncTransferState();
      this.publishDataTransferChanged();
    }
  }

  private cancelTransfer(id: number): void {
    if (this.transferManager.cancel(id)) {
      this.syncTransferState();
      this.publishDataTransferChanged();
    }
  }

  private cancelAllTransfers(): void {
    const items = this.transferManager.snapshot();
    for (let index = 0; index < items.length; index += 1) {
      const item = items[index];
      if (item.state === 'queued' || item.state === 'running' || item.state === 'awaiting_override') {
        this.transferManager.cancel(item.id);
      }
    }
    this.syncTransferState();
  }

  private closeTransferSession(preserveDownloadRoot: boolean = false,
    preserveConnectionFailure: boolean = false): void {
    if (!preserveConnectionFailure && this.connectionAttemptKind === 'file_transfer') {
      this.clearConnectionTimeout();
      this.connectionUiPhase = 'idle';
      this.connectionUiMessage = '';
      this.connectionAttemptKind = 'primary';
    }
    this.showTransferWorkspace = false;
    this.transferSessionReady = false;
    this.transferConnectionPending = false;
    this.cancelAllTransfers();
    this.stopTransferPolling();
    this.transferManager.close();
    this.transferSessionTarget = '';
    this.transferRemoteEntries = [];
    this.transferItems = [];
    this.selectedTransferLocalName = '';
    this.selectedTransferRemoteName = '';
    if (!preserveDownloadRoot) {
      this.transferRoot = undefined;
      this.transferRootPath = '';
      this.transferLocalEntries = [];
      this.transferRootStatus = '选择下载位置后可传输';
    }
    this.transferConnectionStatus = '文件传输未连接';
    this.refreshDirectorySnapshot();
    this.publishDataTransferChanged();
  }

  private publishDataTransferBinding(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.emit(DATA_TRANSFER_BACKGROUND_BIND_EVENT, new DataTransferBackgroundBinding({
      isRemoteSessionActive: () => this.activeSessionId.length > 0,
      isFileTransferSessionActive: () => this.transferManager.isReady(),
      getSessionLabel: () => this.transferManager.isReady() ? this.transferSessionTarget : this.peerTarget,
      getTransfers: () => this.transferManager.snapshot(),
      cancelAllNativeTransfers: () => this.cancelAllTransfers(),
      closeRemoteSession: () => { void this.closeSession('数据传输长时任务已停止'); },
      closeFileTransferSession: () => this.closeTransferSession(),
      reportFailure: (message: string) => this.errorText = message,
    }));
  }

  private publishDataTransferChanged(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.emit(DATA_TRANSFER_BACKGROUND_CHANGE_EVENT);
  }

  private publishDataTransferUnbind(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.emit(DATA_TRANSFER_BACKGROUND_UNBIND_EVENT);
  }

  private isPcDevice(): boolean {
    return deviceInfo.deviceType === '2in1';
  }

  private applyFreeMultiWindowChrome(status: window.WindowStatusType): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow) {
      this.freeMultiWindow = false;
      return;
    }
    const isFreeMultiWindow = status === window.WindowStatusType.FLOATING;
    const hideForPcSession = this.isPcDevice() && this.pcSessionImmersiveRequested;

    if (isFreeMultiWindow) {
      try {
        currentWindow.setWindowDecorVisible(false);
      } catch (error) {
        this.freeMultiWindow = false;
        hilog.error(DOMAIN, TAG, 'Failed to hide free-window decor: %{public}s', String(error));
        return;
      }
      this.freeWindowChromeOwned = true;
      this.freeMultiWindow = true;
      currentWindow.setTitleAndDockHoverShown(false, false)
        .catch((error: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'Failed to disable free-window title and dock hover: %{public}s',
            JSON.stringify(error) ?? '');
        });
      return;
    }

    this.freeMultiWindow = false;
    if (hideForPcSession) {
      try {
        currentWindow.setWindowDecorVisible(false);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to keep PC session decor hidden: %{public}s', String(error));
        return;
      }
      currentWindow.setTitleAndDockHoverShown(false, false)
        .catch((error: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'Failed to keep PC session title and dock hover hidden: %{public}s',
            JSON.stringify(error) ?? '');
        });
      return;
    }

    if (!this.freeWindowChromeOwned) {
      return;
    }
    try {
      currentWindow.setWindowDecorVisible(true);
      this.freeWindowChromeOwned = false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to restore free-window decor: %{public}s', String(error));
      return;
    }
    currentWindow.setTitleAndDockHoverShown(true, true)
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Failed to restore free-window title and dock hover: %{public}s',
          JSON.stringify(error) ?? '');
      });
  }

  private refreshFreeWindowChrome(): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow) {
      return;
    }
    try {
      this.applyFreeMultiWindowChrome(currentWindow.getWindowStatus());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Refresh free-window chrome failed: %{public}s', String(error));
    }
  }

  private registerFreeWindowChrome(): void {
    this.freeWindowDragExpected = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(hostContext)
      .then((currentWindow: window.Window) => {
        if (this.freeWindowDragExpected) {
          this.freeWindow = currentWindow;
          try {
            currentWindow.on('windowStatusDidChange', this.onFreeWindowStatusChange);
            this.freeWindowStatusChangeRegistered = true;
          } catch (error) {
            hilog.info(DOMAIN, TAG, 'Window status listener is unavailable: %{public}s', String(error));
          }
          try {
            this.applyFreeMultiWindowChrome(currentWindow.getWindowStatus());
          } catch (error) {
            hilog.error(DOMAIN, TAG, 'Read initial free-window status failed: %{public}s', String(error));
          }
        }
      })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'register PC window drag failed: %{public}s', JSON.stringify(error) ?? '');
      });
  }

  private unregisterFreeWindowChrome(): void {
    this.freeWindowDragExpected = false;
    if (this.freeWindowStatusChangeRegistered && this.freeWindow) {
      try {
        this.freeWindow.off('windowStatusDidChange', this.onFreeWindowStatusChange);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'unregister free-window status failed: %{public}s', String(error));
      }
    }
    if (this.freeWindow && this.freeWindowChromeOwned) {
      try {
        this.freeWindow.setWindowDecorVisible(true);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'restore system window decor failed: %{public}s', String(error));
      }
      this.freeWindow.setTitleAndDockHoverShown(true, true)
        .catch((error: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'restore system title and dock hover failed: %{public}s',
            JSON.stringify(error) ?? '');
        });
    }
    this.freeWindowStatusChangeRegistered = false;
    this.freeWindowChromeOwned = false;
    this.freeMultiWindow = false;
    this.freeWindow = undefined;
  }

  private startMovingFreeWindow(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.beginMovingFreeWindow();
    }
  }

  private startMovingFreeWindowByMouse(event: MouseEvent): void {
    if (event.action !== MouseAction.Press || event.button !== MouseButton.Left) {
      return;
    }
    this.beginMovingFreeWindow();
    event.stopPropagation();
  }

  private beginMovingFreeWindow(): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow) {
      return;
    }
    try {
      const status = currentWindow.getWindowStatus();
      if (status === window.WindowStatusType.FULL_SCREEN || status === window.WindowStatusType.MAXIMIZE) {
        return;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'get free-window status before moving failed: %{public}s', String(error));
      return;
    }
    currentWindow.startMoving()
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'start moving PC window failed: %{public}s', JSON.stringify(error) ?? '');
      });
  }

  private pcTitleStatusText(): string {
    const transfers = this.transferManager.snapshot();
    const activeTransferCount = TransferProgress.activeCount(transfers);
    if (activeTransferCount > 0) {
      const percent = TransferProgress.percent(transfers);
      return percent === undefined ? `正在传输 ${activeTransferCount} 个文件` :
        `正在传输 ${activeTransferCount} 个文件 · ${percent}%`;
    }
    if (this.activeSessionId.length > 0) {
      const target = this.peerTarget.trim();
      return target.length > 0 ? `已连接 · ${target}` : '远程会话已连接';
    }
    if (this.transferManager.isReady()) {
      return '文件传输会话已连接';
    }
    return '就绪';
  }

  private setRootControlFocused(controlId: string, focused: boolean): void {
    this.getUIContext()?.animateTo({
      duration: 150,
      curve: Curve.Friction,
    }, () => {
      if (focused) {
        this.rootFocusedControl = controlId;
      } else if (this.rootFocusedControl === controlId) {
        this.rootFocusedControl = '';
      }
    });
  }

  private requestInitialDisplayConfiguration(display: number): void {
    if (!this.activeSessionId || this.initialDisplayCommandIssued || this.pendingDisplayIndex >= 0) {
      return;
    }
    if (!this.sessionDisplayController.selectDisplay(this.activeSessionId, display)) {
      return;
    }
    this.initialDisplayCommandIssued = true;
    this.pendingDisplayIndex = display;
    this.sessionMessage = `已请求显示器 ${display + 1} 画面`;
  }

  private requestDisplaySelection(display: number): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    if (display === this.sessionDisplayController.getCurrentDisplayIndex()) {
      return;
    }
    if (!this.sessionDisplayController.selectDisplay(this.activeSessionId, display)) {
      return;
    }
    this.initialDisplayCommandIssued = true;
    this.pendingDisplayIndex = display;
    this.lastAppliedDisplay = -1;
    this.lastAppliedVideoWidth = 0;
    this.lastAppliedVideoHeight = 0;
    this.sessionMessage = `已请求切换到显示器 ${display + 1}`;
  }

  private requestResolutionChange(resolution: ResolutionInfo): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    const display = this.sessionDisplayController.getCurrentDisplayIndex();
    if (!this.sessionDisplayController.requestResolution(
      this.activeSessionId,
      display,
      resolution,
      this.peerPlatform,
    )) {
      return;
    }
    this.pendingResolutionDisplay = display;
    this.pendingResolutionWidth = resolution.width;
    this.pendingResolutionHeight = resolution.height;
    this.sessionMessage = `已请求远端分辨率 ${resolution.width}x${resolution.height}`;
  }

  private applyQualitySelection(preset: QualityPreset): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    if (!this.sessionDisplayController.applyQuality(
      this.activeSessionId,
      preset,
      this.customQualityDraft,
      this.customFpsDraft,
    )) {
      return;
    }
    this.selectedQualityPreset = this.sessionDisplayController.getImageQuality();
    this.customQualityDraft = this.sessionDisplayController.getCustomImageQuality();
    this.customFpsDraft = this.sessionDisplayController.getCustomFps();
    this.sessionMessage = '已请求更新画质设置';
  }

  private updateCustomQuality(value: number): void {
    this.customQualityDraft = value;
    this.selectedQualityPreset = 'custom';
    this.applyQualitySelection('custom');
  }

  private updateCustomFps(value: number): void {
    this.customFpsDraft = value;
    this.selectedQualityPreset = 'custom';
    this.applyQualitySelection('custom');
  }

  private sendChatDraft(value: string): void {
    const message = this.chatStore.send(value, Date.now());
    if (!message) {
      return;
    }
    this.chatDraft = '';
    if (!this.activeSessionId) {
      this.chatStore.markFailed(message.localId);
      this.refreshChatState();
      return;
    }
    try {
      const response = this.nativeSessionBridge.sendChat(this.activeSessionId, message.text);
      this.updateSessionState(response);
      if (response.ok) {
        this.chatStore.markSent(message.localId);
      } else {
        this.chatStore.markFailed(message.localId);
      }
    } catch (error) {
      this.errorText = String(error);
      this.chatStore.markFailed(message.localId);
    }
    this.refreshChatState();
  }

  private retryChat(localId: string): void {
    const message = this.chatStore.retry(localId);
    if (!message) {
      return;
    }
    if (!this.activeSessionId) {
      this.chatStore.markFailed(message.localId);
      this.refreshChatState();
      return;
    }
    try {
      const response = this.nativeSessionBridge.sendChat(this.activeSessionId, message.text);
      this.updateSessionState(response);
      if (response.ok) {
        this.chatStore.markSent(message.localId);
      } else {
        this.chatStore.markFailed(message.localId);
      }
    } catch (error) {
      this.errorText = String(error);
      this.chatStore.markFailed(message.localId);
    }
    this.refreshChatState();
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

  private resolveSessionOrientationMode(active: boolean): RemoteSessionOrientationMode {
    if (!active) {
      return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
    }
    const remoteDisplay = this.viewportModel.getCurrentDisplay();
    if (!remoteDisplay) {
      return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
    }
    return RemoteSessionOrientationPolicy.resolve(
      deviceInfo.deviceType,
      remoteDisplay.width,
      remoteDisplay.height,
    );
  }

  private toWindowOrientation(mode: RemoteSessionOrientationMode): window.Orientation {
    if (mode === RemoteSessionOrientationMode.PORTRAIT) {
      return window.Orientation.PORTRAIT;
    }
    if (mode === RemoteSessionOrientationMode.LANDSCAPE) {
      return window.Orientation.LANDSCAPE;
    }
    return window.Orientation.FOLLOW_DESKTOP;
  }

  private shouldEnableLandscapeMultiWindow(mode: RemoteSessionOrientationMode, active: boolean): boolean {
    return active && deviceInfo.deviceType === 'phone' && mode === RemoteSessionOrientationMode.LANDSCAPE;
  }

  private async applyLandscapeMultiWindow(
    currentWindow: window.Window,
    enabled: boolean,
    force: boolean,
  ): Promise<void> {
    if (!force && this.landscapeMultiWindowEnabled === enabled) {
      return;
    }
    try {
      if (enabled) {
        await currentWindow.enableLandscapeMultiWindow();
      } else {
        await currentWindow.disableLandscapeMultiWindow();
      }
      this.landscapeMultiWindowEnabled = enabled;
      hilog.info(
        DOMAIN,
        TAG,
        'Landscape multi-window %{public}s for remote session',
        enabled ? 'enabled' : 'disabled',
      );
    } catch (error) {
      hilog.warn(
        DOMAIN,
        TAG,
        'Failed to update landscape multi-window: %{public}s',
        String(error),
      );
    }
  }

  private async applyPcSessionImmersive(currentWindow: window.Window, active: boolean): Promise<void> {
    if (!this.isPcDevice()) {
      return;
    }
    if (active) {
      this.pcSessionImmersiveRequested = true;
      let previousStatus = window.WindowStatusType.UNDEFINED;
      try {
        previousStatus = currentWindow.getWindowStatus();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Failed to read PC window status: %{public}s', String(error));
      }
      this.pcSessionWindowStatusBeforeImmersive = previousStatus;
      if (previousStatus === window.WindowStatusType.FULL_SCREEN) {
        try {
          currentWindow.setWindowDecorVisible(false);
          await currentWindow.setTitleAndDockHoverShown(false, false);
          this.pcSessionImmersiveApplied = true;
        } catch (error) {
          this.pcSessionWindowStatusBeforeImmersive = window.WindowStatusType.UNDEFINED;
          this.pcSessionImmersiveRequested = false;
          this.pcSessionImmersiveApplied = false;
          try {
            this.applyFreeMultiWindowChrome(currentWindow.getWindowStatus());
          } catch (chromeError) {
            hilog.warn(DOMAIN, TAG, 'Failed to restore window chrome after immersive error: %{public}s',
              String(chromeError));
          }
          hilog.warn(DOMAIN, TAG, 'Failed to disable title and dock hover: %{public}s', String(error));
        }
        return;
      }
      try {
        await currentWindow.maximize(
          window.MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER,
        );
        currentWindow.setWindowDecorVisible(false);
        await currentWindow.setTitleAndDockHoverShown(false, false);
        this.pcSessionImmersiveApplied = true;
      } catch (error) {
        this.pcSessionWindowStatusBeforeImmersive = window.WindowStatusType.UNDEFINED;
        this.pcSessionImmersiveRequested = false;
        this.pcSessionImmersiveApplied = false;
        try {
          this.applyFreeMultiWindowChrome(currentWindow.getWindowStatus());
        } catch (chromeError) {
          hilog.warn(DOMAIN, TAG, 'Failed to restore window chrome after immersive error: %{public}s',
            String(chromeError));
        }
        hilog.warn(DOMAIN, TAG, 'Failed to enter PC session immersive mode: %{public}s', String(error));
      }
      return;
    }
    if (!this.pcSessionImmersiveApplied) {
      this.pcSessionImmersiveRequested = false;
      return;
    }
    const previousStatus = this.pcSessionWindowStatusBeforeImmersive;
    try {
      if (previousStatus === window.WindowStatusType.FULL_SCREEN) {
        await currentWindow.setTitleAndDockHoverShown(true, true);
      } else if (previousStatus === window.WindowStatusType.MAXIMIZE) {
        await currentWindow.maximize(window.MaximizePresentation.EXIT_IMMERSIVE);
      } else {
        await currentWindow.recover();
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Failed to restore PC window after session: %{public}s', String(error));
    } finally {
      this.pcSessionWindowStatusBeforeImmersive = window.WindowStatusType.UNDEFINED;
      this.pcSessionImmersiveRequested = false;
      this.pcSessionImmersiveApplied = false;
      try {
        this.applyFreeMultiWindowChrome(currentWindow.getWindowStatus());
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Failed to restore PC window chrome after session: %{public}s', String(error));
      }
    }
  }

  private applySessionFullscreen(active: boolean, force: boolean = false): Promise<void> {
    const nextUpdate = this.sessionWindowUpdatePromise.then((): Promise<void> => {
      return this.applySessionFullscreenNow(active, force);
    });
    this.sessionWindowUpdatePromise = nextUpdate;
    return nextUpdate;
  }

  private applySessionFullscreenNow(active: boolean, force: boolean): Promise<void> {
    const orientationMode = this.resolveSessionOrientationMode(active);
    const fullscreenChanged = force || this.sessionFullscreenApplied !== active;
    const orientationChanged = force || this.sessionOrientationMode !== orientationMode;
    const landscapeMultiWindowEnabled = this.shouldEnableLandscapeMultiWindow(orientationMode, active);
    const landscapeMultiWindowChanged = force
      || this.landscapeMultiWindowEnabled !== landscapeMultiWindowEnabled;
    if (!fullscreenChanged && !orientationChanged && !landscapeMultiWindowChanged) {
      return Promise.resolve();
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return window.getLastWindow(hostContext)
      .then(async (currentWindow: window.Window) => {
        if (landscapeMultiWindowChanged) {
          await this.applyLandscapeMultiWindow(currentWindow, landscapeMultiWindowEnabled, force);
        }
        if (orientationChanged) {
          await currentWindow.setPreferredOrientation(this.toWindowOrientation(orientationMode));
          this.sessionOrientationMode = orientationMode;
        }
        if (fullscreenChanged) {
          if (active) {
            await this.applyPcSessionImmersive(currentWindow, true);
            await currentWindow.setWindowLayoutFullScreen(true);
            await currentWindow.setSpecificSystemBarEnabled('status', false, true);
            await currentWindow.setSpecificSystemBarEnabled('navigationIndicator', false, true);
          } else {
            await currentWindow.setSpecificSystemBarEnabled('status', true, true);
            await currentWindow.setSpecificSystemBarEnabled('navigationIndicator', true, true);
            await currentWindow.setWindowLayoutFullScreen(true);
            await this.applyPcSessionImmersive(currentWindow, false);
          }
          this.sessionFullscreenApplied = active;
        }
        this.refreshWindowAvoidAreas(currentWindow);
      })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'applySessionFullscreen failed: %{public}s', JSON.stringify(error) ?? '');
      });
  }

  private refreshSessionOrientation(): void {
    if (!this.pageVisible || this.sessionCloseInFlight || !this.activeSessionId
      || !this.sessionFullscreenApplied) {
      return;
    }
    void this.applySessionFullscreen(true);
  }

  private registerWindowAvoidAreaListener(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(hostContext)
      .then((currentWindow: window.Window) => {
        this.immersiveWindow = currentWindow;
        this.refreshWindowAvoidAreas(currentWindow);
        if (!this.avoidAreaChangeRegistered) {
          try {
            currentWindow.on('avoidAreaChange', this.onWindowAvoidAreaChange);
            this.avoidAreaChangeRegistered = true;
          } catch (error) {
            hilog.error(DOMAIN, TAG, 'register avoidAreaChange failed: %{public}s', String(error));
          }
        }
      })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'get immersive window failed: %{public}s', JSON.stringify(error) ?? '');
      });
  }

  private unregisterWindowAvoidAreaListener(): void {
    if (this.avoidAreaChangeRegistered && this.immersiveWindow) {
      try {
        this.immersiveWindow.off('avoidAreaChange', this.onWindowAvoidAreaChange);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'unregister avoidAreaChange failed: %{public}s', String(error));
      }
    }
    this.avoidAreaChangeRegistered = false;
    this.immersiveWindow = undefined;
  }

  private refreshWindowAvoidAreas(currentWindow: window.Window): void {
    try {
      const systemArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.updateWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM, systemArea);
      const navigationArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.updateWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR, navigationArea);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'refresh window avoid areas failed: %{public}s', String(error));
    }
  }

  private updateWindowAvoidArea(type: window.AvoidAreaType, area: window.AvoidArea): void {
    const uiContext = this.getUIContext();
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      this.windowTopAvoidInset = Math.max(Math.round(uiContext.px2vp(area.topRect.height)), 0);
    } else if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      this.windowBottomAvoidInset = Math.max(Math.round(uiContext.px2vp(area.bottomRect.height)), 0);
    }
  }

  private registerFoldHoverListeners(): void {
    if (!this.foldStatusChangeRegistered) {
      try {
        display.on('foldStatusChange', this.onFoldStatusChange);
        this.foldStatusChangeRegistered = true;
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'register foldStatusChange failed: %{public}s', String(error));
      }
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(hostContext)
      .then((currentWindow: window.Window) => {
        this.previewWindow = currentWindow;
        if (!this.windowSizeChangeRegistered) {
          try {
            currentWindow.on('windowSizeChange', this.onPreviewWindowSizeChange);
            this.windowSizeChangeRegistered = true;
          } catch (error) {
            hilog.error(DOMAIN, TAG, 'register windowSizeChange failed: %{public}s', String(error));
          }
        }
        this.refreshFoldHoverMode();
      })
      .catch((error: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'get preview window failed: %{public}s', JSON.stringify(error) ?? '');
        this.refreshFoldHoverMode();
      });
    this.refreshFoldHoverMode();
  }

  private unregisterFoldHoverListeners(): void {
    if (this.foldStatusChangeRegistered) {
      try {
        display.off('foldStatusChange', this.onFoldStatusChange);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'unregister foldStatusChange failed: %{public}s', String(error));
      }
      this.foldStatusChangeRegistered = false;
    }
    if (this.windowSizeChangeRegistered && this.previewWindow) {
      try {
        this.previewWindow.off('windowSizeChange', this.onPreviewWindowSizeChange);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'unregister windowSizeChange failed: %{public}s', String(error));
      }
      this.windowSizeChangeRegistered = false;
    }
    this.previewWindow = undefined;
    this.setFoldHoverMode(false);
  }

  private refreshFoldHoverMode(): void {
    let nextMode = false;
    try {
      if (this.showPreviewModal && display.isFoldable()) {
        const status = display.getFoldStatus();
        const orientation = display.getDefaultDisplaySync().orientation;
        nextMode = status === display.FoldStatus.FOLD_STATUS_HALF_FOLDED
          && (orientation === display.Orientation.LANDSCAPE || orientation === display.Orientation.LANDSCAPE_INVERTED);
        if (nextMode) {
          this.updateFoldHoverMetrics();
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'refreshFoldHoverMode failed: %{public}s', String(error));
      nextMode = false;
    }
    if (!nextMode) {
      this.foldHoverUpperHeight = 0;
      this.foldHoverCreaseHeight = 0;
    }
    this.setFoldHoverMode(nextMode);
  }

  private updateFoldHoverMetrics(): void {
    try {
      const region = display.getCurrentFoldCreaseRegion();
      if (region.creaseRects.length === 0) {
        this.foldHoverUpperHeight = 0;
        this.foldHoverCreaseHeight = 0;
        return;
      }
      const rect = region.creaseRects[0];
      const uiContext = this.getUIContext();
      this.foldHoverUpperHeight = Math.max(Math.round(uiContext.px2vp(rect.top)), 0);
      this.foldHoverCreaseHeight = Math.max(Math.round(uiContext.px2vp(rect.height)), 0);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'updateFoldHoverMetrics failed: %{public}s', String(error));
      this.foldHoverUpperHeight = 0;
      this.foldHoverCreaseHeight = 0;
    }
  }

  private setFoldHoverMode(active: boolean): void {
    if (this.isFoldHoverMode === active) {
      return;
    }
    this.isFoldHoverMode = active;
    if (active) {
      this.hideSoftKeyboard();
    }
    hilog.info(DOMAIN, TAG, 'Fold hover mode changed: %{public}s', active ? 'true' : 'false');
    setTimeout(() => {
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
    }, 80);
  }

  private async preparePreviewSurface(connectionGeneration?: number): Promise<void> {
    if (!this.activeSessionId ||
      (connectionGeneration !== undefined && connectionGeneration !== this.connectionGeneration)) {
      return;
    }
    await this.applySessionFullscreen(true);
    await this.waitForPreviewWindowReady();
    if (connectionGeneration !== undefined && connectionGeneration !== this.connectionGeneration) {
      return;
    }
    this.showPreviewModal = true;
    this.syncInputInterceptor();
    this.registerFoldHoverListeners();
    this.previewSurfaceVisible = false;
    this.previewSurfaceId = '';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.frameStatus = 'Preparing preview surface';
    this.previewSurfaceGeneration += 1;
    this.previewSurfaceVisible = true;
    this.setSessionKeyboardEntered(true);
    await this.waitForPreviewSurfaceBinding(connectionGeneration);
    if (connectionGeneration !== undefined && connectionGeneration !== this.connectionGeneration) {
      return;
    }
  }

  private async waitForPreviewSurfaceBinding(connectionGeneration?: number): Promise<void> {
    for (let index = 0; index < PREVIEW_SURFACE_WAIT_ATTEMPTS; index++) {
      if (connectionGeneration !== undefined && connectionGeneration !== this.connectionGeneration) {
        return;
      }
      this.recoverPreviewSurfaceIdFromController();
      if (this.previewSurfaceId.length > 0 && this.syncSurfaceBinding()) {
        return;
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), PREVIEW_SURFACE_WAIT_INTERVAL_MS));
    }
    if (this.previewSurfaceId.length === 0) {
      throw new Error('Preview surface was not created before session start');
    }
    throw new Error('Preview surface was created but could not be bound before session start');
  }

  private enterPreviewMode(event: NativeEvent): void {
    if (this.showPreviewModal && this.previewSurfaceVisible && this.previewSurfaceId.length > 0) {
      this.configureDisplayFromPeerInfo(event);
      return;
    }
    this.pendingPreviewPeerInfo = event;
    if (this.previewSurfaceSetupInFlight &&
      this.previewSurfaceSetupGeneration === this.connectionGeneration) {
      return;
    }
    const setupGeneration = this.connectionGeneration;
    this.previewSurfaceSetupInFlight = true;
    this.previewSurfaceSetupGeneration = setupGeneration;
    void this.preparePreviewSurfaceForPendingEvent(setupGeneration);
  }

  private async preparePreviewSurfaceForPendingEvent(setupGeneration: number): Promise<void> {
    try {
      const initialPeerInfo = this.pendingPreviewPeerInfo;
      if (initialPeerInfo) {
        this.configureDisplayFromPeerInfo(initialPeerInfo);
      }
      await this.preparePreviewSurface(setupGeneration);
      if (setupGeneration !== this.connectionGeneration || !this.activeSessionId) {
        return;
      }
      const peerInfo = this.pendingPreviewPeerInfo;
      this.pendingPreviewPeerInfo = undefined;
      if (peerInfo) {
        this.configureDisplayFromPeerInfo(peerInfo);
      }
    } catch (error) {
      if (setupGeneration !== this.connectionGeneration) {
        return;
      }
      this.pendingPreviewPeerInfo = undefined;
      const message = `Preview surface setup failed: ${String(error)}`;
      hilog.error(DOMAIN, TAG, 'preparePreviewSurface failed: %{public}s', message);
      this.failConnectionAttempt(message);
    } finally {
      if (this.previewSurfaceSetupGeneration === setupGeneration) {
        this.previewSurfaceSetupInFlight = false;
        this.previewSurfaceSetupGeneration = -1;
      }
    }
  }

  private async waitForPreviewWindowReady(): Promise<void> {
    if (this.sessionOrientationMode === RemoteSessionOrientationMode.FOLLOW_DESKTOP) {
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
      return;
    }
    const expectLandscape = this.sessionOrientationMode === RemoteSessionOrientationMode.LANDSCAPE;
    for (let index = 0; index < 8; index += 1) {
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const isLandscape = displayInfo.width >= displayInfo.height;
        if (isLandscape === expectLandscape) {
          await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
          return;
        }
      } catch (_error) {
        // The window manager may still be applying the requested direction.
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
    }
  }

  private async toggleRelativeMouseMode(): Promise<void> {
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    const nextMode = !this.relativeMouseMode;
    this.relativeMouseMode = nextMode;
    this.syncRelativeMouseMode(nextMode);
    this.sessionMessage = `已切换到${this.getPointerModeName(nextMode)}`;
  }

  private getPointerModeName(relativeMode: boolean = this.relativeMouseMode): string {
    return relativeMode ? '触摸板' : '模拟鼠标';
  }

  private clampPreviewScale(value: number): number {
    if (!Number.isFinite(value)) {
      return 1;
    }
    return Math.min(Math.max(value, PREVIEW_MIN_USER_SCALE), PREVIEW_MAX_USER_SCALE);
  }

  private clampPreviewOffsetX(value: number): number {
    const limit = Math.max(this.previewViewWidth, 1);
    return Math.min(Math.max(value, -limit), limit);
  }

  private clampPreviewOffsetY(value: number): number {
    const limit = Math.max(this.previewViewHeight, 1);
    return Math.min(Math.max(value, -limit), limit);
  }

  private normalizePreviewUserRotation(value: number): number {
    if (!Number.isFinite(value)) {
      return 0;
    }
    const normalized = value % 360;
    if (normalized > 180) {
      return normalized - 360;
    }
    if (normalized < -180) {
      return normalized + 360;
    }
    return normalized;
  }

  private syncPreviewViewTransform(): void {
    this.viewportModel.setViewTransform(
      this.previewUserScale,
      this.previewUserOffsetX,
      this.previewUserOffsetY,
      this.previewUserRotation,
    );
    this.reprojectVirtualCursorOverlay();
  }

  private hasPreviewViewTransform(): boolean {
    return Math.abs(this.previewUserScale - 1) > 0.001
      || Math.abs(this.previewUserOffsetX) > 0.5
      || Math.abs(this.previewUserOffsetY) > 0.5
      || Math.abs(this.previewUserRotation) > 0.1;
  }

  private previewTransformSummary(): string {
    const scale = Math.round(this.previewUserScale * 100);
    const rotation = Math.round(this.previewUserRotation);
    return rotation === 0 ? `${scale}%` : `${scale}% · ${rotation}°`;
  }

  private sessionOverlayContentHeight(): number {
    const availableHeight = this.previewViewHeight - 160;
    return Math.max(160, Math.min(560, availableHeight));
  }

  private setPreviewTransformMode(active: boolean): void {
    if (this.previewTransformMode === active) {
      return;
    }
    this.inputController?.reset();
    this.previewTransformMode = active;
    if (!active) {
      setTimeout(() => this.requestPreviewInputFocus(), 80);
    }
  }

  private resetPreviewViewTransform(animated: boolean = true): void {
    const reset = (): void => {
      this.previewUserScale = 1;
      this.previewUserOffsetX = 0;
      this.previewUserOffsetY = 0;
      this.previewUserRotation = 0;
      this.syncPreviewViewTransform();
    };
    if (animated) {
      const uiContext = this.getUIContext();
      if (uiContext) {
        uiContext.animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, reset);
        return;
      }
    }
    reset();
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
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
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
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    this.sendMousePayloadToSession(this.activeSessionId, payload, true);
  }

  private sendMousePayloadToSession(
    sessionId: string,
    payload: RustDeskMousePayload,
    reportFailure: boolean,
  ): void {
    if (sessionId.length === 0) {
      return;
    }
    try {
      const response = this.parseResponse(native.sessionSendMouse(sessionId, JSON.stringify(payload)));
      if (!response.ok && reportFailure && this.activeSessionId === sessionId) {
        this.errorText = response.message ?? 'Mouse input failed';
      }
    } catch (error) {
      if (reportFailure && this.activeSessionId === sessionId) {
        this.errorText = `Mouse input failed: ${String(error)}`;
      }
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
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleTouchEvent(event);
  }

  private sendKeyPayloadObject(payload: RustDeskKeyPayload): boolean {
    if (!this.isRemoteControlSessionActive()) {
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
    if (!this.isRemoteControlSessionActive()) {
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
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleMouseEvent(event);
  }

  private handlePreviewAxisEvent(event: AxisEvent): void {
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleAxisEvent(event);
  }

  private handlePreviewKeyEvent(event: KeyEvent): boolean {
    if (!this.isRemoteControlSessionActive()) {
      return false;
    }
    this.requestPreviewInputFocus();
    this.logRelativeDebug('keyboard_event', `keyCode=${event.keyCode} type=${String(event.type)} keyText=${String(event.keyText ?? '')} unicode=${String(event.unicode ?? '')}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private handlePreviewRootKeyEvent(event: KeyEvent): boolean {
    if (!this.isRemoteControlSessionActive()) {
      return false;
    }
    this.logRelativeDebug('keyboard_root_event', `keyCode=${event.keyCode} type=${String(event.type)} keyText=${String(event.keyText ?? '')} unicode=${String(event.unicode ?? '')}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private requestPreviewInputFocus(): void {
    if (!this.showPreviewModal) {
      return;
    }
    try {
      this.getUIContext().getFocusController().requestFocus(PREVIEW_INPUT_FOCUS_ID);
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
      this.toolbarRenderStats = {
        fps: 0,
        totalFrames: 0,
        lastFrameAgeMs: 0,
        hasRenderedFrame: false,
      };
      return;
    }
    const now = Date.now();
    try {
      const currentDisplay = this.viewportModel.getCurrentDisplayIndex();
      const response = this.parseResponse(native.sessionGetRenderStats(this.activeSessionId, currentDisplay));
      const snapshot = response.stats?.stats;
      if (!snapshot || !snapshot.hasRenderedFrame) {
        this.renderFpsText = 'FPS --';
        this.toolbarRenderStats = snapshot ?? {
          fps: 0,
          totalFrames: 0,
          lastFrameAgeMs: 0,
          hasRenderedFrame: false,
        };
        this.handleRenderStall(now, 0, 0, false);
        return;
      }
      this.toolbarRenderStats = snapshot;
      const decodeLatencyMs = Number(snapshot.avgDecodeLatencyMs ?? snapshot.decodeLatencyMs ?? 0);
      this.renderFpsText = decodeLatencyMs > 0
        ? `FPS ${snapshot.fps.toFixed(1)} | Frames ${snapshot.totalFrames} | Dec ${decodeLatencyMs.toFixed(0)}ms`
        : `FPS ${snapshot.fps.toFixed(1)} | Frames ${snapshot.totalFrames}`;
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
    this.syncSurfaceBinding();
  }

  private sessionToolbarMetrics(): SessionToolbarMetrics {
    return formatSessionToolbarMetrics(
      this.toolbarRenderStats.fps,
      this.toolbarRenderStats.totalFrames,
      this.toolbarRenderStats.avgDecodeLatencyMs ?? this.toolbarRenderStats.decodeLatencyMs,
      this.toolbarRenderStats.hasRenderedFrame,
      this.qualityTelemetry.delay,
      this.qualityTelemetry.codec,
    );
  }

  private refreshQualitySummary(): void {
    this.qualitySummary = `Remote fps ${this.qualityTelemetry.fps} | delay ${this.qualityTelemetry.delay} | codec ${this.qualityTelemetry.codec}`;
  }

  private shortRemoteStatusText(): string {
    return `fps ${this.qualityTelemetry.fps} | delay ${this.qualityTelemetry.delay} | codec ${this.qualityTelemetry.codec} | ${this.getPointerModeName()}`;
  }

  private extractRemoteFps(raw: string | undefined): string | undefined {
    if (!raw || raw.length === 0) {
      return undefined;
    }
    try {
      const fpsMap = JSON.parse(raw) as Record<string, number>;
      const current = fpsMap[String(this.viewportModel.getCurrentDisplayIndex())];
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
    const preferredOrder: string[] = ['H265', 'H264', 'AV1', 'VP9', 'VP8'];
    for (let orderIndex = 0; orderIndex < preferredOrder.length; orderIndex += 1) {
      const preferred = preferredOrder[orderIndex];
      for (let capabilityIndex = 0; capabilityIndex < capabilities.length; capabilityIndex += 1) {
        const capability = capabilities[capabilityIndex];
        if (capability.codec !== preferred) {
          continue;
        }
        if (capability.mimeAvailable || capability.recommendedAvailable || capability.hardwareAvailable ||
          capability.softwareAvailable) {
          return preferred.toLowerCase();
        }
      }
    }
    return 'auto';
  }

  private configureDisplayFromPeerInfo(event: NativeEvent): void {
    if (event.platform && event.platform.length > 0) {
      this.peerPlatform = String(event.platform);
    }
    if (event.version && event.version.length > 0) {
      this.peerVersion = String(event.version);
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
      let reportedCurrentDisplay: number | undefined = undefined;
      if (event.current_display !== undefined && event.current_display.length > 0) {
        const parsedCurrentDisplay = Number(event.current_display);
        if (Number.isFinite(parsedCurrentDisplay)
          && (this.pendingDisplayIndex < 0 || this.pendingDisplayIndex === parsedCurrentDisplay)) {
          reportedCurrentDisplay = parsedCurrentDisplay;
        }
      }
      this.sessionDisplayController.updatePeerInfo(
        this.peerDisplays,
        reportedCurrentDisplay,
        this.supportedResolutions,
        this.peerPlatform,
      );
      const currentDisplay = this.sessionDisplayController.getCurrentDisplayIndex();
      this.refreshSessionOrientation();
      this.ensureRemoteCursorEnabled();
      hilog.info(
        DOMAIN,
        TAG,
        'Display setup peer platform=%{public}s current=%{public}d displays=%{public}s resolutions=%{public}s',
        this.peerPlatform,
        currentDisplay,
        JSON.stringify(this.peerDisplays),
        JSON.stringify(this.supportedResolutions),
      );
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
    } catch (error) {
      this.errorText = `Display setup failed: ${String(error)}`;
    }
  }

  private handleSwitchDisplayConfirmation(event: NativeEvent): void {
    const display = Number(event.display ?? -1);
    const width = Number(event.width ?? '0');
    const height = Number(event.height ?? '0');
    if (!Number.isInteger(display) || display < 0 || display >= this.peerDisplays.length
      || !Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      return;
    }
    const previous = this.peerDisplays[display];
    const x = Number(event.x ?? `${previous.x}`);
    const y = Number(event.y ?? `${previous.y}`);
    this.peerDisplays[display] = {
      width: Math.round(width),
      height: Math.round(height),
      x: Number.isFinite(x) ? x : previous.x,
      y: Number.isFinite(y) ? y : previous.y,
      cursor_embedded: previous.cursor_embedded,
      original_width: previous.original_width,
      original_height: previous.original_height,
    };
    if (event.resolutions) {
      this.supportedResolutions = this.parseSupportedResolutions(event.resolutions);
    }
    this.sessionDisplayController.updatePeerInfo(
      this.peerDisplays,
      undefined,
      this.supportedResolutions,
      this.peerPlatform,
    );
    this.refreshSessionOrientation();
    if (this.pendingDisplayIndex === display) {
      this.pendingDisplayIndex = -1;
      this.sessionMessage = `显示器 ${display + 1} 已确认切换`;
      if (this.previewSurfaceId.length > 0) {
        this.syncSurfaceBinding(false);
      }
    }
    if (this.pendingResolutionDisplay === display
      && this.pendingResolutionWidth === Math.round(width)
      && this.pendingResolutionHeight === Math.round(height)) {
      this.pendingResolutionDisplay = -1;
      this.pendingResolutionWidth = 0;
      this.pendingResolutionHeight = 0;
      this.sessionMessage = `远端分辨率已确认 ${Math.round(width)}x${Math.round(height)}`;
    }
    this.applyDisplayConfiguration();
    this.reprojectVirtualCursorOverlay();
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
    if (this.pendingDisplayIndex >= 0) {
      this.frameStatus = `等待显示器 ${this.pendingDisplayIndex + 1} 确认`;
      return;
    }
    if (this.previewSurfaceId.length > 0) {
      this.syncSurfaceBinding(false);
    }
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
    this.requestInitialDisplayConfiguration(currentDisplay);
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
    // Show the local virtual cursor at the display center as soon as geometry is ready.
    if (!this.getInputController().hasVirtualCursor()) {
      this.getInputController().initVirtualCursorToCenter();
    }
  }

  private handlePreviewSurfaceCreated(surfaceId: string): void {
    setTimeout(() => {
      if (!this.activeSessionId || !this.showPreviewModal || !this.previewSurfaceVisible) {
        return;
      }
      this.previewSurfaceId = surfaceId;
      this.frameStatus = `Surface created ${surfaceId}`;
      this.syncSurfaceBinding();
    }, 0);
  }

  private recoverPreviewSurfaceIdFromController(): void {
    if (this.previewSurfaceId.length > 0 || !this.showPreviewModal || !this.previewSurfaceVisible) {
      return;
    }
    try {
      const surfaceId = this.previewController.getXComponentSurfaceId();
      if (surfaceId.length > 0) {
        this.previewSurfaceId = surfaceId;
        this.frameStatus = `Surface recovered ${surfaceId}`;
      }
    } catch (_error) {
      // Surface 尚未创建完成，等待正式生命周期回调。
    }
  }

  private handlePreviewSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    setTimeout(() => {
      if (surfaceId !== this.previewSurfaceId) {
        return;
      }
      this.frameWidth = rect.surfaceWidth;
      this.frameHeight = rect.surfaceHeight;
      this.viewportModel.setSurfaceSize(rect.surfaceWidth, rect.surfaceHeight);
      this.frameStatus = `Surface ready ${rect.surfaceWidth}x${rect.surfaceHeight}`;
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
    }, 0);
  }

  private handlePreviewSurfaceDestroyed(surfaceId: string): void {
    setTimeout(() => {
      if (surfaceId !== this.previewSurfaceId) {
        return;
      }
      this.inputController?.releasePressedButtons();
      this.clearSurfaceBinding();
      this.previewSurfaceId = '';
      this.frameWidth = 0;
      this.frameHeight = 0;
      this.viewportModel.setSurfaceSize(0, 0);
      this.frameStatus = 'Surface destroyed';
    }, 0);
  }

  private syncSurfaceBinding(refreshAfterBind: boolean = true): boolean {
    if (!this.activeSessionId || this.previewSurfaceId.length === 0) {
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionBindSurface(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
        this.previewSurfaceId
      ));
      this.updateSessionState(response);
      if (!response.ok) {
        return false;
      }
      if (refreshAfterBind) {
        this.requestVideoRefresh();
      }
      return true;
    } catch (error) {
      this.errorText = `Surface bind failed: ${String(error)}`;
      return false;
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
      hilog.error(
        DOMAIN,
        TAG,
        'native action failed action=%{public}s phase=%{public}s sessionId=%{public}s message=%{public}s',
        response.action,
        this.sessionPhase,
        this.activeSessionId,
        this.errorText,
      );
    }
  }

  private applyPerformanceTuning(): void {
    if (!this.activeSessionId || this.performanceTuningApplied) {
      return;
    }
    try {
      const quality = this.qualityPresetFor(this.activeSessionDefaults);
      if (this.sessionDisplayController.applyQuality(
        this.activeSessionId,
        quality,
        this.activeSessionDefaults.customQuality,
        this.activeSessionDefaults.customFps,
      )) {
        this.selectedQualityPreset = this.sessionDisplayController.getImageQuality();
      }
      this.applyCodecPreference();
      this.performanceTuningApplied = true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'applyPerformanceTuning failed: %{public}s', String(error));
    }
  }

  private applyCodecPreference(): void {
    if (!this.activeSessionId) {
      return;
    }
    if (this.codecPreferenceApplied) {
      return;
    }
    try {
      const response = this.parseResponse(native.sessionSetCodecPreference(this.activeSessionId, this.preferredCodec));
      this.codecPreferenceApplied = response.ok;
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
    if (events.length > 0) {
      hilog.info(DOMAIN, TAG, 'pollSessionEventsOnce count=%{public}d phase=%{public}s', events.length, this.sessionPhase);
    }
    this.logEventBatch(events, 'poll_once');
    this.logCursorEventBatch(events, 'poll_once');
    events.forEach((event: NativeEvent) => this.handleSessionEvent(event));
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
      if (!response.ok) {
        this.closeRemoteAudio();
        return;
      }
      if (this.activeSessionKind === 'remote_control' && !this.isRemoteAudioSessionActive()) {
        this.closeRemoteAudio();
      }
      const events = (response.events ?? []) as NativeEvent[];
      if (events.length > 0) {
        hilog.info(DOMAIN, TAG, 'pollSessionEvents count=%{public}d phase=%{public}s', events.length, this.sessionPhase);
      }
      this.logEventBatch(events, 'poll');
      this.logCursorEventBatch(events, 'poll');
      events.forEach((event: NativeEvent) => this.handleSessionEvent(event));
      this.pollInputInterceptorEvents();
      if (this.isRemoteControlSessionActive()) {
        this.ensureRemoteCursorEnabled();
      }
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'pollSessionEvents failed sessionId=%{public}s error=%{public}s', this.activeSessionId, this.errorText);
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

  private logEventBatch(events: NativeEvent[], source: string): void {
    if (events.length === 0) {
      return;
    }
    const names = events.map((event: NativeEvent) => {
      if (event.name === 'msgbox') {
        return `msgbox:${String(event.type ?? '')}:${String(event.text ?? '')}`;
      }
      return event.name;
    });
    hilog.info(
      DOMAIN,
      TAG,
      'session event batch source=%{public}s names=%{public}s',
      source,
      JSON.stringify(names),
    );
  }

  private handleSessionEvent(event: NativeEvent): void {
    if (event.name === 'close') {
      this.handleRemoteDisconnect('远端连接已结束');
      return;
    }
    if (event.name === 'permission') {
      if (event.keyboard !== undefined) {
        const keyboardPermission = String(event.keyboard).trim().toLowerCase();
        if (keyboardPermission === 'false') {
          this.remoteKeyboardPermissionAllowed = false;
        } else if (keyboardPermission === 'true') {
          this.remoteKeyboardPermissionAllowed = true;
        }
      }
      return;
    }
    if (event.name === 'connection_ready') {
      this.connectionSummary = `secure=${String(event.secure)}, direct=${String(event.direct)}, stream=${String(event.stream_type)}`;
      if (this.connectionUiPhase === 'connecting' || this.connectionUiPhase === 'authenticating') {
        this.connectionUiMessage = '安全通道已建立，正在读取远端会话信息。';
      }
      if (this.isRemoteControlSessionActive()) {
        this.ensureRemoteCursorEnabled();
      }
      this.performanceTuningApplied = false;
      return;
    }
    if (event.name === 'peer_info' || event.name === 'sync_peer_info') {
      this.clearConnectionTimeout();
      this.connectionUiPhase = 'connected';
      this.connectionUiMessage = '连接成功，正在准备远端画面。';
      this.sessionPhase = 'connected';
      if (event.name === 'peer_info') {
        if (event.platform && event.platform.length > 0) {
          this.peerPlatform = String(event.platform);
        }
        if (event.version && event.version.length > 0) {
          this.peerVersion = String(event.version);
        }
        this.connectionSummary = `peer=${String(event.hostname)}, platform=${String(event.platform)}, version=${String(event.version)}`;
      }
      this.applyPerformanceTuning();
      if (this.isRemoteControlSessionActive()) {
        this.remoteInteractionReady = true;
        this.syncRelativeMouseMode(this.relativeMouseMode);
        this.syncClipboardController();
        this.syncInputInterceptor();
        this.ensureRemoteCursorEnabled();
      }
      if (!this.showPreviewModal || !this.previewSurfaceVisible) {
        this.enterPreviewMode(event);
      } else {
        this.configureDisplayFromPeerInfo(event);
      }
      if (event.name === 'peer_info') {
        this.refreshDirectorySnapshot();
      }
      return;
    }
    if (event.name === 'switch_display') {
      this.handleSwitchDisplayConfirmation(event);
      return;
    }
    if (event.name === 'update_quality_status') {
      const fpsText = this.extractRemoteFps(event.fps);
      if (fpsText) {
        this.qualityTelemetry.fps = fpsText;
      }
      if (event.delay && event.delay.length > 0) {
        this.qualityTelemetry.delay = String(event.delay);
      }
      if (event.codec_format && event.codec_format.length > 0) {
        this.qualityTelemetry.codec = String(event.codec_format);
      }
      if (event.speed && event.speed.length > 0) {
        this.qualityTelemetry.speed = String(event.speed);
      }
      if (event.target_bitrate && event.target_bitrate.length > 0) {
        this.qualityTelemetry.targetBitrate = String(event.target_bitrate);
      }
      if (event.chroma && event.chroma.length > 0) {
        this.qualityTelemetry.chroma = String(event.chroma);
      }
      this.refreshQualitySummary();
      return;
    }
    if (event.name === 'rgba' || event.name === 'texture') {
      this.handleFrameTransportEvent(event);
      return;
    }
    if (event.name === 'cursor_data') {
      this.updateRemoteCursorData(event);
      return;
    }
    if (event.name === 'cursor_id') {
      this.updateRemoteCursorId(event);
      return;
    }
    if (event.name === 'cursor_position') {
      this.updateCursorOverlayFromRemote(Number(event.x ?? '0'), Number(event.y ?? '0'));
      return;
    }
    if (event.name === 'clipboard') {
      if (this.clipboardSyncEnabled && this.isRemoteControlSessionActive()) {
        this.clipboardController?.applyRemoteText(String(event.content ?? ''));
      }
      return;
    }
    if (event.name === 'chat_client_mode') {
      this.chatStore.receive(String(event.text ?? ''), Date.now());
      this.refreshChatState();
      return;
    }
    if (event.name === 'msgbox') {
      this.handleMsgBoxEvent(event);
    }
  }

  private handleMsgBoxEvent(event: NativeEvent): void {
    const title = String(event.title ?? '');
    const text = String(event.text ?? '');
    const type = String(event.type ?? '');
    const message = title.length > 0 ? `${title}: ${text}` : text;
    if (type === 'success' || title === 'Successful') {
      this.sessionMessage = message;
      this.errorText = '';
      return;
    }
    if (type === 'input-password' || type === 're-input-password') {
      this.connectionSummary = '等待密码验证';
      this.errorText = message;
      this.openPasswordDialog('primary', message);
      return;
    }
    if (text === WAITING_FOR_IMAGE_TEXT) {
      if (this.activeSessionId) {
        try {
          this.updateSessionState(this.parseResponse(native.sessionOnWaitingForImageDialogShow(this.activeSessionId)));
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'sessionOnWaitingForImageDialogShow failed: %{public}s', String(error));
        }
      }
      this.sessionMessage = text;
      this.connectionSummary = '已连接，等待远端首帧';
      this.errorText = '';
      return;
    }
    this.handleRemoteDisconnect(message);
  }

  private requestVideoRefresh(): void {
    if (!this.activeSessionId) {
      return;
    }
    try {
      this.updateSessionState(this.nativeSessionBridge.refresh(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
      ));
    } catch (error) {
      this.errorText = `Refresh error: ${String(error)}`;
    }
  }

  private invalidatePreviewFrames(): void {
    this.releasePreviewFramePixelMap();
    this.previewFrameInFlight = false;
  }

  private releasePreviewFramePixelMap(): void {
    const previous = this.previewFramePixelMap;
    this.previewFramePixelMap = undefined;
    this.rgbaFallbackActive = false;
    if (previous) {
      previous.release().catch((_error: BusinessError) => {});
    }
  }

  private updatePreviewFramePixelMap(pixelMap: image.PixelMap, width: number, height: number, display: number): void {
    const previous = this.previewFramePixelMap;
    this.previewFramePixelMap = pixelMap;
    this.rgbaFallbackActive = true;
    this.frameStatus = `RGBA fallback ${width}x${height}`;
    if (previous && previous !== pixelMap) {
      previous.release().catch((_error: BusinessError) => {});
    }
    if (this.pendingDisplayIndex === display) {
      this.pendingDisplayIndex = -1;
      this.refreshSessionOrientation();
      if (this.previewSurfaceId.length > 0) {
        this.syncSurfaceBinding(false);
      }
      this.sessionMessage = `显示器 ${display + 1} 已收到画面`;
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
    }
  }

  private consumePreviewRgbaFrame(display: number): void {
    if (!this.activeSessionId) {
      return;
    }
    if (this.previewFrameInFlight) {
      native.sessionNextRgba(this.activeSessionId, display);
      return;
    }
    const displayInfo = this.peerDisplays[display];
    const width = Math.max(Math.round(displayInfo?.width ?? 0), 0);
    const height = Math.max(Math.round(displayInfo?.height ?? 0), 0);
    if (width <= 0 || height <= 0) {
      native.sessionNextRgba(this.activeSessionId, display);
      return;
    }
    const expectedLength = width * height * 4;
    this.previewFrameInFlight = true;
    try {
      const rgbaSize = Number(native.sessionGetRgbaSize(this.activeSessionId, display));
      if (rgbaSize <= 0 || rgbaSize !== expectedLength) {
        if (rgbaSize > 0) {
          hilog.warn(
            DOMAIN,
            TAG,
            'consumePreviewRgbaFrame unexpected size display=%{public}d size=%{public}d expected=%{public}d',
            display,
            rgbaSize,
            expectedLength,
          );
        }
        this.previewFrameInFlight = false;
        native.sessionNextRgba(this.activeSessionId, display);
        return;
      }
      const rgbaPayload = native.sessionTakeRgbaFrame(this.activeSessionId, display) as Uint8Array | number[];
      const rgbaLength = rgbaPayload.length;
      if (rgbaLength !== expectedLength) {
        hilog.warn(
          DOMAIN,
          TAG,
          'consumePreviewRgbaFrame length mismatch display=%{public}d len=%{public}d expected=%{public}d',
          display,
          rgbaLength,
          expectedLength,
        );
        this.previewFrameInFlight = false;
        native.sessionNextRgba(this.activeSessionId, display);
        return;
      }
      const rgba = rgbaPayload instanceof Uint8Array
        ? rgbaPayload
        : Uint8Array.from(rgbaPayload);
      const options: image.InitializationOptions = {
        editable: false,
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width, height },
        alphaType: image.AlphaType.UNPREMUL,
      };
      image.createPixelMap(rgba.buffer, options)
        .then((pixelMap: image.PixelMap) => {
          this.updatePreviewFramePixelMap(pixelMap, width, height, display);
        })
        .catch((error: BusinessError) => {
          hilog.error(
            DOMAIN,
            TAG,
            'consumePreviewRgbaFrame createPixelMap failed display=%{public}d error=%{public}s',
            display,
            JSON.stringify(error) ?? String(error),
          );
        })
        .finally(() => {
          this.previewFrameInFlight = false;
          if (this.activeSessionId) {
            native.sessionNextRgba(this.activeSessionId, display);
          }
        });
    } catch (error) {
      this.previewFrameInFlight = false;
      hilog.error(
        DOMAIN,
        TAG,
        'consumePreviewRgbaFrame failed display=%{public}d error=%{public}s',
        display,
        String(error),
      );
      native.sessionNextRgba(this.activeSessionId, display);
    }
  }

  private handleFrameTransportEvent(event: NativeEvent): void {
    const display = Number(event.display ?? `${this.viewportModel.getCurrentDisplayIndex()}`);
    const currentDisplay = this.sessionDisplayController.getCurrentDisplayIndex();
    if (display !== currentDisplay) {
      if (event.name === 'rgba' && this.activeSessionId) {
        native.sessionNextRgba(this.activeSessionId, display);
      }
      return;
    }
    if (event.name === 'rgba') {
      this.consumePreviewRgbaFrame(display);
      return;
    }
    if (event.name === 'texture') {
      this.frameStatus = `Texture frame event display ${display}`;
    }
  }

  private sendRemoteKeyTap(name: string): void {
    if (!this.isRemoteControlSessionActive()) {
      return;
    }
    const downPayload = new RustDeskKeyPayload(name, true);
    const upPayload = new RustDeskKeyPayload(name, false);
    const downSent = this.sendKeyPayloadObject(downPayload);
    const upSent = this.sendKeyPayloadObject(upPayload);
    this.logRelativeDebug('fold_keyboard_button', `name=${name} down=${downSent} up=${upSent}`);
    this.requestPreviewInputFocus();
  }

  @Builder
  private previewTransformGestureLayer() {
    Column() {
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .hitTestBehavior(HitTestMode.Block)
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionStart((_event: GestureEvent) => {
            this.previewGestureStartOffsetX = this.previewUserOffsetX;
            this.previewGestureStartOffsetY = this.previewUserOffsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.previewUserOffsetX = this.clampPreviewOffsetX(this.previewGestureStartOffsetX + event.offsetX);
            this.previewUserOffsetY = this.clampPreviewOffsetY(this.previewGestureStartOffsetY + event.offsetY);
            this.syncPreviewViewTransform();
          }),
        PinchGesture({ fingers: 2, distance: 1 })
          .onActionStart((_event: GestureEvent) => {
            this.previewGestureStartScale = this.previewUserScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.previewUserScale = this.clampPreviewScale(this.previewGestureStartScale * event.scale);
            this.syncPreviewViewTransform();
          }),
        RotationGesture({ fingers: 2, angle: 1 })
          .onActionStart((_event: GestureEvent) => {
            this.previewGestureStartRotation = this.previewUserRotation;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.previewUserRotation = this.normalizePreviewUserRotation(
              this.previewGestureStartRotation + event.angle,
            );
            this.syncPreviewViewTransform();
          }),
      ),
    )
    .zIndex(15);
  }

  @Builder
  private androidNavigationOverlay() {
    if (this.androidNavigationAvailable() && this.androidNavigationVisible) {
      Stack() {
        AndroidNavigationBar({
          onBack: () => this.sendAndroidBack(),
          onHome: () => this.sendAndroidHome(),
          onRecent: () => this.sendAndroidRecentApps(),
          onHide: () => {
            this.androidNavigationVisible = false;
            this.preferences?.saveAndroidNavigationVisible(false);
          },
        });
      }
      .width(ANDROID_NAVIGATION_BAR_WIDTH)
      .height(ANDROID_NAVIGATION_BAR_HEIGHT)
      .position({ x: this.androidNavigationX, y: this.androidNavigationY })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 4 })
          .onActionStart((_event: GestureEvent): void => {
            this.androidNavigationDragStartX = this.androidNavigationX;
            this.androidNavigationDragStartY = this.androidNavigationY;
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.androidNavigationX = this.clampAndroidNavigationX(
              this.androidNavigationDragStartX + event.offsetX,
            );
            this.androidNavigationY = this.clampAndroidNavigationY(
              this.androidNavigationDragStartY + event.offsetY,
            );
          })
          .onActionEnd((_event: GestureEvent): void => {
            this.saveAndroidNavigationPosition();
          })
          .onActionCancel((): void => {
            this.saveAndroidNavigationPosition();
          }),
      )
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.94, y: 0.94 })))
      .zIndex(28);
    }
  }

  @Builder
  remotePreviewPane() {
    Stack({ alignContent: Alignment.Top }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.previewSurfaceVisible) {
          XComponent({
            id: `rustdesk-preview-surface-${this.previewSurfaceGeneration.toString()}`,
            type: XComponentType.SURFACE,
            controller: this.previewController
          })
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.black'))
            .scale({ x: this.previewUserScale, y: this.previewUserScale, centerX: '50%', centerY: '50%' })
            .rotate({ angle: this.previewUserRotation, centerX: '50%', centerY: '50%' })
            .translate({ x: this.previewUserOffsetX, y: this.previewUserOffsetY })
            .zIndex(0);
        } else {
          Text('Preparing preview...')
            .fontSize(14)
            .fontColor($r('app.color.white'));
        }

        if (this.previewFramePixelMap && this.rgbaFallbackActive) {
          Image(this.previewFramePixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .interpolation(ImageInterpolation.Medium)
            .scale({ x: this.previewUserScale, y: this.previewUserScale, centerX: '50%', centerY: '50%' })
            .rotate({ angle: this.previewUserRotation, centerX: '50%', centerY: '50%' })
            .translate({ x: this.previewUserOffsetX, y: this.previewUserOffsetY })
            .hitTestBehavior(HitTestMode.None)
            .zIndex(1);
        }

        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Row()
        }
        .id(PREVIEW_INPUT_FOCUS_ID)
        .width('100%')
        .height('100%')
        .padding(0)
        .backgroundColor($r('app.color.transparent'))
        .hoverEffect(HoverEffect.None)
        .hitTestBehavior(HitTestMode.Block)
        .focusable(true)
        .defaultFocus(true)
        .focusOnTouch(true)
        .onVisibleAreaChange([1.0], (_isExpanding: boolean, currentRatio: number): void => {
          if (currentRatio >= 0.999 && this.showPreviewModal) {
            this.requestPreviewInputFocus();
          }
        })
        .onFocus(() => {
          this.handlePreviewKeyboardFocus();
          this.logRelativeDebug('keyboard_focus', `focused id=${PREVIEW_INPUT_FOCUS_ID}`);
        })
        .onBlur(() => {
          this.handlePreviewKeyboardBlur();
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
          this.updateAndroidNavigationViewport(width, height);
          this.applyDisplayConfiguration();
          this.reprojectVirtualCursorOverlay();
        })
        .zIndex(10);

        if (this.previewTransformMode) {
          this.previewTransformGestureLayer();
        }

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
            .fill($r('app.color.white'))
            .stroke($r('app.color.black'))
            .strokeWidth(1.4)
            .opacity(1)
            .position({
              x: this.remoteCursorLeft - this.getFallbackCursorWidth() / 2,
              y: this.remoteCursorTop - this.getFallbackCursorHeight() / 2
            })
            .hitTestBehavior(HitTestMode.None)
            .zIndex(20);
        }

        if (this.softKeyboardVisible && this.softKeyboardAvailable()) {
          Row() {
            RemoteSoftKeyboard({
              keyboardWidth: this.softKeyboardWidth(),
              dockTop: this.softKeyboardDockTop,
              onKey: (
                name: string,
                down: boolean,
                alt: boolean,
                ctrl: boolean,
                shift: boolean,
                command: boolean,
              ): void => this.sendSoftKeyboardKey(name, down, alt, ctrl, shift, command),
              onMoveDock: (): void => this.moveSoftKeyboardToOtherEdge(),
              onCollapse: (): void => this.toggleSoftKeyboard(),
            });
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .position({ x: 0, y: this.softKeyboardOffsetY() })
          .hitTestBehavior(HitTestMode.Block)
          .zIndex(40);
        }
      }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.black'));

      this.androidNavigationOverlay();
      this.previewMiniBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.black'));
  }

  @Builder
  previewMiniBar() {
    if (this.isMiniBarExpanded) {
      Row() {
        Column({ space: 10 }) {
          SessionToolbar({
            relativeMouseMode: this.relativeMouseMode,
            metrics: this.sessionToolbarMetrics(),
            activeOverlayPanel: this.activeOverlayPanel,
            chatTransitionId: SESSION_OVERLAY_TRANSITION_CHAT,
            displayTransitionId: SESSION_OVERLAY_TRANSITION_DISPLAY,
            qualityTransitionId: SESSION_OVERLAY_TRANSITION_QUALITY,
            unreadCount: this.chatRevision >= 0 ? this.chatStore.unreadCount() : 0,
            cameraSession: this.activeSessionKind === 'view_camera',
            viewOnlySession: this.activeSessionKind === 'view_only',
            androidNavigationAvailable: this.androidNavigationAvailable(),
            androidNavigationVisible: this.androidNavigationVisible,
            softKeyboardAvailable: this.softKeyboardAvailable(),
            softKeyboardVisible: this.softKeyboardVisible,
            audioAvailable: this.remoteAudioState.available,
            audioMuted: this.remoteAudioState.muted,
            wideLayout: this.activeSessionKind === 'remote_control' && this.previewViewWidth >= 700,
            transformSummary: this.previewTransformSummary(),
            transformMode: this.previewTransformMode,
            canResetTransform: this.hasPreviewViewTransform(),
            panelContentHeight: this.sessionOverlayContentHeight(),
            onTogglePointerMode: () => this.toggleRelativeMouseMode(),
            onToggleTransform: () => this.setPreviewTransformMode(!this.previewTransformMode),
            onResetTransform: () => this.resetPreviewViewTransform(),
            onOpenChat: () => this.openChatDrawer(),
            onAudioChange: (enabled: boolean) => this.setRemoteAudioEnabled(enabled),
            onOpenDisplay: () => this.openDisplaySheet(),
            onOpenQuality: () => this.openQualitySheet(),
            onToggleSoftKeyboard: () => this.toggleSoftKeyboard(),
            onToggleAndroidNavigation: () => {
              this.androidNavigationVisible = !this.androidNavigationVisible;
              this.preferences?.saveAndroidNavigationVisible(this.androidNavigationVisible);
            },
            onDisconnect: () => this.closeSession('已手动断开连接'),
            onMinimize: () => {
              this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                this.isMiniBarExpanded = false;
              });
            },
            content: () => {
              if (this.isOverlayPanelOpen('chat')) {
                this.chatOverlayPanel();
              } else if (this.isOverlayPanelOpen('display')) {
                this.displayOverlayPanel();
              } else if (this.isOverlayPanelOpen('quality')) {
                this.qualityOverlayPanel();
              }
            },
          });
        }
        .width('92%')
        .constraintSize({
          maxWidth: this.activeSessionKind === 'view_camera' || this.activeSessionKind === 'view_only'
            ? 420
            : (this.previewViewWidth >= 700 ? 580 : 380),
        })
        .padding($r('app.float.space_12'))
        .margin({ top: $r('app.float.space_16') })
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.68,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.mica_highlight'), 0],
            [$r('app.color.transparent'), 0.52],
            [$r('app.color.transparent'), 1],
          ],
        })
        .border({ width: 1, color: $r('app.color.mica_border') })
        .borderRadius($r('app.float.radius_24'))
        .clip(false)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.95, y: 0.95 })));
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .zIndex(30);
    } else {
      Row() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Stack({ alignContent: Alignment.Center }) {
            Stack()
              .width(36)
              .height(4)
              .backgroundColor($r('app.color.neu_text_secondary'))
              .borderRadius(2)
              .opacity(0.72);

            if (this.rootFocusedControl === 'mini-toolbar') {
              Row()
                .width('100%')
                .height('100%')
                .border({ width: 2, color: $r('app.color.focus_ring') })
                .borderRadius({
                  bottomLeft: $r('app.float.radius_14'),
                  bottomRight: $r('app.float.radius_14'),
                })
                .hitTestBehavior(HitTestMode.None);
            }
          }
          .width('100%')
          .height('100%');
        }
        .width(68)
        .height(28)
        .padding(0)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.68,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.mica_highlight'), 0],
            [$r('app.color.transparent'), 0.58],
            [$r('app.color.transparent'), 1],
          ],
        })
        .border({ width: 1, color: $r('app.color.mica_border') })
        .borderRadius({
          bottomLeft: $r('app.float.radius_14'),
          bottomRight: $r('app.float.radius_14'),
        })
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .hoverEffect(HoverEffect.None)
        .focusOnTouch(true)
        .accessibilityText('展开远控工具栏')
        .onFocus(() => this.setRootControlFocused('mini-toolbar', true))
        .onBlur(() => this.setRootControlFocused('mini-toolbar', false))
        .onClick((): void => {
          this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
            this.isMiniBarExpanded = true;
          });
        })
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -10 })));
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: -14 })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .zIndex(30);
    }
  }

  @Builder
  private FoldControlButton(
    label: string,
    _controlId: string,
    selected: boolean,
    danger: boolean,
    _selection: boolean,
    onClick: () => void,
  ) {
    Stack() {
      FloatingActionSurface({
        compact: true,
        selected: selected,
        accessibilityLabel: label,
        onActivate: onClick,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(danger
              ? $r('app.color.neu_danger')
              : (selected ? $r('app.color.neu_accent') : $r('app.color.neu_text_primary')));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .layoutWeight(1)
    .height($r('app.float.control_regular'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  foldHoverControlPane() {
    Column({ space: $r('app.float.space_12') }) {
      Row({ space: $r('app.float.space_12') }) {
        this.FoldControlButton(
          this.getPointerModeName(),
          'fold-pointer',
          this.relativeMouseMode,
          false,
          true,
          () => this.toggleRelativeMouseMode(),
        )
        this.FoldControlButton(
          '断开连接',
          'fold-disconnect',
          false,
          true,
          false,
          () => this.closeSession('已手动断开连接'),
        )
      }
      .width('100%');

      Row({ space: $r('app.float.space_8') }) {
        this.FoldControlButton('Esc', 'fold-esc', false, false, false,
          () => this.sendRemoteKeyTap('VK_ESCAPE'))
        this.FoldControlButton('Tab', 'fold-tab', false, false, false,
          () => this.sendRemoteKeyTap('VK_TAB'))
        this.FoldControlButton('Enter', 'fold-enter', false, false, false,
          () => this.sendRemoteKeyTap('VK_RETURN'))
      }
      .width('100%');

      Row({ space: $r('app.float.space_8') }) {
        this.FoldControlButton('Back', 'fold-back', false, false, false,
          () => this.sendRemoteKeyTap('VK_BACK'))
        this.FoldControlButton('Home', 'fold-home', false, false, false,
          () => this.sendRemoteKeyTap('VK_HOME'))
        this.FoldControlButton('End', 'fold-end', false, false, false,
          () => this.sendRemoteKeyTap('VK_END'))
      }
      .width('100%');

      Row({ space: $r('app.float.space_8') }) {
        this.FoldControlButton('←', 'fold-left', false, false, false,
          () => this.sendRemoteKeyTap('VK_LEFT'))
        this.FoldControlButton('↑', 'fold-up', false, false, false,
          () => this.sendRemoteKeyTap('VK_UP'))
        this.FoldControlButton('↓', 'fold-down', false, false, false,
          () => this.sendRemoteKeyTap('VK_DOWN'))
        this.FoldControlButton('→', 'fold-right', false, false, false,
          () => this.sendRemoteKeyTap('VK_RIGHT'))
      }
      .width('100%');

      Column() {
      }
      .width('100%')
      .layoutWeight(1)
      .focusable(true)
      .focusOnTouch(true)
      .backgroundColor($r('app.color.transparent'))
      .onKeyEvent((event: KeyEvent) => this.handlePreviewRootKeyEvent(event));
    }
    .width('100%')
    .height('100%')
    .padding({
      left: $r('app.float.space_20'),
      right: $r('app.float.space_20'),
      top: $r('app.float.space_16'),
      bottom: $r('app.float.space_16'),
    })
    .backgroundColor($r('app.color.background'))
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.handlePreviewRootKeyEvent(event));
  }

  @Builder
  private chatOverlayPanel() {
    SessionPanelFrame({
      title: '聊天',
      transitionId: SESSION_OVERLAY_TRANSITION_CHAT,
      onBack: () => this.closeOverlayPanel(),
    }) {
      ChatDrawer({
        messages: this.chatMessages(),
        draft: this.chatDraft,
        unreadCount: this.chatRevision >= 0 ? this.chatStore.unreadCount() : 0,
        onDraftChange: (value: string) => this.chatDraft = value,
        onSend: (value: string) => this.sendChatDraft(value),
        onRetry: (localId: string) => this.retryChat(localId),
        onClose: () => this.closeOverlayPanel(),
      });
    }
  }

  @Builder
  private RootFloatingAction(
    label: string,
    _controlId: string,
    danger: boolean,
    onClick: () => void,
  ) {
    Stack() {
      FloatingActionSurface({
        compact: true,
        accessibilityLabel: label,
        onActivate: onClick,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(danger ? $r('app.color.neu_danger') : $r('app.color.neu_text_primary'));
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.transparent'))
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .height($r('app.float.control_small'))
    .constraintSize({ minWidth: 104 })
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private transferWorkspaceBuilder() {
    HdsNavigation() {
      Column() {
        TransferDrawer({
          scroller: this.transferScroller,
          titleSpacerHeight: this.mainTitleSpacerHeight(),
          downloadRootPath: this.transferRootPath,
          rootStatus: this.transferRootStatus,
          sessionReady: this.transferSessionReady,
          sessionStatus: this.transferConnectionStatus,
          localEntries: this.transferLocalEntries,
          remoteDirectory: this.transferRemoteDirectory,
          remoteEntries: this.transferRemoteEntries,
          selectedLocalName: this.selectedTransferLocalName,
          selectedRemoteName: this.selectedTransferRemoteName,
          transfers: this.transferItems,
          bottomAvoidInset: this.windowBottomAvoidInset,
          onSelectLocal: (name: string) => this.selectTransferLocal(name),
          onSelectRemote: (name: string) => this.selectTransferRemote(name),
          onUpload: () => this.uploadSelectedTransferFile(),
          onDownload: () => this.downloadSelectedTransferFile(),
          onOpenRemoteDirectory: (name: string) => this.openTransferRemoteDirectory(name),
          onRemoteBack: () => this.openTransferParentDirectory(),
          onResolveOverride: (id: number, needOverride: boolean) => this.resolveTransferOverride(id, needOverride),
          onCancel: (id: number) => this.cancelTransfer(id),
          onClose: () => this.closeTransferWorkspace(),
        });
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.mainViewportWidth >= 840 ? $r('app.float.space_24') : $r('app.float.space_12'),
        right: this.mainViewportWidth >= 840 ? $r('app.float.space_24') : $r('app.float.space_12'),
        bottom: 0,
      })
      .backgroundColor($r('app.color.background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .titleBar({
      enableComponentSafeArea: !this.freeMultiWindow,
      avoidLayoutSafeArea: true,
      content: {
        stackBuilder: (): void => this.FreeWindowTitleBarStack(),
        title: {
          mainTitle: '文件传输',
          subTitle: `${this.transferSessionTarget || this.peerTarget} · ${this.transferSessionReady ? '已安全连接' : '正在连接'}`,
        },
        menu: {
          value: [{
            content: {
              label: '返回工作台',
              icon: $r('sys.symbol.chevron_left'),
              type: IconStyleMode.NORMAL,
              action: () => this.closeTransferWorkspace(),
            },
          }, {
            content: {
              label: '结束会话',
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.NORMAL,
              action: () => this.closeTransferSession(),
            },
          }],
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
    })
    .bindToScrollable([this.transferScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  @Builder
  private displayOverlayPanel() {
    SessionPanelFrame({
      title: '显示器与分辨率',
      transitionId: SESSION_OVERLAY_TRANSITION_DISPLAY,
      onBack: () => this.closeOverlayPanel(),
    }) {
      DisplaySelectorSheet({
        displays: this.sessionDisplayController.getDisplays(),
        currentDisplay: this.pendingDisplayIndex >= 0
          ? this.pendingDisplayIndex
          : this.sessionDisplayController.getCurrentDisplayIndex(),
        resolutions: this.sessionDisplayController.getResolutions(),
        selectedResolution: this.pendingResolutionWidth > 0 && this.pendingResolutionHeight > 0 ? {
          width: this.pendingResolutionWidth,
          height: this.pendingResolutionHeight,
        } : undefined,
        resolutionEnabled: this.activeSessionKind !== 'view_only'
          && this.sessionDisplayController.canChangeResolution(this.peerPlatform),
        viewOnlySession: this.activeSessionKind === 'view_only',
        onSelectDisplay: (index: number) => this.requestDisplaySelection(index),
        onSelectResolution: (resolution: ResolutionInfo) => this.requestResolutionChange(resolution),
        onClose: () => this.closeOverlayPanel(),
      });
    }
  }

  @Builder
  private qualityOverlayPanel() {
    SessionPanelFrame({
      title: '画质控制',
      transitionId: SESSION_OVERLAY_TRANSITION_QUALITY,
      onBack: () => this.closeOverlayPanel(),
    }) {
      QualityControlSheet({
        selectedPreset: this.selectedQualityPreset,
        customQuality: this.customQualityDraft,
        customFps: this.customFpsDraft,
        telemetry: this.qualityTelemetry,
        onSelectPreset: (preset: QualityPreset) => this.applyQualitySelection(preset),
        onCustomQualityChange: (value: number) => this.updateCustomQuality(value),
        onCustomFpsChange: (value: number) => this.updateCustomFps(value),
        onClose: () => this.closeOverlayPanel(),
      });
    }
  }

  private isWideMainLayout(): boolean {
    return this.mainViewportWidth >= 840;
  }

  private wideRailWidth(): number {
    return 88;
  }

  private wideRailFrameWidth(): number {
    return this.wideRailWidth() + LuminousNeoTokens.shadowPaddingFor(LuminousNeoTokens.BASE_SURFACE_SIZE) * 2;
  }

  private wideRailTopInset(): number {
    const titleBarInset = this.freeMultiWindow ? FREE_WINDOW_TITLE_BAR_HEIGHT_VP : 0;
    return titleBarInset + WIDE_RAIL_EDGE_INSET_VP;
  }

  private wideRailHeight(): number {
    const titleBarInset = this.freeMultiWindow ? FREE_WINDOW_TITLE_BAR_HEIGHT_VP : 0;
    return Math.max(1,
      this.mainViewportHeight - titleBarInset - WIDE_RAIL_EDGE_INSET_VP * 2);
  }

  private wideContentTitleSpacerHeight(): number {
    return Math.max(0, WIDE_RAIL_EDGE_INSET_VP - RustDeskLayoutTokens.PAGE_CONTENT_TOP_PADDING);
  }

  private wideRailItemSurfaceWidth(): number {
    // LuminousSurface 会在实体两侧预留完整阴影框；36vp 与当前页签高度的阴影安全区匹配。
    return this.wideRailWidth() - 36;
  }

  private wideRailItemSurfaceHeight(): number {
    return 54;
  }

  private wideRailItemFrameHeight(): number {
    return 68;
  }

  private openMainTab(index: number): void {
    if (index === this.currentTabIndex) {
      return;
    }
    this.mainTabTransitionDirection = index > this.currentTabIndex ? 1 : -1;
    if (!this.isWideMainLayout()) {
      this.hdsTabsController.changeIndex(index);
      return;
    }
    this.getUIContext().animateTo({
      duration: MAIN_PAGE_TRANSITION_DURATION_MS,
      curve: Curve.FastOutSlowIn,
    }, (): void => {
      this.currentTabIndex = index;
    });
  }

  private playRotationTransition(): void {
    this.getUIContext().keyframeAnimateTo({
      iterations: 1,
      onFinish: (): void => {
        this.rotationTransitionOpacity = 1;
        this.rotationTransitionScale = 1;
      },
    }, [{
      duration: ROTATION_TRANSITION_OUT_DURATION_MS,
      curve: Curve.FastOutLinearIn,
      event: (): void => {
        this.rotationTransitionOpacity = ROTATION_TRANSITION_MID_OPACITY;
        this.rotationTransitionScale = ROTATION_TRANSITION_MID_SCALE;
      },
    }, {
      duration: ROTATION_TRANSITION_IN_DURATION_MS,
      curve: Curve.LinearOutSlowIn,
      event: (): void => {
        this.rotationTransitionOpacity = 1;
        this.rotationTransitionScale = 1;
      },
    }]);
  }

  private updateMainViewport(newArea: Area): void {
    const width = Number(newArea.width);
    const height = Number(newArea.height);
    if (width > 0) {
      this.mainViewportWidth = width;
    }
    if (height > 0) {
      this.mainViewportHeight = height;
    }
    if (width <= 0 || height <= 0) {
      return;
    }
    const nextPortrait = height >= width;
    if (!this.viewportOrientationInitialized) {
      this.viewportOrientationInitialized = true;
      this.lastViewportPortrait = nextPortrait;
      return;
    }
    if (nextPortrait === this.lastViewportPortrait) {
      return;
    }
    this.lastViewportPortrait = nextPortrait;
    this.playRotationTransition();
  }

  private shouldShowPhoneMainTitleBar(): boolean {
    return deviceInfo.deviceType === 'phone' && !this.freeMultiWindow && !this.isWideMainLayout();
  }

  private mainNavigationTitle(): ResourceStr {
    if (this.currentTabIndex === 0) {
      return $r('app.string.navigation_home_title');
    }
    if (this.currentTabIndex === 1) {
      return '设备';
    }
    return '设置';
  }

  private mainNavigationSubtitle(): ResourceStr {
    if (this.currentTabIndex === 0) {
      return $r('app.string.navigation_home_subtitle');
    }
    if (this.currentTabIndex === 1) {
      return '最近、通讯簿与局域网';
    }
    return '连接、安全与体验';
  }

  private activeMainScrollers(): Scroller[] {
    if (this.currentTabIndex === 0) {
      return [this.connectScroller];
    }
    if (this.currentTabIndex === 1) {
      return [this.deviceRecentScroller, this.deviceAddressBookScroller, this.deviceLanScroller];
    }
    return [this.settingsScroller];
  }

  private mainTitleSpacerHeight(): number {
    if (this.shouldShowPhoneMainTitleBar()) {
      return 0;
    }
    if (this.freeMultiWindow) {
      return FREE_WINDOW_TITLE_BAR_HEIGHT_VP + this.wideContentTitleSpacerHeight();
    }
    if (this.isWideMainLayout()) {
      return this.wideContentTitleSpacerHeight();
    }
    return RustDeskLayoutTokens.PAGE_TITLE_SPACER;
  }

  private deviceTitleSpacerHeight(): number {
    if (this.shouldShowPhoneMainTitleBar()) {
      return 0;
    }
    if (this.freeMultiWindow) {
      return FREE_WINDOW_TITLE_BAR_HEIGHT_VP + this.wideContentTitleSpacerHeight();
    }
    if (this.isWideMainLayout()) {
      return this.wideContentTitleSpacerHeight();
    }
    return RustDeskLayoutTokens.DEVICE_PAGE_TITLE_SPACER;
  }

  private boundMainTitleSpacerHeight(): number {
    if (this.shouldShowPhoneMainTitleBar()) {
      return 0;
    }
    if (this.freeMultiWindow) {
      return FREE_WINDOW_TITLE_BAR_HEIGHT_VP + this.wideContentTitleSpacerHeight();
    }
    if (this.isWideMainLayout()) {
      return this.wideContentTitleSpacerHeight();
    }
    return RustDeskLayoutTokens.PAGE_TITLE_SPACER;
  }

  private mainTabBottomMargin(): number {
    return 24;
  }

  @Builder
  private ConnectPageContent() {
    ConnectTab({
      target: this.peerTarget,
      rememberPassword: this.rememberPassword,
      canDisconnect: this.activeSessionId.length > 0,
      transferActive: this.transferSessionReady,
      activeTransferPeerId: this.transferManager.isReady() ? this.transferSessionTarget : '',
      wideLayout: this.isWideMainLayout(),
      directorySnapshot: this.directorySnapshot,
      scroller: this.connectScroller,
      titleSpacerHeight: this.mainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      onTargetChange: (value: string) => this.updatePeerTarget(value),
      onConnectRemote: () => this.connectRemoteSession(),
      onViewOnly: () => this.connectViewOnlySession(),
      onViewCamera: () => this.connectCameraSession(),
      onOpenTransfer: () => this.openTransferWorkspace(),
      onDisconnect: () => this.closeSession('已手动断开连接'),
      onSetPeerFavorite: (peerId: string, favorite: boolean) => this.setPeerFavorite(peerId, favorite),
      onRemoveRecentPeer: (peerId: string) => this.removeRecentPeer(peerId),
      onConnectPeerRemote: (peerId: string) => this.launchPeer(peerId, 'remote_control'),
      onViewPeerOnly: (peerId: string) => this.launchPeer(peerId, 'view_only'),
      onViewPeerCamera: (peerId: string) => this.launchPeer(peerId, 'view_camera'),
      onOpenPeerTransfer: (peerId: string) => this.launchPeer(peerId, 'file_transfer'),
    })
  }

  @Builder
  private DevicesPageContent() {
    DeviceDirectoryPanel({
      snapshot: this.directorySnapshot,
      wideLayout: this.isWideMainLayout(),
      activeTransferPeerId: this.transferManager.isReady() ? this.transferSessionTarget : '',
      recentScroller: this.deviceRecentScroller,
      addressBookScroller: this.deviceAddressBookScroller,
      lanScroller: this.deviceLanScroller,
      titleSpacerHeight: this.deviceTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      onRefresh: () => this.refreshDirectorySnapshot(),
      onScanLan: () => this.scanLanPeers(),
      onSetFavorite: (peerId: string, favorite: boolean) => this.setPeerFavorite(peerId, favorite),
      onRemoveRecent: (peerId: string) => this.removeRecentPeer(peerId),
      onConnectRemote: (peerId: string) => this.launchPeer(peerId, 'remote_control'),
      onViewOnly: (peerId: string) => this.launchPeer(peerId, 'view_only'),
      onViewCamera: (peerId: string) => this.launchPeer(peerId, 'view_camera'),
      onOpenTransfer: (peerId: string) => this.launchPeer(peerId, 'file_transfer'),
    })
  }

  @Builder
  private SettingsPageContent() {
    SettingsTab({
      nativeVersion: this.nativeVersion,
      health: this.health,
      integrationStage: this.integrationStage,
      upstreamRepo: this.upstreamRepo,
      buildMarker: this.nativeBuildMarker,
      decoderCapabilities: this.decoderCapabilities,
      serverConfig: this.serverConfig,
      serverValidating: this.serverValidating,
      serverSaving: this.serverSaving,
      sessionDefaults: this.sessionDefaults,
      accountState: this.accountState,
      accountLoginProviders: this.accountLoginProviders,
      notes: this.notes,
      errorText: this.errorText,
      wideLayout: this.isWideMainLayout(),
      scroller: this.settingsScroller,
      titleSpacerHeight: this.boundMainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      onServerConfigChange: (config: ServerConfig) => this.serverConfig = config,
      onValidateServerConfig: (config: ServerConfig) => this.testServerConfiguration(config),
      onSaveServerConfig: (config: ServerConfig) => this.saveServerConfiguration(config),
      onSessionDefaultsChange: (defaults: SessionDefaults) => this.saveSessionDefaults(defaults),
      onAccountLogin: (username: string, password: string) => this.startAccountLogin(username, password),
      onAccountVerify: (code: string) => this.startAccountVerification(code),
      onAccountCancelChallenge: () => this.cancelAccountChallenge(),
      onAccountOidcLogin: (provider: string) => this.startAccountOidc(provider),
      onAccountOidcCancel: () => this.cancelAccountOidc(),
      onAddressBookSync: () => this.startAddressBookSync(),
      onAccountLogout: () => this.logoutAccount(),
      onRefresh: () => this.refreshNativeState(),
    })
  }

  @Builder
  private WideNavigationItem(index: number, name: string, icon: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: this.currentTabIndex === index ? -1 : 0,
        surfaceWidth: this.wideRailItemSurfaceWidth(),
        surfaceHeight: this.wideRailItemSurfaceHeight(),
        cornerRadius: 18,
        motionEnabled: true,
      }) {
        Column({ space: 4 }) {
          SymbolGlyph(icon)
            .fontSize(22)
            .fontColor([this.currentTabIndex === index
              ? $r('app.color.neu_accent')
              : $r('app.color.neu_text_secondary')]);
          Text(name)
            .fontSize(10)
            .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.currentTabIndex === index
              ? $r('app.color.neu_accent')
              : $r('app.color.neu_text_secondary'));
        }
        .width(this.wideRailItemSurfaceWidth())
        .height(this.wideRailItemSurfaceHeight())
        .justifyContent(FlexAlign.Center);
      }

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
      .width(this.wideRailItemSurfaceWidth())
      .height(this.wideRailItemSurfaceHeight())
      .padding(0)
      .backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.None)
      .borderRadius(18)
      .accessibilityText(name)
      .accessibilitySelected(this.currentTabIndex === index)
      .onClick((): void => this.openMainTab(index));
    }
    .width('100%')
    .height(this.wideRailItemFrameHeight())
    .clip(false);
  }

  @Builder
  private WideRailIdentity() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: 46,
        surfaceHeight: 46,
        cornerRadius: 16,
        motionEnabled: true,
      }) {
        Image($r('app.media.startIcon'))
          .width(34)
          .height(34)
          .borderRadius(11)
          .objectFit(ImageFit.Contain);
      }
    }
    .width('100%')
    .height(66)
    .clip(false)

  }

  @Builder
  private WideNavigationRail() {
    Stack() {
      FloatingGlassSurface({
        radius: $r('app.float.radius_24'),
        surfaceWidth: this.wideRailWidth(),
        surfaceHeight: this.wideRailHeight(),
      }) {
        Column({ space: 6 }) {
          Column({ space: 2 }) {
            this.WideRailIdentity();
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 8 });

          this.WideNavigationItem(0, '首页', $r('sys.symbol.house'))
          this.WideNavigationItem(1, '设备', $r('sys.symbol.person_crop_circle_fill'))
          this.WideNavigationItem(2, '设置', $r('sys.symbol.gearshape'))
          Blank()
          Text('安全连接')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.success'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 });
        }
        .width('100%')
        .height('100%')
        .padding({ left: 10, right: 10, top: 14, bottom: 16 });
      }
    }
    .width(this.wideRailWidth())
    .height(this.wideRailHeight())
    .borderRadius($r('app.float.radius_24'))
    .clip(false);
  }

  @Builder
  previewModalBuilder() {
    Stack() {
      if (this.isFoldHoverMode) {
        Column() {
          if (this.foldHoverUpperHeight > 0) {
            Stack() {
              this.remotePreviewPane();
            }
            .width('100%')
            .height(this.foldHoverUpperHeight)
            .backgroundColor($r('app.color.black'));

            if (this.foldHoverCreaseHeight > 0) {
              Column() {
              }
              .width('100%')
              .height(this.foldHoverCreaseHeight)
              .backgroundColor($r('app.color.black'));
            }
          } else {
            Stack() {
              this.remotePreviewPane();
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor($r('app.color.black'));
          }

          Stack() {
            if (this.activeSessionKind === 'remote_control') {
              this.foldHoverControlPane();
            } else if (this.activeSessionKind === 'view_only') {
              Column({ space: $r('app.float.space_12') }) {
                Text('只观看模式 · 触摸与键盘输入已关闭')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .textAlign(TextAlign.Center)
                  .width('100%');
                this.FoldControlButton('断开连接', 'fold-view-only-disconnect', false, true, false,
                  () => this.closeSession('已手动断开连接'));
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ left: $r('app.float.space_20'), right: $r('app.float.space_20') });
            } else {
              Text('摄像头预览')
                .fontSize(18)
                .fontColor($r('app.color.text_primary'));
            }
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.background'));
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.black'));
      } else {
        this.remotePreviewPane();
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.black'));
  }

  @Builder
  TabBuilder(index: number, name: string, icon: Resource) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.currentTabIndex === index
          ? $r('app.color.brand_primary')
          : $r('app.color.text_tertiary')])
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
      Text(name)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index
          ? $r('app.color.brand_primary')
          : $r('app.color.text_tertiary'))
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private FreeWindowTitleBar() {
    Row() {
      Row({ space: 9 }) {
        Image($r('app.media.resk'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
        Text('RustDesk')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('多窗')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.mica_control'))
          .borderRadius(6)
      }
        .height('100%')
        .padding({ left: 14 })

      Row() {
        Text(this.pcTitleStatusText())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
        .height('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onTouch((event: TouchEvent) => this.startMovingFreeWindow(event))
        .onMouse((event: MouseEvent) => this.startMovingFreeWindowByMouse(event))

      Row()
        .width(138)
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(FREE_WINDOW_TITLE_BAR_HEIGHT_VP)
    .backgroundColor($r('app.color.transparent'))
    .zIndex(1000)
  }

  @Builder
  private FreeWindowTitleBarStack() {
    if (this.freeMultiWindow) {
      this.FreeWindowTitleBar();
    }
  }

  @Builder
  private SelectedMainPage() {
    Stack() {
      if (this.currentTabIndex === 0) {
        Stack() {
          this.ConnectPageContent();
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: -this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
        ));
      } else if (this.currentTabIndex === 1) {
        Stack() {
          this.DevicesPageContent();
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: -this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
        ));
      } else {
        Stack() {
          this.SettingsPageContent();
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({
            x: -this.mainTabTransitionDirection * MAIN_PAGE_TRANSITION_DISTANCE_VP,
          })),
        ));
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private CompactMainTabs() {
    HdsTabs({ controller: this.hdsTabsController }) {
      TabContent() {
        this.ConnectPageContent();
      }
      .tabBar(this.TabBuilder(0, '首页', $r('sys.symbol.house')))

      TabContent() {
        this.DevicesPageContent();
      }
      .tabBar(this.TabBuilder(1, '设备', $r('sys.symbol.person_crop_circle_fill')))

      TabContent() {
        this.SettingsPageContent();
      }
      .tabBar(this.TabBuilder(2, '设置', $r('sys.symbol.gearshape')))
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .scrollable(false)
    .animationDuration(280)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    })
    .barFloatingStyle({
      barWidth: { smallWidth: 264, mediumWidth: 300, largeWidth: 328 },
      barBottomMargin: this.mainTabBottomMargin(),
      gradientMask: {
        maskColor: $r('app.color.tabs_gradient_mask'),
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      },
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'));
  }

  @Builder
  private MainNavigationBody() {
    if (this.isWideMainLayout()) {
      this.SelectedMainPage();
    } else {
      this.CompactMainTabs();
    }
  }

  @Builder
  private MainNavigationPane() {
    if (this.shouldShowPhoneMainTitleBar()) {
      HdsNavigation() {
        this.MainNavigationBody();
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .titleBar({
        enableComponentSafeArea: true,
        avoidLayoutSafeArea: true,
        content: {
          title: {
            mainTitle: this.mainNavigationTitle(),
            subTitle: this.mainNavigationSubtitle(),
          },
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: $r('app.color.transparent'),
              maskExtraHeight: 0,
              blurRadius: 0,
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('app.color.text_primary'),
                subTitleColor: $r('app.color.text_secondary'),
              },
              dividerStyle: {
                dividerColor: $r('app.color.transparent'),
              },
            },
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: $r('app.color.title_gradient_mask'),
              maskExtraHeight: 0,
              blurRadius: 16,
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('app.color.text_primary'),
                subTitleColor: $r('app.color.text_secondary'),
              },
              dividerStyle: {
                dividerColor: $r('app.color.transparent'),
              },
            },
          },
        },
      })
      .bindToScrollable(this.activeMainScrollers())
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.transparent'));
    } else {
      HdsNavigation() {
        this.MainNavigationBody();
      }
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.transparent'));
    }
  }

  @Builder
  private MainContent() {
    if (this.showTransferWorkspace) {
      this.transferWorkspaceBuilder();
    } else if (this.showPreviewModal) {
      this.previewModalBuilder();
    } else if (this.isWideMainLayout()) {
      Stack({ alignContent: Alignment.Top }) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            this.WideNavigationRail();
          }
          .width(this.wideRailFrameWidth())
          .height(this.wideRailHeight())
          .margin({ top: this.wideRailTopInset() })
          .clip(false)
          .zIndex(10);

          Stack({ alignContent: Alignment.Top }) {
            this.MainNavigationPane();
          }
          .layoutWeight(1)
          .height('100%')
          .zIndex(1);
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Top)
        .backgroundColor($r('app.color.transparent'));

        if (this.freeMultiWindow) {
          this.FreeWindowTitleBar();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.transparent'));
    } else {
      Stack({ alignContent: Alignment.Top }) {
        this.MainNavigationPane();
        if (this.freeMultiWindow) {
          this.FreeWindowTitleBar();
        }
      }
      .width('100%')
      .height('100%');
    }
  }

  build() {
    Stack() {
      Stack({ alignContent: Alignment.Top }) {
        this.MainContent();
        if (this.freeMultiWindow && this.showPreviewModal) {
          this.FreeWindowTitleBar();
        }
      }
      .width('100%')
      .height('100%')
      .opacity(this.rotationTransitionOpacity)
      .scale({ x: this.rotationTransitionScale, y: this.rotationTransitionScale })
      .zIndex(1)

      ConnectionAttemptOverlay({
        visible: this.connectionUiPhase !== 'idle' && !this.showPreviewModal && !this.passwordDialogVisible,
        phase: this.connectionUiPhase,
        target: this.connectionUiTarget,
        message: this.connectionUiMessage,
        bottomAvoidInset: this.windowBottomAvoidInset,
        onCancel: () => this.cancelConnectionAttempt(),
        onRetry: () => this.retryConnectionAttempt(),
        onDismiss: () => this.dismissConnectionAttempt(),
      })
      .zIndex(1500)

      PasswordDialog({
        visible: this.passwordDialogVisible,
        password: this.passwordDraft,
        rememberPassword: this.rememberPassword,
        onPasswordChange: (value: string) => this.passwordDraft = value,
        onRememberChange: (value: boolean) => this.rememberPassword = value,
        onCancel: () => this.cancelPasswordDialog(),
        onSubmit: () => this.submitPassword(),
      })
      .zIndex(2000)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.updateMainViewport(newArea);
    })
  }
}
