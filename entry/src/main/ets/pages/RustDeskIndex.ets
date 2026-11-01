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
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError, Callback, deviceInfo } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { inputMethod } from '@kit.IMEKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  LuminousNeoTokens,
  LuminousSurface,
} from 'luminous_neo';
import { ConnectTab } from './rustdesk/components/ConnectTab';
import { DeviceDirectoryPanel } from './rustdesk/components/DeviceDirectoryPanel';
import { AuthDialogMode, PasswordDialog } from './rustdesk/components/PasswordDialog';
import { DirectCredentialsDialog } from './rustdesk/components/DirectCredentialsDialog';
import { ConnectionAttemptOverlay } from './rustdesk/components/ConnectionAttemptOverlay';
import { InsecureConnectionDialog } from './rustdesk/components/InsecureConnectionDialog';
import { SettingsTab } from './rustdesk/components/SettingsTab';
import { ViewedHostPage } from './rustdesk/components/ViewedHostPage';
import { SessionToolbar } from './rustdesk/components/SessionToolbar';
import {
  RemoteSessionResumeChip,
} from './rustdesk/components/RemoteSessionWorkspace';
import {
  ANDROID_NAVIGATION_BAR_HEIGHT,
  ANDROID_NAVIGATION_BAR_WIDTH,
  ANDROID_NAVIGATION_COLLAPSED_HEIGHT,
  ANDROID_NAVIGATION_COLLAPSED_WIDTH,
  AndroidNavigationBar,
} from './rustdesk/components/AndroidNavigationBar';
import {
  REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT,
  RemoteSoftKeyboard,
} from './rustdesk/components/RemoteSoftKeyboard';
import { DisplaySelectorSheet } from './rustdesk/components/DisplaySelectorSheet';
import { QualityControlSheet } from './rustdesk/components/QualityControlSheet';
import { SessionPanelFrame } from './rustdesk/components/SessionPanelFrame';
import { TransferDrawer } from './rustdesk/components/TransferDrawer';
import { RustDeskPreferences } from './rustdesk/RustDeskPreferences';
import {
  defaultRefreshRateFor,
  isValidRefreshRate,
  resolveRefreshRateChoices,
} from './rustdesk/RustDeskRefreshRate';
import { RustDeskLayoutTokens } from './rustdesk/RustDeskLayoutTokens';
import {
  DirectWireCredentials,
  DirectWireProtocol,
  checkRdpUser,
  directDialTarget,
  isDirectWireKind,
  targetFieldIssue,
  targetFieldIssueText,
} from './rustdesk/DirectWireCredentials';
import { RdpCertificateChallenge, rdpCertificateChallengeFromEvent, rdpCertificateTrustKey } from './rustdesk/RdpCertificateTrust';
import { RustDeskMainBridge } from './rustdesk/RustDeskMainBridge';
import {
  RustDeskRuntimeObserver,
  RustDeskRuntimeState,
  rustDeskRuntimeController,
} from '../services/RustDeskRuntimeController';
import {
  ApprovedServerProfile,
  DirectorySnapshot,
  DirectoryWriteReply,
  PeerProtocol,
  PeerRecord,
  RustDeskInputMode,
  RustDeskRightClickGesture,
  ServerConfig,
  ServerProfileReply,
  ServerProfileState,
  SessionDefaults,
} from './rustdesk/RustDeskDirectoryTypes';
import {
  applyPeerOnlineStates,
  bareTargetAddress,
  buildFavoritePeers,
  collectPeerOnlineIds,
  peerProjectionListsEqual,
  preservePeerOnlineStates,
} from './rustdesk/RustDeskPeerDirectoryModel';
import { computeRdpDesktopSize, computeRdpScaleFactor, copySessionDefaults, swapDefaultDirectPort } from './rustdesk/DirectSessionSettings';
import { invalidatesRdpUsernameCache, migrateDeviceRecord, savedDeviceKey } from './rustdesk/SavedDeviceModel';
import { DeviceLivenessProbe } from '../services/DeviceLivenessProbe';
import { copyPeerRecord, peerProtocolOf } from './rustdesk/RustDeskPeerDirectoryModel';
import { RustDeskSurfaceController } from './rustdesk/RustDeskSurfaceController';
import { RustDeskInputController } from './rustdesk/RustDeskInputController';
import {
  RUSTDESK_IME_INITIAL_TEXT,
  RustDeskImeInputController,
  RustDeskImeInputDelta,
} from './rustdesk/RustDeskImeInputController';
import { RustDeskCursorModel } from './rustdesk/RustDeskCursorModel';
import {
  RustDeskClipboardController,
  RustDeskRemoteClipboardPayload,
  RustDeskSystemClipboardHost,
  carriesRichClipboard,
  clipboardTextSyncAllowed,
} from './rustdesk/RustDeskClipboardController';
import {
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskSize,
} from './rustdesk/RustDeskInputMapper';
import {
  computeSurfaceGeometry,
  RustDeskDisplayMode,
  RustDeskViewportModel,
} from './rustdesk/RustDeskViewportModel';
import {
  RemoteSessionOrientationMode,
  RemoteSessionOrientationPolicy,
} from './rustdesk/RemoteSessionOrientationPolicy';
import { RustDeskNativeSessionBridge } from './rustdesk/NativeSessionBridge';
import {
  RemoteSessionTab,
  RemoteSessionTabsController,
} from './rustdesk/RemoteSessionTabsController';
import { DownloadRootManager } from './rustdesk/DownloadRootManager';
import { TransferManager } from './rustdesk/TransferManager';
import { RemoteFilePath } from './rustdesk/RemoteFilePath';
import { TransferProgress } from './rustdesk/TransferProgress';
import {
  FloatingActionSurface,
  FloatingGlassSurface,
} from './rustdesk/components/FloatingSurface';
import { DEFAULT_REFRESH_RATE, matchesResolutionRefusal, SessionDisplayController } from './rustdesk/SessionDisplayController';
import { FrameRateTelemetry } from '../services/FrameRateTelemetry';
import { SessionOverlayPanel, SessionOverlayState } from './rustdesk/SessionOverlayState';
import { formatSessionToolbarMetrics, SessionToolbarMetrics } from './rustdesk/SessionToolbarMetrics';
import {
  applyFrameRateSnapshot,
  clearQualityFrameMetrics,
  emptyQualityTelemetry,
  mergeQualityStatus,
  DownloadRoot,
  LocalFileEntry,
  QualityTelemetry,
  RemoteAudioState,
  RemoteFileEntry,
  SessionStartOptions,
  TransferItem,
} from './rustdesk/RustDeskSessionTypes';
import {
  DATA_TRANSFER_BACKGROUND_BIND_EVENT,
  DATA_TRANSFER_BACKGROUND_CHANGE_EVENT,
  DATA_TRANSFER_BACKGROUND_UNBIND_EVENT,
  DataTransferBackgroundBinding,
} from '../services/DataTransferBackgroundService';
import {
  REMOTE_SESSION_APP_STATE_EVENT,
  REMOTE_SESSION_CONTINUE_HANDOFF_EVENT,
  REMOTE_SESSION_CONTINUE_STATE_EVENT,
  REMOTE_SESSION_HANDOFF_EVENT,
  RemoteSessionHandoffEnvelope,
  RemoteSessionHandoffService,
  RemoteSessionShareController,
  RemoteSessionShareSnapshot,
} from '../services/RemoteSessionHandoffService';
import {
  ControlledPasswordMode,
  ControlledTrustedDevice,
} from '../services/controlled/ControlledHostTypes';
import { controlledHostCoordinator } from '../services/controlled/ControlledHostCoordinator';
import {
  EASYTIER_API_RESULT_EVENT,
  EASYTIER_OPERATION_START_INSTANCE,
  EASYTIER_SNAPSHOT_EVENT,
  EASYTIER_STATE_RUNNING,
  EasyTierApiRequestOutcome,
  EasyTierApiResultEvent,
  EasyTierApiService,
  EasyTierConnectionIntent,
  EasyTierConnectionKind,
  EasyTierInstanceSummary,
  EasyTierSnapshotEvent,
} from '../services/EasyTierApiService';
import {
  ActionResponse,
  DecoderCapability,
  DOMAIN,
  EVENT_POLL_INTERVAL_MS,
  NativeEvent,
  PASSWORD_TIMEOUT_MS,
  PeerDisplayInfo,
  ResolutionInfo,
  SavedConnectionSettings,
  TAG,
} from './rustdesk/RustDeskTypes';

const REMOTE_CURSOR_LOG_SAMPLE_EVERY = 10;
const REMOTE_CURSOR_MIN_VISIBLE_SIZE = 12;
const FALLBACK_CURSOR_BASE_WIDTH = 18;
const FALLBACK_CURSOR_BASE_HEIGHT = 24;
const REMOTE_CURSOR_OPTION_REAPPLY_MS = 1000;
const WAITING_FOR_IMAGE_TEXT = 'Connected, waiting for image...';
const PREVIEW_INPUT_FOCUS_ID = 'rustdesk-preview-input-layer';
const SYSTEM_IME_INPUT_FOCUS_ID = 'rustdesk-system-ime-input';
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
/**
 * How often an unconfirmed XComponent detach is retried.
 *
 * The native side keeps the binding and the same instance for exactly this, so
 * the id is retried rather than dropped on an unconfirmed unregistration.
 */
const COMPONENT_DETACH_RETRY_LIMIT = 20;
const COMPONENT_DETACH_RETRY_INTERVAL_MS = 250;
/**
 * How long a close waits for a producer that still owes a join.
 *
 * The Surface may only be destroyed once every destination is released, and a
 * producer that has not finished its own teardown keeps its destination held, so
 * the caller polls instead of claiming a release nobody reported.
 */
const SURFACE_RELEASE_WAIT_ATTEMPTS = 40;
const SURFACE_RELEASE_WAIT_INTERVAL_MS = 100;
const ANDROID_NAVIGATION_BOTTOM_OFFSET = 80;
const ANDROID_NAVIGATION_EDGE_MARGIN = 12;
/**
 * The floating session toolbar's collapsed entry. Every device and orientation
 * shows the same vertical grab tab, docked to the pane's right edge. The tab is
 * 28 wide; the node that carries it is 44 so the touch target is not narrow.
 */
const MINI_BAR_COLLAPSED_WIDTH = 28;
const MINI_BAR_COLLAPSED_HEIGHT = 68;
const MINI_BAR_COLLAPSED_TOUCH_WIDTH = 44;
/**
 * The collapsed entry's top baseline, and the offset the status-bar band adds to
 * it, so the tab never lands under the system bar.
 */
const MINI_BAR_TOP_BASELINE = 80;
const MINI_BAR_TOP_AVOID_OFFSET = 60;
/** The gap the toolbar keeps below the pane's bottom edge. */
const MINI_BAR_BOTTOM_MARGIN = 8;
/** The expanded panel keeps the toolbar's responsive width. */
const MINI_BAR_EXPANDED_WIDTH_RATIO = 0.95;
/** The expanded panel's own inset, on all four sides. */
const MINI_BAR_EXPANDED_PADDING = 10;
/**
 * The toolbar chrome (header row, the gaps between sections, the session tab
 * bar) used before the toolbar has reported what it measured.
 *
 * It only covers the first layout of the first expansion, and it is the
 * layout's own numbers rather than a guess: a 32 tall header, two 6 gaps and
 * the 50 tall tab bar.
 */
const SESSION_TOOLBAR_CHROME_FALLBACK_HEIGHT = 94;
const ANDROID_RECENT_PRESS_DURATION_MS = 500;
const BACKGROUND_SESSION_POLL_INTERVAL_MS = 250;
const NEW_REMOTE_SESSION_SWITCH_TARGET = '__new_remote_session__';


// Every session this client opens is interactive: VNC and RDP are selected by the
// connection mode bar, not by a scheme typed into the target, so they render and
// take input through the same path as a RustDesk session.
type PrimarySessionKind = 'remote_control' | 'vnc' | 'rdp';
type PasswordSessionKind = 'primary' | 'file_transfer';
type PeerLaunchKind = EasyTierConnectionKind;
type ConnectionUiPhase = 'idle' | 'waiting_for_easytier' | 'connecting'
  | 'awaiting_password' | 'authenticating' | 'connected' | 'failed';

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
  /** This module owns an installed interceptor. */
  active?: boolean;
  /** A key arriving now would really be captured; the phase `active` alone does not say. */
  admitting?: boolean;
  /**
   * Capture was closed on purpose (stop or a revocation).
   *
   * A sealed poll answers `ok:false` and discards its queue: keys captured before
   * the seal must not be forwarded, so the caller releases what it still holds and
   * stops instead of reading events.
   */
  sealed?: boolean;
  result?: number;
  events?: InterceptedKeyEvent[];
  /** True when the bounded native callback queue overflowed; admission is then closed. */
  overflow?: boolean;
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
  private sessionDisplayController: SessionDisplayController = new SessionDisplayController(
    this.viewportModel,
    this.nativeSessionBridge,
    () => { this.invalidatePreviewFrames(); },
    (response: ActionResponse) => this.updateSessionState(response),
  );
  private cursorModel: RustDeskCursorModel = new RustDeskCursorModel();
  private mainBridge: RustDeskMainBridge = new RustDeskMainBridge();
  private remoteSessionShareController: RemoteSessionShareController = new RemoteSessionShareController();
  private activeSessionDefaults: SessionDefaults = new SessionDefaults();
  private inputController?: RustDeskInputController;
  private imeInputController: RustDeskImeInputController = new RustDeskImeInputController();
  private systemImeTextController: TextInputController = new TextInputController();
  private clipboardController?: RustDeskClipboardController;
  private clipboardFileRootSessionId: string = '';
  /**
   * Sessions whose peer clipboard was updated while they were not the active tab.
   *
   * A direct wire's take is non-consuming and its notification is emitted once per
   * peer revision, so the notification the background poll consumes is remembered
   * here: the session's retained mailbox is retrieved and applied when that session
   * becomes active, before its own local clipboard is read. Only the fact is kept,
   * never a payload — the text stays in the session's own mailbox.
   */
  private readonly clipboardPeerUpdateSessions: Set<string> = new Set();
  private preferences?: RustDeskPreferences;
  private connectScroller: Scroller = new Scroller();
  private deviceRecentScroller: Scroller = new Scroller();
  private deviceFavoriteScroller: Scroller = new Scroller();
  private deviceLanScroller: Scroller = new Scroller();
  private deviceAddressBookScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private viewedHostScroller: Scroller = new Scroller();
  private transferScroller: Scroller = new Scroller();
  private keyboardEnteredSessionId: string = '';
  private lastKeyboardFocusLogAt: number = 0;
  @Local pageVisible: boolean = true;
  private appForeground: boolean = true;
  private remoteSessionHandoffListenerRegistered: boolean = false;
  private remoteSessionSharingActive: boolean = false;
  private remoteSessionContinuationActive: boolean = false;
  private activeSessionPassword: string = '';
  private activeSessionShareTarget: string = '';
  private activeSessionShareTargetKind: string = 'target';
  private activeSessionRustdeskIdOnly: boolean = false;
  private activeSessionServerConfig: ServerConfig = new ServerConfig();
  private activeSessionPasswordEphemeral: boolean = false;
  private handoffPasswordAutoSubmitAttempted: boolean = false;
  private activeSessionForceRelay: boolean = false;
  private remoteInteractionReady: boolean = false;
  private inputInterceptorActive: boolean = false;
  private previewKeyboardCaptureFocused: boolean = false;
  private previewKeyboardBlurTimer: number = -1;
  private systemImeBlurTimer: number = -1;
  private softKeyboardPressedKeys: string[] = [];
  /**
   * The modifier latches the remote soft keyboard draws.
   *
   * They are the keys the engine accepted a Down for, so they have to be
   * observable: the panel toggles a modifier from the state it is told here,
   * and a latch that never reached the panel would keep asking for a Down.
   */
  @Local softKeyboardAltActive: boolean = false;
  @Local softKeyboardCtrlActive: boolean = false;
  @Local softKeyboardShiftActive: boolean = false;
  @Local softKeyboardCommandActive: boolean = false;
  private lanScanGeneration: number = 0;
  private lanScanActive: boolean = false;
  private lanScanPollTimer: number = -1;
  private serverTestTimer: number = -1;
  private serverTestGeneration: number = 0;
  private systemImeCaretTimer: number = -1;
  private peerOnlinePollTimer: number = -1;
  private peerOnlinePollGeneration: number = 0;
  private peerOnlinePollInFlight: boolean = false;
  private deviceLivenessProbe: DeviceLivenessProbe = new DeviceLivenessProbe();
  private savedDevices: PeerRecord[] | undefined = undefined;
  private rdpFollowResizeTimer: number = -1;
  private lastPeerProbeStartedAt: number = 0;
  private directoryMigrationOwner: string = '';
  private directoryMigrationInFlight: boolean = false;
  // The route captured for the attempt being registered, frozen from the page's approval.
  private activeSessionApprovedProfile: ApprovedServerProfile | undefined = undefined;
  @Local directAudioCapability: string = '';
  @Local directQualityDefaults: SessionDefaults = new SessionDefaults();
  private sessionReturnTabIndex: number = 0;
  private lastBackgroundSessionPollAt: number = 0;
  private remoteSessionTabsController: RemoteSessionTabsController = new RemoteSessionTabsController(6);

  @Local currentTabIndex: number = 0;
  @Local firstLaunchTutorialPending: boolean = false;
  @Local firstLaunchTutorialRequest: number = 0;
  @Local mainTabTransitionDirection: number = 1;
  @Local mainViewportWidth: number = 390;
  @Local mainViewportHeight: number = 844;
  @Local rotationTransitionOpacity: number = 1;
  @Local rotationTransitionScale: number = 1;
  @Local windowTopAvoidInset: number = 0;
  @Local windowBottomAvoidInset: number = 0;
  @Local windowCutoutLeftWidth: number = 0;
  @Local windowCutoutRightWidth: number = 0;
  @Local rootFocusedControl: string = '';
  private viewportOrientationInitialized: boolean = false;
  private firstLaunchTutorialSchedulePending: boolean = false;
  private lastViewportPortrait: boolean = true;

  @Local apiServer: string = '';
  @Local decoderCapabilities: DecoderCapability[] = [];
  @Local errorText: string = '';
  @Local serverConfig: ServerConfig = new ServerConfig();
  /** The approval this page holds; the editable draft in `serverConfig` never changes it. */
  @Local serverProfile: ServerProfileState = new ServerProfileState();
  @Local serverValidating: boolean = false;
  @Local serverSaving: boolean = false;
  @Local directorySnapshot: DirectorySnapshot = new DirectorySnapshot();
  private directoryRevision: number = 0;
  @Local sessionDefaults: SessionDefaults = new SessionDefaults();
  @Local clipboardSyncEnabled: boolean = true;

  @Local peerTarget: string = '';
  @Local connectPageMode: number = 0;
  @Local passwordDraft: string = '';
  @Local rememberPassword: boolean = false;

  @Local activeSessionId: string = '';
  @Local remoteSessionTabs: Array<RemoteSessionTab> = [];
  @Local activeCoreSessionId: string = '';
  @Local activeSessionKind: PrimarySessionKind = 'remote_control';
  @Local sessionPhase: string = 'idle';
  @Local sessionMessage: string = '未连接';
  @Local connectionSummary: string = '未连接';
  @Local connectionUiPhase: ConnectionUiPhase = 'idle';
  @Local connectionUiTarget: string = '';
  @Local connectionUiMessage: string = '';
  @Local isPolling: boolean = false;
  @Local frameStatus: string = 'Surface not ready';
  @Local frameWidth: number = 0;
  @Local frameHeight: number = 0;
  @Local showPreviewModal: boolean = false;
  @Local showTransferWorkspace: boolean = false;
  @Local previewSurfaceVisible: boolean = false;
  @Local previewSurfaceGeneration: number = 0;
  @Local touchMode: boolean = true;
  @Local relativeMouseMode: boolean = false;
  // Input is a local switch: turning it off stops every pointer and keyboard
  // emission without telling the peer, so it can be flipped back instantly.
  @Local inputEnabled: boolean = true;
  @Local rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Local previewViewWidth: number = 0;
  @Local previewViewHeight: number = 0;
  // How the remote frame is fitted into the pane.
  //
  // `fit` is the default because the video Surface is a fixed-size native
  // producer: its frame is composited into whatever rectangle it is measured at,
  // with no aspect correction. A surface laid out at the pane's size is
  // therefore a stretch by construction, and the mode has to change the measured
  // rectangle rather than a render hint.
  @Local previewDisplayMode: RustDeskDisplayMode = 'fit';
  // The rate the panel reports while a session runs, in Hz, or 0 when unknown.
  // The telemetry rows count what the decoder produced; this is the ceiling the
  // picture is actually shown at, and the two differ whenever the request is not
  // honoured.
  @Local panelRefreshRate: number = 0;
  @Local previewUserScale: number = 1;
  @Local previewUserOffsetX: number = 0;
  @Local previewUserOffsetY: number = 0;
  @Local previewUserRotation: number = 0;
  @Local previewFramePixelMap: image.PixelMap | undefined = undefined;
  @Local rgbaFallbackActive: boolean = false;
  @Local isFoldHoverMode: boolean = false;
  @Local softKeyboardVisible: boolean = false;
  @Local systemImeActive: boolean = false;
  @Local systemImeText: string = RUSTDESK_IME_INITIAL_TEXT;
  @Local softKeyboardDockTop: boolean = false;
  @Local softKeyboardX: number = 0;
  @Local softKeyboardY: number = 12;
  @Local foldHoverUpperHeight: number = 0;
  @Local foldHoverCreaseHeight: number = 0;

  // Private app readiness/admission only; not host, transfer or media success.
  private runtimeInitialized: boolean = false;
  private pagePreferencesInitialized: boolean = false;
  private runtimeObserverBound: boolean = false;
  private runtimeOwnerGeneration: string = '';
  private decoderCapabilityReport: string = '';
  private readonly onRuntimeStateChanged: RustDeskRuntimeObserver = (state: RustDeskRuntimeState): void => {
    this.applyRuntimeState(state);
  };
  private connectionGeneration: number = 0;
  private connectionTimeoutId: number = -1;
  private lastConnectionKind: PrimarySessionKind = 'remote_control';
  private lastConnectionRustdeskIdOnly: boolean = false;
  private connectionAttemptKind: PasswordSessionKind = 'primary';
  private sessionCloseInFlight: boolean = false;
  private sessionConnectInFlight: boolean = false;
  private sessionSwitchInFlight: boolean = false;
  private pendingSessionSwitchId: string = '';
  private readonly pendingClosedSessionIds: Array<string> = [];
  private pendingTransitionClose: boolean = false;
  private pollTimer: number = -1;
  private passwordTimeoutId: number = -1;
  private eventPollInFlight: boolean = false;
  private previewFrameInFlight: boolean = false;
  private performanceTuningApplied: boolean = false;
  private previewSurfaceId: string = '';
  /** The SurfaceHolder node binding id, separate from the decoder's Surface lease id. */
  private previewComponentId: string = '';
  private previewComponentDetachTimer: number = -1;
  private previewComponentDetachAttempts: number = 0;
  private previewComponentDetachIds: string[] = [];
  /**
   * Whether the current Surface's destroy was authorized by a confirmed release.
   *
   * A destroy without this flag is reported to the native side, which seals the
   * destinations that still held it rather than being told a release happened.
   */
  private previewSurfaceDestroyAuthorized: boolean = false;
  /**
   * The native side's own message for a refused Surface bind.
   *
   * A bind refusal carries only that message, so it is kept to be rendered as-is
   * instead of being replaced by a synthesized reason.
   */
  private previewSurfaceBindFailure: string = '';
  /** Native lifecycle epoch of the active session; bind/ACK echo it verbatim. */
  private activeSessionLifecycleEpoch: string = '';
  /** Engine input generation the active viewer published; RustDesk leaves it empty. */
  private activeInputGeneration: string = '';
  /**
   * Holds whose release this session attempted and the peer refused, as native
   * reported it. Empty means unknown: it is never assumed to be zero.
   */
  private activeInputHoldsOwed: string = '';
  private previewSurfaceSetupInFlight: boolean = false;
  private previewSurfaceSetupGeneration: number = -1;
  private pendingPreviewPeerInfo?: NativeEvent;
  private androidNavigationPositionInitialized: boolean = false;
  private androidNavigationDragStartX: number = 0;
  private androidNavigationDragStartY: number = 0;
  private softKeyboardDragStartX: number = 0;
  private softKeyboardDragStartY: number = 12;
  private lastAppliedDisplay: number = -1;
  private lastAppliedVideoWidth: number = 0;
  private lastAppliedVideoHeight: number = 0;
  @Local peerPlatform: string = '';
  private peerVersion: string = '';
  @Local peerDisplays: PeerDisplayInfo[] = [];
  @Local supportedResolutions: ResolutionInfo[] = [];
  @Local currentDisplayIndex: number = 0;
  @Local qualityTelemetry: QualityTelemetry = emptyQualityTelemetry();

  /** The XComponent id that carries the video Surface, for node lookups. */
  private previewSurfaceNodeId(): string {
    return `rustdesk-preview-surface-${this.previewSurfaceGeneration.toString()}`;
  }

  /** Declares the live node's expected draw rate, not measured rendering or scanout FPS. */
  private declarePanelFrameRate(): void {
    const componentId = this.previewComponentId;
    if (componentId.length === 0) {
      hilog.warn(DOMAIN, TAG, 'panel frame rate request skipped: no native XComponent scope');
      return;
    }
    const range: ExpectedFrameRateRange = this.previewFrameRateRange();
    try {
      const raw = native.xcomponentSetFrameRateRangeNative(componentId, range.expected, range.min, range.max);
      const response: ESObject = JSON.parse(raw);
      hilog.info(DOMAIN, TAG, 'panel_frame_rate_response=%{public}s', raw);
      const code = response.result === undefined ? 'unavailable' : String(response.result);
      this.panelRefreshRate = this.currentPanelRefreshRate();
      hilog.info(
        DOMAIN,
        TAG,
        'panel_frame_rate component=%{public}s expected=%{public}d min=%{public}d max=%{public}d code=%{public}s callbacks=%{public}d panel=%{public}d',
        componentId,
        range.expected,
        range.min,
        range.max,
        code,
        Number(response.frameCallbacks ?? 0),
        this.panelRefreshRate,
      );
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'panel frame rate request failed: %{public}s', String(error));
    }
  }

  /** Adopts the attached FrameNode through the native SurfaceHolder API. */
  private adoptPreviewSurfaceComponent(nodeId: string, controller: RustDeskSurfaceController): void {
    const frameNode = this.getUIContext().getAttachedFrameNodeById(nodeId);
    if (!frameNode) {
      hilog.warn(DOMAIN, TAG, 'panel node attach failed: no FrameNode for %{public}s', nodeId);
      return;
    }
    try {
      const raw = native.xcomponentAttach(nodeId, frameNode, controller.handleNativeSurfaceEvent);
      hilog.info(DOMAIN, TAG, 'panel_holder_attach=%{public}s', raw);
      const response: ESObject = JSON.parse(raw);
      const componentId = String(response.componentId ?? '');
      const adopted = response.ok === true && componentId.length > 0;
      // The native holder exists from the moment attach allocated it. When that
      // attach failed and its own cleanup is not confirmed (released is not true),
      // the componentId stays on this instance: a later detach is the only thing
      // that may release it, and dropping the id would lose the holder. A failed
      // attach never clears a component that already worked.
      if (adopted || (componentId.length > 0 && response.released !== true)) {
        controller.adoptedComponentId = componentId;
      }
      if (adopted) {
        this.previewComponentId = componentId;
      }
      if (!adopted && controller.adoptedComponentId.length > 0) {
        hilog.warn(DOMAIN, TAG, 'panel_holder_attach retained component=%{public}s for detach',
          controller.adoptedComponentId);
      }
      hilog.info(
        DOMAIN,
        TAG,
        'panel_native_attach ok=%{public}s adopted=%{public}s already=%{public}s component=%{public}s result=%{public}d',
        String(response.ok === true),
        String(adopted),
        String(response.alreadyAdopted === true),
        this.previewComponentId.length > 0 ? this.previewComponentId : '-',
        Number(response.result ?? -1),
      );
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'panel native attach failed: %{public}s', String(error));
    }
    this.declarePanelFrameRate();
  }

  /**
   * Retries a detach the native side did not confirm.
   *
   * Bounded: the binding and its instance are kept for the retry, and once the
   * attempts run out the id stays for the next lifecycle callback to retry.
   */
  private scheduleComponentDetachRetry(): void {
    if (this.previewComponentDetachTimer >= 0
      || this.previewComponentDetachAttempts >= COMPONENT_DETACH_RETRY_LIMIT
      || this.previewComponentDetachIds.length === 0) {
      return;
    }
    this.previewComponentDetachAttempts += 1;
    this.previewComponentDetachTimer = setTimeout((): void => {
      this.previewComponentDetachTimer = -1;
      const pendingIds = this.previewComponentDetachIds.slice();
      for (const id of pendingIds) {
        this.detachPreviewSurfaceComponent(id);
      }
    }, COMPONENT_DETACH_RETRY_INTERVAL_MS) as number;
  }

  /**
   * Releases the native XComponent scope.
   *
   * The id is dropped only when the native side confirms the drop: an
   * unconfirmed unregistration keeps the binding and the same instance exactly so
   * the detach can be retried, and a component that was never bound is a no-op.
   */
  private detachPreviewSurfaceComponent(componentId: string): void {
    if (componentId.length === 0) {
      return;
    }
    if (!this.previewComponentDetachIds.includes(componentId)) {
      this.previewComponentDetachIds.push(componentId);
    }
    try {
      const response: ESObject = JSON.parse(native.xcomponentDetach(componentId));
      // Only an explicit released:true is a completed detach. A held holder or an
      // unproven answer keeps the id so a later detach is still possible; the
      // native answer has no detached/alreadyDetached/unregisterResult field.
      const released = response.released === true;
      if (released) {
        if (this.previewComponentId === componentId) {
          this.previewComponentId = '';
        }
        this.previewComponentDetachIds = this.previewComponentDetachIds.filter((id: string): boolean => id !== componentId);
        if (this.previewComponentDetachIds.length === 0) {
          this.previewComponentDetachAttempts = 0;
        }
      } else {
        this.scheduleComponentDetachRetry();
      }
      hilog.info(
        DOMAIN,
        TAG,
        'panel_native_detach component=%{public}s ok=%{public}s released=%{public}s held=%{public}s error=%{public}s',
        componentId,
        String(response.ok === true),
        String(released),
        String(response.held === true),
        String(response.error ?? ''),
      );
    } catch (error) {
      this.scheduleComponentDetachRetry();
      hilog.warn(DOMAIN, TAG, 'panel native detach failed: %{public}s', String(error));
    }
  }

  /** The rate the panel is running at right now, or 0 when it cannot be read. */
  private currentPanelRefreshRate(): number {
    try {
      const rate = Number(display.getDefaultDisplaySync().refreshRate);
      return Number.isFinite(rate) && rate > 0 ? Math.round(rate) : 0;
    } catch (_error) {
      return 0;
    }
  }

  /**
   * The rate to ask for: the operator's choice, bounded by what the panel can
   * show, with the minimum left at 0 so the system may still drop for power.
   */
  private previewFrameRateRange(): ExpectedFrameRateRange {
    const choices = this.refreshRateChoices.length > 0
      ? this.refreshRateChoices
      : [DEFAULT_REFRESH_RATE];
    const maximum = choices[choices.length - 1];
    const wanted = Math.round(this.selectedRefreshRate);
    const expected = wanted > 0 && wanted <= maximum ? wanted : maximum;
    return { expected, min: 0, max: maximum };
  }

  private preferredCodec: string = 'auto';
  /**
   * Turns the engine's cumulative counters into per-second rates.
   *
   * The rows in the quality panel read the rates this produced, not the raw
   * counters: a cumulative total is not a frame rate, and the sampler is the
   * only place that owns the observation window.
   */
  private frameRateTelemetry: FrameRateTelemetry = new FrameRateTelemetry();
  private codecPreferenceApplied: boolean = false;
  @Local passwordDialogVisible: boolean = false;
  @Local authDialogMode: AuthDialogMode = 'password';
  private authChallengeMode: AuthDialogMode = 'password';
  @Local code2faDraft: string = '';
  @Local trustThisDevice: boolean = false;
  @Local canTrustDevice: boolean = true;
  @Local authErrorMessage: string = '';
  @Local insecureConnectionDialogVisible: boolean = false;
  @Local insecureConnectionMessage: string = '';
  private insecureConnectionSessionId: string = '';
  private passwordSessionKind: PasswordSessionKind = 'primary';
  @Local directCredentialsVisible: boolean = false;
  @Local directCredentialsProtocol: DirectWireProtocol = 'vnc';
  @Local directCredentialsTarget: string = '';
  @Local directCredentialsUsername: string = '';
  @Local directCredentialPassword: string = '';
  @Local directCredentialsError: ResourceStr = '';
  @Local rdpCertificateDialogVisible: boolean = false;
  @Local rdpCertificateChallenge: RdpCertificateChallenge | undefined = undefined;
  @Local rdpCertificateReplaceConfirmation: boolean = false;
  @Local rdpCertificateBusy: boolean = false;
  @Local rdpCertificateError: ResourceStr = '';
  private rdpCertificateSessionId: string = '';
  private rdpCertificateDecisionGeneration: number = 0;
  private rdpCredentialGeneration: number = 0;
  private rdpDialCredentials: DirectWireCredentials | undefined = undefined;
  private rdpCredentialPinOverride: string = '';
  private rdpCredentialPinOverrideTarget: string = '';
  private rdpCertificateCredentials: Map<string, DirectWireCredentials> = new Map<string, DirectWireCredentials>();
  private rdpCertificateRejectedSessions: Set<string> = new Set<string>();
  /**
   * The credentials one direct dial has already been given, held between the
   * dialog and the start call that consumes them.
   *
   * A direct viewer reads its password once, when it dials, so the answer cannot
   * arrive later: it waits here, is taken exactly once, and is dropped when the
   * session closes, when the dialog is cancelled and when a different request
   * replaces it. It is never persisted and never written into a target.
   */
  private pendingDirectCredentials: DirectWireCredentials | undefined = undefined;
  /**
   * The endpoint an answered RDP account belongs to.
   *
   * The account is not a secret, and this only lets the same endpoint offer it
   * back when it asks again; a different endpoint is never given another's.
   */
  private directWireUsernameTarget: string = '';
  /**
   * The failure one direct poll envelope reported, and the session it came from.
   *
   * The two travel together so the text can only ever be read for the session that
   * reported it: the poll walks every tab, and one wire's cause must never be
   * presented as another session's.
   */
  private directWireFailureText: string = '';
  private directWireFailureSessionId: string = '';
  /**
   * A retry that arrived while the failed attempt was still releasing its wire.
   *
   * A wrong credential is answered by closing and dialling a fresh viewer, so a
   * retry that lands during that close is remembered here and run once the
   * transition finishes instead of being dropped.
   */
  private pendingConnectionRetry: string = '';
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
  private manualSessionWindowImmersiveApplied: boolean = false;
  @Local sessionWindowControlCapable: boolean = false;
  @Local sessionWindowResizeCapable: boolean = false;
  @Local sessionWindowFullscreen: boolean = false;
  @Local sessionWindowControlBusy: boolean = false;
  @Local remoteCursorVisible: boolean = false;
  @Local remoteCursorLeft: number = 0;
  @Local remoteCursorTop: number = 0;
  @Local remoteCursorPixelMap: image.PixelMap | undefined = undefined;
  @Local remoteCursorBitmapWidth: number = 0;
  @Local remoteCursorBitmapHeight: number = 0;
  @Local remoteCursorHotX: number = 0;
  @Local remoteCursorHotY: number = 0;
  @Local isMiniBarExpanded: boolean = false;
  /**
   * The floating toolbar's anchor: the top-right corner it hangs from. Collapsed
   * and expanded share it, so the panel opens inward from where the tab sits and
   * a drag survives either state. Page-local only; never persisted.
   */
  @Local miniBarAnchorRight: number = 0;
  @Local miniBarAnchorTop: number = 0;
  /** The expanded panel's measured height, the bound that keeps it on screen. */
  @Local miniBarExpandedHeight: number = 0;
  /**
   * What the toolbar reports it spends on its own chrome: header row, the gaps
   * between sections and the session tab bar. The body budget is what is left
   * after it, so the value is measured rather than assumed.
   */
  @Local sessionToolbarChromeHeight: number = 0;
  private miniBarAnchorInitialized: boolean = false;
  private miniBarDragged: boolean = false;
  /** Where the visible state actually sits when the current drag began. */
  private miniBarDragStartX: number = 0;
  private miniBarDragStartY: number = 0;
  @Local androidNavigationVisible: boolean = true;
  @Local androidNavigationX: number = 0;
  @Local androidNavigationY: number = 0;
  private androidNavigationExpandedX: number = -1;
  private androidNavigationExpandedY: number = -1;
  private androidNavigationCollapsedX: number = -1;
  private androidNavigationCollapsedY: number = -1;
  @Local remoteKeyboardPermissionAllowed: boolean = true;
  private overlayState: SessionOverlayState = new SessionOverlayState();
  @Local activeOverlayPanel: SessionOverlayPanel = 'home';
  // The capture rate is the only picture control. Encoding quality is the
  // encoder's business: it spends whatever bandwidth the path can carry.
  @Local selectedRefreshRate: number = DEFAULT_REFRESH_RATE;
  @Local refreshRateChoices: number[] = [DEFAULT_REFRESH_RATE];
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
  @Local pendingDisplayIndex: number = -1;
  @Local pendingResolutionDisplay: number = -1;
  @Local pendingResolutionWidth: number = 0;
  @Local pendingResolutionHeight: number = 0;
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  @Local hdsMaterialAvailable: boolean = false;
  @Local easyTierDataAvailable: boolean = false;
  @Local easyTierPreconnectEnabled: boolean = false;
  @Local easyTierSelectedInstanceId: string = '';
  @Local easyTierSelectedInstanceName: string = '';
  @Local easyTierSelectedInstanceState: string = '';
  @Local easyTierStatusText: string = '';
  @Local easyTierRequestPending: boolean = false;
  @Local easyTierInstances: EasyTierInstanceSummary[] = [];
  private easyTierSnapshotFresh: boolean = false;
  private easyTierResultListenerRegistered: boolean = false;
  private onEasyTierApiResult = (result: EasyTierApiResultEvent): void => {
    EasyTierApiService.clearBufferedResult(result.requestId);
    void this.applyEasyTierApiResult(result);
  };
  private onEasyTierSnapshot = (snapshot: EasyTierSnapshotEvent): void => {
    this.applyEasyTierSnapshot(snapshot);
  };
  private onRemoteSessionHandoff = (): void => {
    const envelope = RemoteSessionHandoffService.takeIncoming();
    if (envelope !== undefined) {
      void this.connectRemoteSessionHandoff(envelope);
    }
  };
  private onRemoteSessionAppState = (foreground: boolean): void => {
    this.appForeground = foreground;
    if (foreground && this.pageVisible) {
      this.refreshDirectorySnapshot(true);
      if (this.showPreviewModal && this.activeSessionId.length > 0) {
        this.applyRemoteAudioPollingForKind(this.activeSessionKind);
        this.scheduleRdpFollowResize();
      }
    } else {
      this.discardAllRdpCertificateSecrets();
      this.discardDirectCredentialSecrets();
      this.directCredentialsVisible = false;
      this.stopPeerOnlinePolling();
      this.clearRdpFollowResize();
    }
    // Backgrounding is a clipboard admission change of its own: the page may stay
    // visible while the ability is no longer in front, and neither the peer's text
    // may be written to the system pasteboard nor a local read forwarded then.
    this.syncClipboardController();
    this.syncRemoteSessionSharing();
  };
  private onRemoteSessionContinueHandoff = (): void => {
    if (this.activeSessionId.length === 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'continuation payload delivered; closing source session');
    void this.closeSession('已接续到其他设备');
  };

  private detectHdsMaterialCapability(): void {
    this.hdsMaterialAvailable = false;
    if (deviceInfo.distributionOSApiVersion < 60100) {
      return;
    }
    try {
      this.hdsMaterialAvailable = hdsMaterial.getSystemMaterialTypes().length > 0;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'HDS material capability unavailable: %{public}s', String(error));
    }
  }

  aboutToAppear(): void {
    this.pageVisible = true;
    this.appForeground = rustDeskRuntimeController.state().foreground;
    this.detectHdsMaterialCapability();
    this.previewController = this.createPreviewSurfaceController(
      this.previewSurfaceGeneration,
      this.activeSessionId,
    );
    void this.initializeRuntime();
    this.registerRemoteSessionHandoffListener();
    this.registerEasyTierResultListener();
    this.registerWindowAvoidAreaListener();
    this.applySessionFullscreen(false, true);
    this.registerFreeWindowChrome();
    this.publishDataTransferBinding();
  }

  aboutToDisappear(): void {
    this.pageVisible = false;
    this.discardAllRdpCertificateSecrets();
    this.rejectPendingInsecureConnection();
    this.clearActiveSessionHandoffState();
    this.unregisterRemoteSessionHandoffListener();
    this.connectionGeneration += 1;
    this.clearConnectionTimeout();
    this.clearPasswordTimeout();
    this.clearPreviewKeyboardBlurTimer();
    this.clearRdpFollowResize();
    this.clearSystemImeCaretTimer();
    this.detachRuntimeObserver();
    this.serverTestGeneration += 1;
    this.clearServerTestTimer();
    this.stopPeerOnlinePolling();
    this.previewKeyboardCaptureFocused = false;
    this.hideSystemIme(false);
    this.releaseSoftKeyboardKeys();
    this.stopInputInterceptor();
    this.clipboardController?.reset();
    this.clipboardFileRootSessionId = '';
    this.clipboardPeerUpdateSessions.clear();
    this.setSessionKeyboardEntered(false);
    this.unregisterWindowAvoidAreaListener();
    this.unregisterFoldHoverListeners();
    this.clearSurfaceBinding();
    this.stopPolling();
    this.closeTransferSession();
    this.closeRemoteAudio();
    this.unregisterEasyTierResultListener();
    this.publishDataTransferUnbind();
    void this.applySessionFullscreen(false)
      .finally((): void => {
        this.unregisterFreeWindowChrome();
      });
  }

  onPageShow(): void {
    this.pageVisible = true;
    this.appForeground = rustDeskRuntimeController.state().foreground;
    void this.initializeRuntime();
    this.syncClipboardController();
    this.syncInputInterceptor();
    this.refreshFreeWindowChrome();
    this.refreshSessionOrientation();
    this.refreshDirectorySnapshot(true);
    this.scheduleFirstLaunchTutorial();
    this.syncRemoteSessionSharing();
    this.startPolling();
    if (this.showPreviewModal && this.activeSessionId.length > 0) {
      this.syncSurfaceBinding();
      this.applyRemoteAudioPollingForKind(this.activeSessionKind);
      const activeTab = this.remoteSessionTabsController.get(this.activeSessionId);
      if (activeTab !== undefined && activeTab.audioPreferenceCaptured) {
        this.nativeSessionBridge.setRemoteAudioMuted(activeTab.sessionId, activeTab.audioMuted);
        this.refreshRemoteAudioState();
      }
    }
  }

  onPageHide(): void {
    this.pageVisible = false;
    this.detachRuntimeObserver();
    this.discardAllRdpCertificateSecrets();
    this.discardDirectCredentialSecrets();
    this.directCredentialsVisible = false;
    this.hideSystemIme(false);
    this.disableRemoteSessionSharing(true);
    this.stopPeerOnlinePolling();
    this.clearRdpFollowResize();
    this.clipboardController?.stop();
    this.stopInputInterceptor();
    this.stopPolling();
    for (const tab of this.remoteSessionTabsController.snapshot()) {
      if (tab.sessionId === this.activeSessionId) {
        tab.audioMuted = this.remoteAudioState.muted;
        tab.audioPreferenceCaptured = this.remoteAudioState.available;
      }
      this.setSessionVideoPaused(tab.sessionId, true);
      this.nativeSessionBridge.setRemoteAudioMuted(tab.sessionId, true);
      tab.paused = true;
    }
    this.syncRemoteSessionTabs();
  }

  private registerRemoteSessionHandoffListener(): void {
    if (this.remoteSessionHandoffListenerRegistered) {
      return;
    }
    const context = this.abilityContext();
    context.eventHub.on(REMOTE_SESSION_HANDOFF_EVENT, this.onRemoteSessionHandoff);
    context.eventHub.on(REMOTE_SESSION_APP_STATE_EVENT, this.onRemoteSessionAppState);
    context.eventHub.on(REMOTE_SESSION_CONTINUE_HANDOFF_EVENT, this.onRemoteSessionContinueHandoff);
    this.remoteSessionHandoffListenerRegistered = true;
    this.onRemoteSessionHandoff();
  }

  private unregisterRemoteSessionHandoffListener(): void {
    if (!this.remoteSessionHandoffListenerRegistered) {
      return;
    }
    const context = this.abilityContext();
    context.eventHub.off(REMOTE_SESSION_HANDOFF_EVENT, this.onRemoteSessionHandoff);
    context.eventHub.off(REMOTE_SESSION_APP_STATE_EVENT, this.onRemoteSessionAppState);
    context.eventHub.off(REMOTE_SESSION_CONTINUE_HANDOFF_EVENT, this.onRemoteSessionContinueHandoff);
    this.remoteSessionHandoffListenerRegistered = false;
  }

  private registerEasyTierResultListener(): void {
    if (this.easyTierResultListenerRegistered) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.on(EASYTIER_API_RESULT_EVENT, this.onEasyTierApiResult);
    context.eventHub.on(EASYTIER_SNAPSHOT_EVENT, this.onEasyTierSnapshot);
    this.easyTierResultListenerRegistered = true;
    const buffered = EasyTierApiService.takeBufferedResult();
    if (buffered !== undefined) {
      void this.applyEasyTierApiResult(buffered);
    }
    const bufferedSnapshot = EasyTierApiService.takeBufferedSnapshot();
    if (bufferedSnapshot !== undefined) {
      this.applyEasyTierSnapshot(bufferedSnapshot);
    }
    void this.refreshEasyTierSnapshot(false);
  }

  private unregisterEasyTierResultListener(): void {
    if (!this.easyTierResultListenerRegistered) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.off(EASYTIER_API_RESULT_EVENT, this.onEasyTierApiResult);
    context.eventHub.off(EASYTIER_SNAPSHOT_EVENT, this.onEasyTierSnapshot);
    this.easyTierResultListenerRegistered = false;
  }

  private getInputController(): RustDeskInputController {
    if (!this.inputController) {
      this.inputController = new RustDeskInputController({
        isSessionActive: () => this.isInteractiveSessionActive(),
        usesCoreRawKeyRoute: () => this.isRemoteControlSessionActive(),
        isMouseMode: () => this.inputEnabled && !this.touchMode,
        isPeerMacOS: () => this.isPeerMacOS(),
        isPeerAndroid: () => this.isPeerAndroid(),
        isPeerMobile: () => this.isPeerMobile(),
        isLocalPhone: () => deviceInfo.deviceType === 'phone',
        gesturesEnabled: () => this.activeSessionDefaults.gesturesEnabled,
        rightClickGesture: () => this.rightClickGesture,
        getCoordinateSpace: () => this.getCoordinateSpace(),
        sendMouse: (payload: RustDeskMousePayload) => this.sendMousePayload(payload),
        sendFlutterKey: (payload: RustDeskFlutterKeyPayload) => this.sendFlutterKeyPayloadObject(payload),
        sendKey: (payload: RustDeskKeyPayload) => this.sendKeyPayloadObject(payload),
        log: (label: string, payload: string) => this.logRelativeDebug(label, payload),
        remoteCursorDebugText: () => this.remoteCursorDebugText(),
        overlayCursorDebugText: (label: string) => this.overlayCursorDebugText(label),
        onVirtualCursorMoved: (remoteX: number, remoteY: number) => this.updateOverlayFromVirtualCursor(remoteX, remoteY),
        onCanvasTransform: (
          scaleFactor: number,
          panX: number,
          panY: number,
          focalX: number,
          focalY: number,
        ) => this.applyPreviewTouchTransform(scaleFactor, panX, panY, focalX, focalY),
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

  private isPeerMobile(): boolean {
    const normalized = this.peerPlatform.toLowerCase().replace(/[\s_-]/g, '');
    return normalized === 'android'
      || normalized === 'ios'
      || normalized === 'iphone'
      || normalized === 'ipad'
      || normalized === 'harmonyos'
      || normalized === 'ohos';
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

  private relativeMouseModeSupported(): boolean {
    if (!this.isRemoteControlSessionActive()) {
      return false;
    }
    const platform = this.peerPlatform.toLowerCase().replace(/[\s_-]/g, '');
    return platform !== 'linux' && this.isPeerVersionAtLeast(1, 4, 5);
  }

  private androidNavigationAvailable(): boolean {
    return this.isRemoteControlSessionActive()
      && this.isPeerAndroid()
      && this.isPeerVersionAtLeast(1, 2, 7)
      && this.remoteKeyboardPermissionAllowed;
  }

  private androidNavigationOverlayWidth(): number {
    return this.androidNavigationVisible
      ? ANDROID_NAVIGATION_BAR_WIDTH
      : ANDROID_NAVIGATION_COLLAPSED_WIDTH;
  }

  private androidNavigationOverlayHeight(): number {
    return this.androidNavigationVisible
      ? ANDROID_NAVIGATION_BAR_HEIGHT
      : ANDROID_NAVIGATION_COLLAPSED_HEIGHT;
  }

  private clampAndroidNavigationX(value: number, viewportWidth: number = this.previewViewWidth): number {
    const maxX = Math.max(
      ANDROID_NAVIGATION_EDGE_MARGIN,
      viewportWidth - this.androidNavigationOverlayWidth() - ANDROID_NAVIGATION_EDGE_MARGIN,
    );
    return Math.min(Math.max(value, ANDROID_NAVIGATION_EDGE_MARGIN), maxX);
  }

  private clampAndroidNavigationY(value: number, viewportHeight: number = this.previewViewHeight): number {
    const maxY = Math.max(
      ANDROID_NAVIGATION_EDGE_MARGIN,
      viewportHeight - this.androidNavigationOverlayHeight() - ANDROID_NAVIGATION_EDGE_MARGIN,
    );
    return Math.min(Math.max(value, ANDROID_NAVIGATION_EDGE_MARGIN), maxY);
  }

  private updateAndroidNavigationViewport(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    if (!this.androidNavigationPositionInitialized) {
      const initialX = this.androidNavigationVisible
        ? (width - ANDROID_NAVIGATION_BAR_WIDTH) / 2
        : width - ANDROID_NAVIGATION_COLLAPSED_WIDTH - ANDROID_NAVIGATION_EDGE_MARGIN;
      this.androidNavigationX = this.clampAndroidNavigationX(initialX, width);
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
    if (this.androidNavigationVisible) {
      this.androidNavigationExpandedX = this.androidNavigationX;
      this.androidNavigationExpandedY = this.androidNavigationY;
    } else {
      this.androidNavigationCollapsedX = this.androidNavigationX;
      this.androidNavigationCollapsedY = this.androidNavigationY;
    }
    this.preferences?.saveAndroidNavigationPosition(
      this.androidNavigationX,
      this.androidNavigationY,
    );
  }

  private setAndroidNavigationExpanded(expanded: boolean): void {
    if (this.androidNavigationVisible === expanded) {
      return;
    }
    if (this.androidNavigationVisible) {
      this.androidNavigationExpandedX = this.androidNavigationX;
      this.androidNavigationExpandedY = this.androidNavigationY;
    } else {
      this.androidNavigationCollapsedX = this.androidNavigationX;
      this.androidNavigationCollapsedY = this.androidNavigationY;
    }
    this.androidNavigationVisible = expanded;
    if (this.previewViewWidth > 0 && this.previewViewHeight > 0) {
      if (expanded) {
        const expandedX = this.androidNavigationExpandedX >= 0
          ? this.androidNavigationExpandedX
          : (this.previewViewWidth - ANDROID_NAVIGATION_BAR_WIDTH) / 2;
        const expandedY = this.androidNavigationExpandedY >= 0
          ? this.androidNavigationExpandedY
          : this.previewViewHeight - ANDROID_NAVIGATION_BAR_HEIGHT - ANDROID_NAVIGATION_BOTTOM_OFFSET;
        this.androidNavigationX = this.clampAndroidNavigationX(expandedX);
        this.androidNavigationY = this.clampAndroidNavigationY(expandedY);
      } else {
        const collapsedX = this.androidNavigationCollapsedX >= 0
          ? this.androidNavigationCollapsedX
          : this.previewViewWidth - ANDROID_NAVIGATION_COLLAPSED_WIDTH - ANDROID_NAVIGATION_EDGE_MARGIN;
        const collapsedY = this.androidNavigationCollapsedY >= 0
          ? this.androidNavigationCollapsedY
          : this.previewViewHeight - ANDROID_NAVIGATION_COLLAPSED_HEIGHT - ANDROID_NAVIGATION_BOTTOM_OFFSET;
        this.androidNavigationX = this.clampAndroidNavigationX(collapsedX);
        this.androidNavigationY = this.clampAndroidNavigationY(collapsedY);
      }
      this.androidNavigationPositionInitialized = true;
      this.saveAndroidNavigationPosition();
    }
    this.preferences?.saveAndroidNavigationVisible(expanded);
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

  private async initializeRuntime(): Promise<void> {
    if (this.pagePreferencesInitialized) {
      if (this.pageVisible) {
        this.bindRuntimeObserver();
      }
      return;
    }
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.preferences = new RustDeskPreferences(hostContext);
      if (this.preferences.shouldShowBeginnerGuide()) {
        this.firstLaunchTutorialPending = true;
        this.scheduleFirstLaunchTutorial();
      }
      this.clipboardController = new RustDeskClipboardController(
        new RustDeskSystemClipboardHost(hostContext, (label: string, payload: string) =>
          this.logRelativeDebug(label, payload)),
        {
          sendText: (sessionId: string, content: string) =>
            sessionId === this.activeSessionId && this.sendClipboardText(content),
          sendImage: (sessionId: string, content: Uint8Array) =>
            sessionId === this.activeSessionId && this.sendClipboardImage(content),
          sendFiles: (sessionId: string, paths: Array<string>) =>
            sessionId === this.activeSessionId && this.sendClipboardFiles(paths),
          supportsRichClipboard: (sessionId: string): boolean =>
            sessionId === this.activeSessionId && carriesRichClipboard(this.activeSessionKind),
          log: (label: string, payload: string) => this.logRelativeDebug(label, payload),
        },
      );
      this.applySavedSettings(this.preferences.load());
      const easyTierSettings = this.preferences.loadEasyTier();
      this.easyTierPreconnectEnabled = easyTierSettings.enabled;
      this.easyTierSelectedInstanceId = easyTierSettings.instanceId;
      this.easyTierSelectedInstanceName = easyTierSettings.instanceName;
      this.easyTierSelectedInstanceState = '';
      this.easyTierStatusText = easyTierSettings.instanceId.length > 0
        ? '已保存实例；可刷新状态或直接连接' : '';
      this.sessionDefaults = this.preferences.loadSessionDefaults();
      this.refreshRefreshRateChoices();
      const androidNavigationState = this.preferences.loadAndroidNavigationState();
      this.androidNavigationVisible = androidNavigationState.visible;
      this.androidNavigationPositionInitialized = androidNavigationState.positionInitialized;
      this.androidNavigationX = androidNavigationState.x;
      this.androidNavigationY = androidNavigationState.y;
      if (this.androidNavigationVisible) {
        this.androidNavigationExpandedX = androidNavigationState.x;
        this.androidNavigationExpandedY = androidNavigationState.y;
      } else {
        this.androidNavigationCollapsedX = androidNavigationState.x;
        this.androidNavigationCollapsedY = androidNavigationState.y;
      }
      this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
      this.clipboardSyncEnabled = this.sessionDefaults.clipboardEnabled;
      this.touchMode = this.sessionDefaults.touchMode;
      this.relativeMouseMode = !this.touchMode && this.sessionDefaults.relativeMouseMode;
      this.inputEnabled = this.sessionDefaults.inputEnabled;
      this.rightClickGesture = this.sessionDefaults.rightClickGesture;
      this.selectedRefreshRate = this.defaultRefreshRate(this.sessionDefaults);
      // Preserve the user's request, not an invented decoder recommendation.
      this.preferredCodec = this.sessionDefaults.preferredCodec;
      this.isMiniBarExpanded = this.sessionDefaults.toolbarExpanded;

      this.pagePreferencesInitialized = true;
      if (this.pageVisible) {
        this.bindRuntimeObserver();
      }
      this.refreshDirectorySnapshot();
      // EntryAbility alone calls appInit. Its ready bit is not evidence for
      // the absent host/transfer APIs or a decoder recommendation. No generic
      // onRuntimeReady callback or synthetic 'Runtime initialized' message.
    } catch (error) {
      this.errorText = `Runtime init failed: ${String(error)}`;
      hilog.error(DOMAIN, TAG, 'initializeRuntime failed: %{public}s', this.errorText);
    }
  }

  private bindRuntimeObserver(): void {
    if (this.runtimeObserverBound || !this.pageVisible) {
      return;
    }
    this.runtimeObserverBound = true;
    rustDeskRuntimeController.bind(this.onRuntimeStateChanged);
  }

  private detachRuntimeObserver(): void {
    this.lanScanGeneration += 1;
    this.clearLanScanPollTimer();
    this.lanScanActive = false;
    this.runtimeInitialized = false;
    this.runtimeOwnerGeneration = '';
    if (!this.runtimeObserverBound) {
      return;
    }
    this.runtimeObserverBound = false;
    void rustDeskRuntimeController.unbind(this.onRuntimeStateChanged).catch((error: Error): void => {
      // Retain native ownership on failure; a hidden page cannot declare stop
      // or session/Surface release. A later Ability fence remains authoritative.
      hilog.warn(DOMAIN, TAG, 'LAN page-exit cleanup failed: %{public}s', String(error));
    });
  }

  private runtimeLanCanScan(state: RustDeskRuntimeState): boolean {
    return this.pageVisible && this.runtimeObserverBound && !state.pending &&
      state.ready && state.discoveryAllowed && !state.lanPending &&
      state.scanId !== undefined && !this.lanScanActive;
  }

  private applyRuntimeState(state: RustDeskRuntimeState): void {
    if (!this.pageVisible || !this.runtimeObserverBound) {
      return;
    }
    const ownerChanged = state.ownerGeneration !== this.runtimeOwnerGeneration;
    if (ownerChanged || state.pending) {
      this.lanScanGeneration += 1;
      this.clearLanScanPollTimer();
    }
    this.runtimeOwnerGeneration = state.ownerGeneration;
    this.runtimeInitialized = !state.pending && state.ready && state.discoveryAllowed;
    this.appForeground = state.foreground;
    const reply = state.lan;
    this.lanScanActive = state.lanPending || (reply !== undefined && reply.ok &&
      (reply.state === 'scanning' || reply.state === 'stopping' || reply.state === 'removing'));
    if (!this.lanScanActive || !this.runtimeInitialized) {
      this.clearLanScanPollTimer();
    }
    let message = state.error;
    if (message.length === 0 && state.pending) {
      message = '正在同步隐私与前台状态';
    } else if (message.length === 0 && !state.privacyAccepted) {
      message = '尚未取得系统隐私同意';
    } else if (message.length === 0 && !state.foreground) {
      message = '应用不在前台';
    } else if (message.length === 0 && !state.ready) {
      message = '内核私有存储尚未就绪';
    } else if (message.length === 0 && state.lanPending) {
      message = '正在等待局域网操作回执';
    } else if (message.length === 0 && this.lanScanActive) {
      message = '正在扫描局域网设备';
    } else if (message.length === 0 && reply !== undefined && reply.ok && reply.terminal !== undefined) {
      message = `局域网扫描已结束（${reply.terminal}）`;
    }
    const snapshot = this.directoryScanSnapshot(this.lanScanActive, message);
    snapshot.lan = this.mainBridge.listLanPeers();
    this.mergeSavedLanMetadata(snapshot.lan);
    preservePeerOnlineStates(snapshot.lan, [this.directorySnapshot.lan, snapshot.saved]);
    snapshot.favorite = buildFavoritePeers(snapshot.saved, snapshot.lan);
    snapshot.lanCanScan = this.runtimeLanCanScan(state);
    this.directorySnapshot = snapshot;
    if (!this.runtimeInitialized) {
      this.stopPeerOnlinePolling();
    }
    if (ownerChanged && this.runtimeInitialized) {
      // A query consumes an existing owner. It must never mint/adopt one.
      void this.pollLanScanSnapshot(this.lanScanGeneration);
      void this.refreshNativeState();
    }
    if (this.runtimeInitialized) {
      void this.migrateEngineDirectory();
    }
  }

  /**
   * One-time migration of the engine's own directory into the saved list.
   *
   * The local store stays the owner, so this runs only while it has never been
   * written, needs both engine reads to really succeed, and writes nothing on a
   * read failure: a partial write would close the migration for good.
   */
  private async migrateEngineDirectory(): Promise<void> {
    const preferences = this.preferences;
    const owner = this.runtimeOwnerGeneration;
    if (!this.runtimeInitialized || owner.length === 0 || preferences === undefined) {
      return;
    }
    if (this.directoryMigrationInFlight || this.directoryMigrationOwner === owner) {
      return;
    }
    if (preferences.hasSavedPeers()) {
      this.directoryMigrationOwner = owner;
      return;
    }
    this.directoryMigrationInFlight = true;
    try {
      const favorites = await this.mainBridge.listFavorites();
      const recent = await this.mainBridge.listRecentPeers(favorites.ok ? favorites.favorites : []);
      if (!this.runtimeInitialized || this.runtimeOwnerGeneration !== owner || !this.pageVisible) {
        return;
      }
      if (!favorites.ok || !recent.ok) {
        const detail = (recent.ok ? favorites.error : recent.error).trim();
        this.mainBridge.recordDirectoryMessage('设备迁移',
          detail.length > 0 ? detail : '读取引擎目录失败');
        this.refreshDirectorySnapshot();
        return;
      }
      const legacy = recent.peers;
      for (const id of favorites.favorites) {
        if (!legacy.some((peer: PeerRecord): boolean => peer.id === id)) {
          const peer = new PeerRecord();
          peer.id = id;
          peer.favorite = true;
          legacy.push(peer);
        }
      }
      if (legacy.length === 0) {
        // Both reads succeeded and the engine had no rows: nothing to migrate, so
        // the store keeps its absent state instead of being written empty.
        this.directoryMigrationOwner = owner;
        this.refreshDirectorySnapshot();
        return;
      }
      this.savedDevices = preferences.loadSavedPeers(legacy);
      this.directoryMigrationOwner = owner;
      this.refreshDirectorySnapshot();
    } catch (error) {
      if (this.runtimeOwnerGeneration !== owner) {
        return;
      }
      this.mainBridge.recordDirectoryMessage('设备迁移', String(error));
      this.refreshDirectorySnapshot();
    } finally {
      this.directoryMigrationInFlight = false;
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

  private markFirstLaunchTutorialShown(): void {
    if (!this.firstLaunchTutorialPending) {
      return;
    }
    this.firstLaunchTutorialPending = false;
    this.firstLaunchTutorialRequest = 0;
    this.preferences?.markBeginnerGuideShown();
  }

  private scheduleFirstLaunchTutorial(): void {
    if (!this.firstLaunchTutorialPending || this.firstLaunchTutorialSchedulePending
      || !this.pageVisible || !this.appForeground) {
      return;
    }
    this.firstLaunchTutorialSchedulePending = true;
    setTimeout((): void => {
      this.firstLaunchTutorialSchedulePending = false;
      if (!this.firstLaunchTutorialPending || !this.pageVisible || !this.appForeground) {
        return;
      }
      this.openMainTab(2);
      setTimeout((): void => {
        if (this.firstLaunchTutorialPending && this.pageVisible && this.appForeground) {
          this.firstLaunchTutorialRequest += 1;
        }
      }, 420);
    }, 400);
  }

  /**
   * Reads the rates this panel can actually show.
   *
   * `supportedRefreshRates` is API 20+, so a device that predates it falls back
   * to whatever rate the panel is running at plus the low-bandwidth option. The
   * list is a property of the device rather than a constant, which is why the
   * panel offers exactly these numbers and nothing else.
   */
  private refreshRefreshRateChoices(): void {
    let supported: number[] | undefined = undefined;
    let current = DEFAULT_REFRESH_RATE;
    try {
      const displayInfo = display.getDefaultDisplaySync();
      current = Number(displayInfo.refreshRate);
      const rates = displayInfo.supportedRefreshRates;
      if (rates !== undefined && rates !== null) {
        supported = [];
        for (let index = 0; index < rates.length; index += 1) {
          supported.push(Number(rates[index]));
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'display refresh query failed: %{public}s', String(error));
    }
    const choices = resolveRefreshRateChoices(supported, current);
    this.refreshRateChoices = choices;
    if (!choices.includes(this.selectedRefreshRate)) {
      this.selectedRefreshRate = defaultRefreshRateFor(choices, current);
    }
  }

  private applySavedSettings(settings: SavedConnectionSettings): void {
    this.peerTarget = bareTargetAddress(settings.target);
    this.connectPageMode = settings.mode;
    this.rememberPassword = settings.rememberPassword;
  }

  private copySessionDefaults(source: SessionDefaults): SessionDefaults {
    return copySessionDefaults(source);
  }

  private copyServerConfig(source: ServerConfig): ServerConfig {
    const config = new ServerConfig();
    config.mode = source.mode;
    config.idServer = source.idServer;
    config.relayServer = source.relayServer;
    config.apiServer = source.apiServer;
    config.key = source.key;
    config.effectiveApiServer = source.effectiveApiServer;
    config.usingPublicServer = source.usingPublicServer;
    config.remoteReachable = source.remoteReachable;
    config.accountAvailable = source.accountAvailable;
    config.message = source.message;
    return config;
  }

  /**
   * The route a new ID connection may use: the explicitly saved profile, never the
   * draft the settings card is still editing. A saved official profile keeps the
   * `public` dial spelling this client already uses for the pinned public route.
   */
  private savedRouteConfig(approved: ApprovedServerProfile | undefined): ServerConfig {
    const config = new ServerConfig();
    if (approved === undefined) {
      config.message = '服务器配置尚未明确保存';
      return config;
    }
    config.mode = approved.mode;
    config.idServer = approved.mode === 'official' ? '' : approved.idServer;
    config.relayServer = approved.relayServer;
    config.key = approved.key;
    config.usingPublicServer = approved.mode === 'official';
    return config;
  }

  private serverConfigFromHandoff(envelope: RemoteSessionHandoffEnvelope): ServerConfig {
    const config = new ServerConfig();
    if (envelope.targetKind === 'ip') {
      return config;
    }
    config.idServer = envelope.idServer;
    config.relayServer = envelope.relayServer;
    config.apiServer = envelope.apiServer;
    config.key = envelope.key;
    return config;
  }

  private createRemoteSessionShareSnapshot(): RemoteSessionShareSnapshot | undefined {
    if (this.activeSessionShareTarget.length === 0 || this.activeSessionId.length === 0) {
      return undefined;
    }
    const snapshot = new RemoteSessionShareSnapshot();
    snapshot.target = this.activeSessionShareTarget;
    snapshot.targetKind = this.activeSessionShareTargetKind;
    let connToken = '';
    try {
      connToken = this.nativeSessionBridge.getConnToken(this.activeSessionId) ?? '';
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'session connection token unavailable: %{public}s', String(error));
    }
    snapshot.connToken = connToken;
    if (connToken.length === 0) {
      return undefined;
    }
    if (snapshot.targetKind === 'target') {
      snapshot.idServer = this.activeSessionServerConfig.idServer;
      snapshot.relayServer = this.activeSessionServerConfig.relayServer;
      snapshot.apiServer = this.activeSessionServerConfig.apiServer;
      snapshot.key = this.activeSessionServerConfig.key;
      snapshot.forceRelay = this.activeSessionForceRelay;
    }
    snapshot.connectionMode = 'remote_control';
    return snapshot;
  }

  private syncRemoteSessionSharing(): void {
    const snapshot = this.createRemoteSessionShareSnapshot();
    const continuationEligible = this.sessionDefaults.sessionSharingEnabled
      && this.activeSessionId.length > 0
      && this.sessionPhase === 'connected'
      && snapshot !== undefined;
    RemoteSessionHandoffService.setOutgoingSnapshot(continuationEligible ? snapshot : undefined);
    if (continuationEligible !== this.remoteSessionContinuationActive) {
      this.remoteSessionContinuationActive = continuationEligible;
      this.abilityContext().eventHub.emit(REMOTE_SESSION_CONTINUE_STATE_EVENT, continuationEligible);
    }
    const shareEligible = this.pageVisible
      && this.appForeground
      && this.showPreviewModal
      && continuationEligible;
    if (shareEligible === this.remoteSessionSharingActive) {
      return;
    }
    if (!shareEligible || snapshot === undefined) {
      this.disableRemoteSessionSharing(true);
      return;
    }
    this.remoteSessionSharingActive = true;
    this.remoteSessionShareController.setEnabled(this.abilityContext(), snapshot);
  }

  private disableRemoteSessionSharing(keepContinuation: boolean = false): void {
    this.remoteSessionSharingActive = false;
    this.remoteSessionShareController.disable();
    if (!keepContinuation) {
      RemoteSessionHandoffService.setOutgoingSnapshot(undefined);
      if (this.remoteSessionContinuationActive) {
        this.remoteSessionContinuationActive = false;
        this.abilityContext().eventHub.emit(REMOTE_SESSION_CONTINUE_STATE_EVENT, false);
      }
    }
  }

  private clearActiveSessionHandoffState(preserveRdpCertificateDecision: boolean = false): void {
    this.disableRemoteSessionSharing();
    this.activeSessionPassword = '';
    // A credential answered for a wire that is being closed is not this client's
    // to keep: the next dial asks again rather than spending a secret on a
    // session the operator has already left.
    this.discardDirectCredentialSecrets();
    if (!preserveRdpCertificateDecision) {
      this.forgetRdpCertificateCredentials(this.activeSessionId);
      this.rdpDialCredentials?.wipePassword();
      this.rdpDialCredentials = undefined;
      if (this.rdpCertificateSessionId === this.activeSessionId) {
        this.discardRdpCertificateDecision();
      }
    }
    // The cause reported for this session goes with it: the text was already used
    // as the close reason, and a later session must not inherit it.
    this.clearDirectWireFailure();
    this.activeSessionShareTarget = '';
    this.activeSessionShareTargetKind = 'target';
    this.activeSessionRustdeskIdOnly = false;
    this.activeSessionServerConfig = new ServerConfig();
    this.activeSessionApprovedProfile = undefined;
    this.activeSessionPasswordEphemeral = false;
    this.handoffPasswordAutoSubmitAttempted = false;
    this.activeSessionForceRelay = false;
  }

  private handoffTargetKind(target: string): string {
    const normalized = target.trim();
    if (normalized.includes('@')) {
      return 'target';
    }
    if (normalized.includes(':') || /^\d{1,3}(\.\d{1,3}){3}$/.test(normalized)) {
      return 'ip';
    }
    return 'target';
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

  /**
   * The rate a session starts from. It is remembered per device but re-derived
   * from the panel on every start, so a default saved on a 60 Hz device stays
   * meaningful when the same session is reopened from a 120 Hz one.
   */
  private defaultRefreshRate(defaults: SessionDefaults): number {
    if (!isValidRefreshRate(defaults.refreshRate)) {
      return defaultRefreshRateFor(this.refreshRateChoices, this.selectedRefreshRate);
    }
    return Math.round(defaults.refreshRate);
  }

  private applySessionDefaultsToIdleState(capabilities: DecoderCapability[]): void {
    this.touchMode = this.sessionDefaults.touchMode;
    this.relativeMouseMode = !this.touchMode && this.sessionDefaults.relativeMouseMode;
    this.inputEnabled = this.sessionDefaults.inputEnabled;
    this.rightClickGesture = this.sessionDefaults.rightClickGesture;
    this.clipboardSyncEnabled = this.sessionDefaults.clipboardEnabled;
    this.selectedRefreshRate = this.defaultRefreshRate(this.sessionDefaults);
    this.preferredCodec = this.resolvePreferredCodec(this.sessionDefaults.preferredCodec, capabilities);
    this.isMiniBarExpanded = this.sessionDefaults.toolbarExpanded;
  }

  private saveSessionDefaults(defaults: SessionDefaults): void {
    const nextDefaults = this.copySessionDefaults(defaults);
    this.sessionDefaults = nextDefaults;
    this.preferences?.saveSessionDefaults(nextDefaults);
    this.syncRemoteSessionSharing();
    if (!this.activeSessionId) {
      this.activeSessionDefaults = this.copySessionDefaults(nextDefaults);
      this.applySessionDefaultsToIdleState(this.decoderCapabilities);
    }
  }

  private testServerConfiguration(config: ServerConfig): void {
    if (this.serverValidating || this.serverSaving) {
      return;
    }
    this.clearServerTestTimer();
    const generation = ++this.serverTestGeneration;
    this.serverValidating = true;
    this.serverTestTimer = setTimeout(() => {
      this.serverTestTimer = -1;
      if (generation !== this.serverTestGeneration) {
        return;
      }
      this.performServerConfigurationTest(config, generation);
    }, 0) as number;
  }

  private async performServerConfigurationTest(config: ServerConfig, generation: number): Promise<void> {
    try {
      const result = await this.mainBridge.testServerConfig(config);
      if (generation === this.serverTestGeneration) {
        this.serverConfig = result;
      }
    } catch (error) {
      if (generation === this.serverTestGeneration) {
        config.remoteReachable = false;
        config.resultState = 'error';
        config.message = String(error);
        this.serverConfig = config;
      }
    } finally {
      if (generation === this.serverTestGeneration) {
        this.serverValidating = false;
      }
    }
  }

  private updateServerConfigDraft(config: ServerConfig): void {
    this.serverTestGeneration += 1;
    this.clearServerTestTimer();
    this.serverValidating = false;
    this.serverConfig = config;
  }

  private clearServerTestTimer(): void {
    if (this.serverTestTimer < 0) {
      return;
    }
    clearTimeout(this.serverTestTimer);
    this.serverTestTimer = -1;
  }

  private saveServerConfiguration(config: ServerConfig): void {
    const generation = ++this.serverTestGeneration;
    this.clearServerTestTimer();
    this.serverValidating = false;
    this.serverSaving = true;
    void this.completeServerConfigurationSave(config, generation);
  }

  /**
   * Adopts a save receipt only while this attempt is still the page's current
   * server action: editing the draft or starting another test/save bumps the
   * generation, so a late receipt cannot replace the newer draft or approval.
   */
  private async completeServerConfigurationSave(config: ServerConfig,
    generation: number): Promise<void> {
    try {
      const reply = await this.mainBridge.saveServerConfig(config);
      if (generation !== this.serverTestGeneration) {
        return;
      }
      if (!reply.ok || !reply.approved || !reply.committed) {
        // The engine did not persist this draft: the approval in force stays
        // untouched and only this draft carries the real refusal.
        const failed = this.copyDraftServerConfig(config);
        failed.resultState = 'error';
        failed.message = reply.error.length > 0 ? reply.error : '保存未被引擎确认';
        this.serverConfig = failed;
        return;
      }
      this.serverProfile = reply.toProfileState();
      const saved = this.copyServerConfig(reply.config);
      saved.resultState = 'saved';
      saved.message = reply.message;
      this.serverConfig = saved;
      this.apiServer = saved.effectiveApiServer;
      this.refreshDirectorySnapshot();
    } catch (error) {
      if (generation !== this.serverTestGeneration) {
        return;
      }
      const failed = this.copyDraftServerConfig(config);
      failed.resultState = 'error';
      failed.message = String(error);
      this.serverConfig = failed;
    } finally {
      if (generation === this.serverTestGeneration) {
        this.serverSaving = false;
      }
    }
  }

  /** The draft a save or test was asked to persist; nothing here is an approval. */
  private copyDraftServerConfig(source: ServerConfig): ServerConfig {
    const config = new ServerConfig();
    config.mode = source.mode;
    config.idServer = source.idServer;
    config.relayServer = source.relayServer;
    config.key = source.key;
    return config;
  }

  private applyServerProfileReply(reply: ServerProfileReply): void {
    // A read failure cannot revoke the last confirmed explicit save.
    if (reply.ok) {
      this.serverProfile = reply.toProfileState();
    }
  }

  /** The card's values for a read receipt: an unsaved store stays visibly unsaved. */
  private serverConfigFromReply(reply: ServerProfileReply): ServerConfig {
    if (!reply.ok) {
      const failed = this.copyServerConfig(this.serverConfig);
      failed.resultState = 'error';
      failed.message = reply.error;
      return failed;
    }
    const config = this.copyServerConfig(reply.config);
    config.message = reply.message;
    return config;
  }

  private refreshDirectorySnapshot(forceProbe: boolean = false): void {
    this.stopPeerOnlinePolling();
    const snapshot = new DirectorySnapshot();
    snapshot.revision = ++this.directoryRevision;
    this.mainBridge.resetDirectoryMessage();
    if (this.savedDevices === undefined && this.preferences !== undefined) {
      try {
        // The local store owns the list. The engine directory is only a migration
        // source, read once per owner by migrateEngineDirectory.
        this.savedDevices = this.preferences.loadSavedPeers(undefined);
      } catch (error) {
        snapshot.message = String(error);
      }
    }
    snapshot.saved = this.savedDevices?.slice() ?? [];
    snapshot.recent = snapshot.saved.slice().sort((left: PeerRecord, right: PeerRecord): number =>
      right.lastSuccessAt - left.lastSuccessAt);
    snapshot.lan = this.mainBridge.listLanPeers();
    this.mergeSavedLanMetadata(snapshot.lan);
    preservePeerOnlineStates(snapshot.lan, [this.directorySnapshot.lan, snapshot.saved]);
    snapshot.favorite = buildFavoritePeers(snapshot.saved, snapshot.lan);
    snapshot.lanScanning = this.lanScanActive;
    snapshot.lanCanScan = this.runtimeLanCanScan(rustDeskRuntimeController.state());
    snapshot.message = snapshot.message.length > 0 ? snapshot.message : this.mainBridge.getDirectoryMessage();
    this.directorySnapshot = snapshot;
    this.schedulePeerOnlineProbe(forceProbe ? 0 : Math.max(0, 30000 - (Date.now() - this.lastPeerProbeStartedAt)));
  }

  private schedulePeerOnlineProbe(delayMs: number): void {
    if (!this.pageVisible || !this.appForeground) {
      return;
    }
    if (this.peerOnlinePollTimer >= 0) {
      clearTimeout(this.peerOnlinePollTimer);
    }
    const generation = this.peerOnlinePollGeneration;
    this.peerOnlinePollTimer = setTimeout(() => {
      this.peerOnlinePollTimer = -1;
      void this.performPeerOnlineProbe(generation);
    }, Math.max(0, delayMs)) as number;
  }

  private stopPeerOnlinePolling(): void {
    this.peerOnlinePollGeneration += 1;
    if (this.peerOnlinePollTimer >= 0) {
      clearTimeout(this.peerOnlinePollTimer);
      this.peerOnlinePollTimer = -1;
    }
    this.peerOnlinePollInFlight = false;
    this.deviceLivenessProbe.cancel();
  }

  private async performPeerOnlineProbe(generation: number): Promise<void> {
    if (generation !== this.peerOnlinePollGeneration || !this.pageVisible || !this.appForeground ||
      this.peerOnlinePollInFlight) {
      return;
    }
    this.peerOnlinePollInFlight = true;
    this.lastPeerProbeStartedAt = Date.now();
    const snapshot = this.directoryScanSnapshot(this.lanScanActive, this.directorySnapshot.message);
    const lists = [snapshot.saved, snapshot.recent, snapshot.favorite, snapshot.lan];
    for (const list of lists) {
      for (const peer of list) {
        peer.online = undefined;
        peer.directWireReachable = undefined;
      }
    }
    const peers = snapshot.saved.concat(snapshot.lan);
    const tcpResult = this.deviceLivenessProbe.probe(peers);
    const approval = this.serverProfile.captureApproved();
    const owner = this.runtimeOwnerGeneration;
    try {
      const ids = collectPeerOnlineIds(lists);
      if (approval === undefined) {
        // Without an explicitly saved profile hbbs is never asked, and no other
        // observation may stand in for its answer.
        if (ids.length > 0) {
          snapshot.message = '服务器配置尚未明确保存，未查询 RustDesk 在线状态';
        }
      } else {
        for (let offset = 0; offset < ids.length && generation === this.peerOnlinePollGeneration; offset += 64) {
          const result = await this.mainBridge.queryPeerOnlineStates(ids.slice(offset, offset + 64), approval);
          const currentApproval = this.serverProfile.captureApproved();
          if (generation !== this.peerOnlinePollGeneration || owner !== this.runtimeOwnerGeneration ||
            !this.pageVisible || !this.appForeground ||
            currentApproval === undefined || currentApproval.revision !== approval.revision) {
            return;
          }
          // Each native call has its own queryGeneration, not one token for all
          // batches. The captured page/profile generation fences this sweep.
          if (!result.ok || result.queryGeneration.length === 0) {
            if (result.message.length > 0) {
              snapshot.message = result.message;
            }
            continue;
          }
          applyPeerOnlineStates(lists, result.onlines, result.offlines);
        }
      }
      const observed = await tcpResult;
      const currentApproval = this.serverProfile.captureApproved();
      if (generation !== this.peerOnlinePollGeneration || owner !== this.runtimeOwnerGeneration ||
        !this.pageVisible || !this.appForeground || currentApproval?.revision !== approval?.revision) {
        return;
      }
      // A direct RDP/VNC socket answers only for that wire. It is never a RustDesk
      // online claim, and an id-only peer is not probed at all.
      for (const observation of observed) {
        if (observation.directWireReachable === undefined) {
          continue;
        }
        for (const list of lists) {
          for (const peer of list) {
            if (savedDeviceKey(peer) === savedDeviceKey(observation) &&
              peerProtocolOf(peer) !== 'rustdesk') {
              peer.directWireReachable = observation.directWireReachable;
            }
          }
        }
      }
      snapshot.favorite = buildFavoritePeers(snapshot.saved, snapshot.lan);
      this.directorySnapshot = snapshot;
    } finally {
      if (generation === this.peerOnlinePollGeneration) {
        this.peerOnlinePollInFlight = false;
        this.schedulePeerOnlineProbe(30000);
      }
    }
  }

  private directoryScanSnapshot(scanning: boolean, message: string): DirectorySnapshot {
    const snapshot = new DirectorySnapshot();
    snapshot.revision = ++this.directoryRevision;
    snapshot.saved = this.directorySnapshot.saved.slice();
    snapshot.lanCanScan = this.directorySnapshot.lanCanScan;
    snapshot.recent = this.directorySnapshot.recent.slice();
    snapshot.favorite = this.directorySnapshot.favorite.slice();
    snapshot.lan = this.directorySnapshot.lan.slice();
    snapshot.addressBook = this.directorySnapshot.addressBook.slice();
    snapshot.lanScanning = scanning;
    snapshot.message = message;
    return snapshot;
  }
  private mergeSavedLanMetadata(peers: PeerRecord[]): void {
    for (const peer of peers) {
      peer.protocol = 'rustdesk';
      peer.rustdeskIdOnly = true;
      const local = this.savedDevices?.find((record: PeerRecord): boolean => savedDeviceKey(record) === savedDeviceKey(peer));
      if (local !== undefined) {
        peer.alias = local.alias;
        peer.note = local.note;
        peer.favorite = local.favorite;
      }
    }
  }


  private clearLanScanPollTimer(): void {
    if (this.lanScanPollTimer >= 0) {
      clearTimeout(this.lanScanPollTimer);
      this.lanScanPollTimer = -1;
    }
  }

  private async pollLanScanSnapshot(scanGeneration: number): Promise<void> {
    if (!this.pageVisible || !this.runtimeInitialized || scanGeneration !== this.lanScanGeneration) {
      return;
    }
    try {
      await this.mainBridge.queryLanPeers();
      // The singleton observer applies only matching receipts. An undefined
      // result is retired/pending work, never a successful empty query.
    } catch (error) {
      if (this.pageVisible && scanGeneration === this.lanScanGeneration) {
        this.errorText = String(error);
      }
    }
    if (this.pageVisible && this.runtimeInitialized && this.lanScanActive &&
      scanGeneration === this.lanScanGeneration) {
      this.clearLanScanPollTimer();
      this.lanScanPollTimer = setTimeout(() => {
        this.lanScanPollTimer = -1;
        void this.pollLanScanSnapshot(scanGeneration);
      }, 350) as number;
    }
  }

  private async scanLanPeers(): Promise<void> {
    if (!this.runtimeLanCanScan(rustDeskRuntimeController.state())) {
      return;
    }
    const scanGeneration = ++this.lanScanGeneration;
    this.clearLanScanPollTimer();
    try {
      const admitted = await this.mainBridge.scanLan();
      if (!this.pageVisible || scanGeneration !== this.lanScanGeneration || admitted === undefined) {
        return;
      }
      if (admitted.ok && this.lanScanActive) {
        await this.pollLanScanSnapshot(scanGeneration);
      }
      // A start receipt is admission plus a snapshot, not scan completion.
      // Only subsequent native state/terminal receipts end the spinner.
    } catch (error) {
      if (this.pageVisible && scanGeneration === this.lanScanGeneration) {
        this.errorText = String(error);
      }
    }
  }

  private cancelLanScan(): void {
    const scanGeneration = ++this.lanScanGeneration;
    this.clearLanScanPollTimer();
    void this.mainBridge.stopLan().catch((error: Error): void => {
      if (this.pageVisible && scanGeneration === this.lanScanGeneration) {
        this.errorText = String(error);
      }
    });
    // Do not claim stopped before the exact native stop receipt settles.
  }

  private setPeerFavorite(peerId: string, protocol: PeerProtocol, favorite: boolean, idOnly: boolean): void {
    const peer = this.findDirectoryPeer(peerId, protocol, idOnly);
    const updated = copyPeerRecord(peer);
    updated.favorite = favorite;
    const error = this.saveLocalDevice(peer, updated);
    if (error !== '') {
      this.errorText = String(error);
      return;
    }
    this.mirrorDirectoryWrite(() => this.mainBridge.setFavorite(updated, favorite), '收藏设备');
  }

  private removeRecentPeer(peerId: string, protocol: PeerProtocol, idOnly: boolean): void {
    const peer = this.findDirectoryPeer(peerId, protocol, idOnly);
    const key = savedDeviceKey(peer);
    const next = (this.savedDevices ?? []).filter((row: PeerRecord): boolean => savedDeviceKey(row) !== key);
    if (!this.preferences?.saveSavedPeers(next)) {
      this.errorText = '无法删除本机设备记录';
      return;
    }
    this.savedDevices = next;
    this.refreshDirectorySnapshot();
    this.mirrorDirectoryWrite(() => this.mainBridge.removeRecentPeer(peer), '最近设备');
  }

  private async removeDiscoveredPeer(peerId: string): Promise<void> {
    const scanGeneration = ++this.lanScanGeneration;
    this.clearLanScanPollTimer();
    try {
      const receipt = await this.mainBridge.removeDiscoveredPeer(peerId);
      if (!this.pageVisible || scanGeneration !== this.lanScanGeneration || receipt === undefined) {
        return;
      }
      if (!receipt.ok) {
        this.errorText = receipt.error ?? '无法移除局域网设备';
      }
      // Rows come from the acknowledged native snapshot, not a local deletion
      // or a fabricated `removed`/durable-storage flag.
    } catch (error) {
      if (this.pageVisible && scanGeneration === this.lanScanGeneration) {
        this.errorText = String(error);
      }
    }
  }

  private setPeerNote(peerId: string, protocol: PeerProtocol, note: string, idOnly: boolean): void {
    const peer = this.findDirectoryPeer(peerId, protocol, idOnly);
    const updated = copyPeerRecord(peer);
    updated.note = note;
    const error = this.saveLocalDevice(peer, updated);
    if (error !== '') {
      this.errorText = String(error);
    }
  }

  /**
   * Mirrors one directory write into the engine while the same owner is current.
   *
   * The local saved list stays the owner of the row; an engine refusal is a real
   * failure reported to the operator, never dropped and never turned into success.
   */
  private mirrorDirectoryWrite(write: () => Promise<DirectoryWriteReply>, scope: string): void {
    const owner = this.runtimeOwnerGeneration;
    if (!this.runtimeInitialized || owner.length === 0) {
      return;
    }
    void write().then((reply: DirectoryWriteReply): void => {
      if (this.runtimeOwnerGeneration !== owner || reply.ok) {
        return;
      }
      this.mainBridge.recordDirectoryMessage(scope, reply.error);
      this.refreshDirectorySnapshot();
    }).catch((error: Error): void => {
      if (this.runtimeOwnerGeneration !== owner) {
        return;
      }
      this.mainBridge.recordDirectoryMessage(scope, String(error));
      this.refreshDirectorySnapshot();
    });
  }

  private findDirectoryPeer(target: string, protocol: PeerProtocol, idOnly: boolean): PeerRecord {
    const candidate = new PeerRecord();
    candidate.id = target;
    candidate.protocol = protocol;
    candidate.rustdeskIdOnly = idOnly;
    const normalized = migrateDeviceRecord(candidate);
    return this.directorySnapshot.saved.concat(this.directorySnapshot.lan)
      .find((peer: PeerRecord): boolean => savedDeviceKey(peer) === savedDeviceKey(normalized)) ?? normalized;
  }

  private saveLocalDevice(original: PeerRecord, value: PeerRecord): ResourceStr {
    const peer = migrateDeviceRecord(value);
    try {
      peer.rdpCertificateSha256 = peer.protocol === 'rdp'
        ? (this.preferences?.rdpCertificateSha256(peer.id) ?? '') : '';
    } catch (error) {
      return String(error);
    }
    const oldKey = savedDeviceKey(original);
    const next = (this.savedDevices ?? []).filter((row: PeerRecord): boolean =>
      savedDeviceKey(row) !== oldKey && savedDeviceKey(row) !== savedDeviceKey(peer));
    next.push(peer);
    if (!this.preferences?.saveSavedPeers(next)) {
      return '无法保存本机设备记录，请重试';
    }
    if (invalidatesRdpUsernameCache(original, peer, this.directWireUsernameTarget)) {
      this.directWireUsernameTarget = '';
    }
    this.savedDevices = next;
    this.refreshDirectorySnapshot();
    return '';
  }
  private rememberConnectedDevice(event: NativeEvent): void {
    const protocol: PeerProtocol = this.activeSessionKind === 'rdp' ? 'rdp' :
      (this.activeSessionKind === 'vnc' ? 'vnc' : 'rustdesk');
    const target = this.activeSessionShareTarget || this.peerTarget;
    const original = this.findDirectoryPeer(target, protocol, this.activeSessionRustdeskIdOnly);
    const peer = copyPeerRecord(original);
    peer.lastSuccessAt = Date.now();
    if (event.hostname !== undefined) {
      peer.hostname = event.hostname;
    }
    if (event.platform !== undefined) {
      peer.platform = event.platform;
    }
    if (protocol === 'rdp' && this.directWireUsernameTarget === target) {
      peer.rdpUsername = this.directCredentialsUsername;
    }
    const error = this.saveLocalDevice(original, peer);
    if (error !== '') {
      this.errorText = String(error);
      return;
    }
    // Only a session this client really observed reaches the engine directory.
    this.mirrorDirectoryWrite(() => this.mainBridge.recordRecentPeer(peer), '最近设备');
  }


  private changeConnectPageMode(index: number): void {
    this.updatePeerTarget(swapDefaultDirectPort(this.peerTarget, index));
    this.connectPageMode = index;
    this.preferences?.saveTarget(this.peerTarget, index);
  }

  private updatePeerTarget(value: string): void {
    if (value !== this.peerTarget) {
      this.passwordDraft = '';
      this.rememberPassword = false;
    }
    this.peerTarget = value;
  }

  private launchPeer(peerId: string, kind: PeerLaunchKind, rustdeskIdOnly: boolean = false): void {
    void this.preparePeerLaunch(peerId, kind, rustdeskIdOnly);
  }

  private abilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private setEasyTierPreconnectEnabled(enabled: boolean): void {
    this.easyTierPreconnectEnabled = enabled;
    this.preferences?.saveEasyTierEnabled(enabled);
    if (!enabled) {
      EasyTierApiService.cancelPending(this.abilityContext());
      this.easyTierRequestPending = false;
      this.easyTierStatusText = 'EasyTier 预组网已关闭';
      if (this.connectionUiPhase === 'waiting_for_easytier') {
        this.connectionUiPhase = 'idle';
        this.connectionUiMessage = '';
      }
      return;
    }
    this.easyTierStatusText = this.easyTierSelectedInstanceId.length > 0
      ? '已保存实例；正在同步运行状态' : '请先选择 EasyTier 实例';
  }

  private setEasyTierMode(instanceId: string): void {
    if (instanceId.length === 0) {
      this.setEasyTierPreconnectEnabled(false);
      return;
    }
    const instance = this.findEasyTierInstance(this.easyTierInstances, instanceId);
    if (instance === undefined) {
      return;
    }
    this.updateSelectedEasyTierInstance(instance);
    if (!this.easyTierPreconnectEnabled) {
      this.easyTierPreconnectEnabled = true;
      this.preferences?.saveEasyTierEnabled(true);
    }
    this.easyTierStatusText = this.easyTierInstanceStatus(instance, this.easyTierSnapshotFresh);
  }

  /** Home's mode index for one launch kind, so the address and its protocol always travel together. */
  private connectPageModeForKind(kind: PeerLaunchKind): number {
    if (kind === 'vnc') {
      return 1;
    }
    if (kind === 'rdp') {
      return 2;
    }
    return kind === 'file_transfer' ? 3 : 0;
  }

  private async preparePeerLaunch(targetValue: string, kind: PeerLaunchKind,
    rustdeskIdOnly: boolean = false): Promise<void> {
    if (this.sessionCloseInFlight) {
      return;
    }
    const target = targetValue.trim();
    if (target.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    rustdeskIdOnly = kind === 'remote_control' && rustdeskIdOnly;
    this.captureSessionReturnTab();
    this.updatePeerTarget(target);
    this.connectPageMode = this.connectPageModeForKind(kind);
    this.preferences?.saveTarget(target, this.connectPageMode);
    if (!this.easyTierPreconnectEnabled || !this.easyTierDataAvailable) {
      await this.launchPeerDirect(target, kind, rustdeskIdOnly);
      return;
    }
    if (this.easyTierRequestPending) {
      this.showEasyTierToast('已有 EasyTier 请求正在处理，请稍候或取消当前请求');
      return;
    }

    const context = this.abilityContext();
    this.beginEasyTierPreconnect(target, kind, '正在读取 EasyTier 实例状态', rustdeskIdOnly);
    const snapshot = await EasyTierApiService.readSnapshot(context);
    this.easyTierRequestPending = false;
    this.applyEasyTierSnapshot(snapshot);
    if (!snapshot.ok) {
      this.connectionUiPhase = 'idle';
      this.connectionUiMessage = '';
      EasyTierApiService.clearConnectionIntent(context);
      await this.launchPeerDirect(target, kind, rustdeskIdOnly);
      return;
    }
    if (this.easyTierSelectedInstanceId.length === 0) {
      if (snapshot.instances.length === 0) {
        this.failEasyTierPreconnect(target, kind, 'EasyTier 中没有可用实例，请先创建配置');
        return;
      }
      this.failEasyTierPreconnect(target, kind, '请先在 EasyTier 下拉栏中选择实例');
      return;
    }
    const instance = this.findEasyTierInstance(snapshot.instances, this.easyTierSelectedInstanceId);
    if (instance === undefined) {
      this.failEasyTierPreconnect(target, kind, '已选择的 EasyTier 实例不在当前快照中，请重新选择');
      return;
    }
    if (!EasyTierApiService.saveConnectionIntent(context, target, kind, rustdeskIdOnly)) {
      this.failEasyTierPreconnect(target, kind, '无法保存待恢复的 RustDesk 连接');
      return;
    }
    await this.continueEasyTierLaunch(instance, snapshot.fresh,
      new EasyTierConnectionIntent(target, kind, Date.now(), rustdeskIdOnly));
  }

  private async launchPeerDirect(target: string, kind: PeerLaunchKind,
    rustdeskIdOnly: boolean = false): Promise<void> {
    this.updatePeerTarget(target);
    this.preferences?.saveTarget(target, this.connectPageMode);
    if (kind === 'file_transfer') {
      await this.openTransferWorkspaceDirect();
      return;
    }
    await this.connectSessionDirect(kind as PrimarySessionKind, undefined, rustdeskIdOnly);
  }

  private beginEasyTierPreconnect(target: string, kind: PeerLaunchKind, message: string,
    rustdeskIdOnly: boolean = false): void {
    this.clearConnectionTimeout();
    this.connectionAttemptKind = kind === 'file_transfer' ? 'file_transfer' : 'primary';
    if (kind !== 'file_transfer') {
      this.lastConnectionKind = kind as PrimarySessionKind;
      this.lastConnectionRustdeskIdOnly = kind === 'remote_control' && rustdeskIdOnly;
    }
    this.connectionUiTarget = target;
    this.connectionUiPhase = 'waiting_for_easytier';
    this.connectionUiMessage = message;
    this.easyTierRequestPending = true;
    this.easyTierStatusText = message;
    this.errorText = '';
  }

  private failEasyTierPreconnect(target: string, kind: PeerLaunchKind, message: string): void {
    const normalizedMessage = message.trim().length > 0 ? message.trim() : 'EasyTier 预组网未完成';
    EasyTierApiService.clearConnectionIntent(this.abilityContext());
    this.connectionAttemptKind = kind === 'file_transfer' ? 'file_transfer' : 'primary';
    if (kind !== 'file_transfer') {
      this.lastConnectionKind = kind as PrimarySessionKind;
    }
    this.connectionUiTarget = target;
    this.connectionUiPhase = 'failed';
    this.connectionUiMessage = normalizedMessage;
    this.easyTierRequestPending = false;
    this.easyTierStatusText = normalizedMessage;
    this.errorText = normalizedMessage;
  }

  private async requestEasyTierStart(instanceId: string): Promise<void> {
    this.easyTierRequestPending = true;
    const outcome = await EasyTierApiService.request(
      this.abilityContext(),
      EASYTIER_OPERATION_START_INSTANCE,
      instanceId,
    );
    this.handleEasyTierRequestOutcome(outcome);
  }

  private handleEasyTierRequestOutcome(outcome: EasyTierApiRequestOutcome): void {
    if (outcome.ok) {
      return;
    }
    this.easyTierRequestPending = false;
    const intent = EasyTierApiService.loadConnectionIntent(this.abilityContext());
    EasyTierApiService.cancelPending(this.abilityContext());
    if (intent !== undefined) {
      this.failEasyTierPreconnect(intent.target, intent.kind, outcome.message);
      return;
    }
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    this.easyTierStatusText = outcome.message;
    this.errorText = outcome.message;
    this.showEasyTierToast(outcome.message);
  }

  private async applyEasyTierApiResult(result: EasyTierApiResultEvent): Promise<void> {
    this.lastConnectionRustdeskIdOnly = result.kind === 'remote_control' && result.rustdeskIdOnly;
    this.easyTierRequestPending = false;
    this.easyTierStatusText = result.message;
    if (result.operation === EASYTIER_OPERATION_START_INSTANCE) {
      if (!result.ok || result.code !== 'OK' || result.instance === undefined
        || result.instance.state !== EASYTIER_STATE_RUNNING || result.target.length === 0) {
        this.failEasyTierPreconnect(
          result.target.length > 0 ? result.target : this.connectionUiTarget,
          result.kind,
          result.message,
        );
        return;
      }
      this.updateSelectedEasyTierInstance(result.instance);
      this.easyTierStatusText = this.easyTierInstanceStatus(result.instance);
      this.connectionUiPhase = 'idle';
      this.connectionUiMessage = '';
      await this.launchPeerDirect(result.target, result.kind, result.rustdeskIdOnly);
    }
  }

  private async refreshEasyTierSnapshot(showError: boolean): Promise<EasyTierSnapshotEvent> {
    const snapshot = await EasyTierApiService.readSnapshot(this.abilityContext());
    this.applyEasyTierSnapshot(snapshot);
    if (!snapshot.ok && showError) {
      this.errorText = snapshot.message;
      this.showEasyTierToast(snapshot.message);
    }
    return snapshot;
  }

  private applyEasyTierSnapshot(snapshot: EasyTierSnapshotEvent): void {
    if (!snapshot.ok) {
      this.easyTierDataAvailable = false;
      this.easyTierSnapshotFresh = false;
      this.easyTierInstances = [];
      this.easyTierSelectedInstanceState = '';
      if (this.easyTierPreconnectEnabled && !this.easyTierRequestPending) {
        this.easyTierStatusText = snapshot.message;
      }
      return;
    }
    this.easyTierDataAvailable = true;
    this.easyTierSnapshotFresh = snapshot.fresh;
    this.easyTierInstances = snapshot.instances;
    if (this.easyTierSelectedInstanceId.length === 0) {
      if (this.easyTierPreconnectEnabled && !this.easyTierRequestPending) {
        this.easyTierStatusText = snapshot.instances.length === 0
          ? 'EasyTier 中暂无可用实例'
          : (snapshot.fresh ? '请选择 EasyTier 实例' : 'EasyTier 实例状态已过期');
      }
      return;
    }
    const selected = this.findEasyTierInstance(snapshot.instances, this.easyTierSelectedInstanceId);
    if (selected === undefined) {
      this.easyTierSelectedInstanceState = '';
      if (this.easyTierPreconnectEnabled) {
        this.easyTierPreconnectEnabled = false;
        this.preferences?.saveEasyTierEnabled(false);
      }
      if (!this.easyTierRequestPending) {
        this.easyTierStatusText = '已选择的 EasyTier 实例不在当前快照中，已改为不组网';
      }
      return;
    }
    this.updateSelectedEasyTierInstance(selected);
    if (!this.easyTierRequestPending) {
      this.easyTierStatusText = this.easyTierInstanceStatus(selected, snapshot.fresh);
    }
  }

  private findEasyTierInstance(instances: EasyTierInstanceSummary[], instanceId: string):
    EasyTierInstanceSummary | undefined {
    for (let index = 0; index < instances.length; index += 1) {
      if (instances[index].instanceId === instanceId) {
        return instances[index];
      }
    }
    return undefined;
  }

  private async continueEasyTierLaunch(instance: EasyTierInstanceSummary, snapshotFresh: boolean,
    intent: EasyTierConnectionIntent): Promise<void> {
    this.updateSelectedEasyTierInstance(instance);
    if (snapshotFresh && instance.state === EASYTIER_STATE_RUNNING) {
      EasyTierApiService.clearConnectionIntent(this.abilityContext());
      this.easyTierRequestPending = false;
      this.connectionUiPhase = 'idle';
      this.connectionUiMessage = '';
      this.easyTierStatusText = this.easyTierInstanceStatus(instance, true);
      await this.launchPeerDirect(intent.target, intent.kind, intent.rustdeskIdOnly);
      return;
    }
    this.beginEasyTierPreconnect(
      intent.target,
      intent.kind,
      snapshotFresh
        ? `正在请求 EasyTier 启动 ${instance.instanceName}`
        : `EasyTier 状态已过期，正在请求启动 ${instance.instanceName}`,
      intent.rustdeskIdOnly,
    );
    await this.requestEasyTierStart(instance.instanceId);
  }

  private updateSelectedEasyTierInstance(instance: EasyTierInstanceSummary): void {
    const selectionChanged = this.easyTierSelectedInstanceId !== instance.instanceId
      || this.easyTierSelectedInstanceName !== instance.instanceName;
    this.easyTierSelectedInstanceId = instance.instanceId;
    this.easyTierSelectedInstanceName = instance.instanceName;
    this.easyTierSelectedInstanceState = instance.state;
    if (selectionChanged) {
      this.preferences?.saveEasyTierInstance(instance.instanceId, instance.instanceName);
    }
  }

  private easyTierInstanceStatus(instance: EasyTierInstanceSummary, snapshotFresh: boolean = true): string {
    if (!snapshotFresh) {
      return `${instance.instanceName} 状态已过期`;
    }
    if (instance.state === EASYTIER_STATE_RUNNING) {
      return instance.peerCount > 0
        ? `${instance.instanceName} 正在运行 · ${instance.peerCount} 个对端`
        : `${instance.instanceName} 正在运行`;
    }
    if (instance.state === 'starting') {
      return `${instance.instanceName} 正在启动`;
    }
    return `${instance.instanceName} 已停止`;
  }

  private cancelEasyTierRequest(): void {
    EasyTierApiService.cancelPending(this.abilityContext());
    this.easyTierRequestPending = false;
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    this.easyTierStatusText = '已取消 EasyTier 预组网';
  }

  private showEasyTierToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 5000 });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to show EasyTier feedback: %{public}s', String(error));
    }
  }

  /**
   * One informational line about the running session.
   *
   * It is a notice, not an error: it is used where the native side confirms a
   * setting is in force but could not act on it yet, so the operator is told
   * rather than left with a silent log entry.
   */
  private showSessionNotice(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 5000 });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to show session notice: %{public}s', String(error));
    }
  }

  private async refreshNativeState(): Promise<void> {
    const state = rustDeskRuntimeController.state();
    if (!this.pageVisible || !this.runtimeInitialized || !state.discoveryAllowed) {
      return;
    }
    try {
      const report = await rustDeskRuntimeController.queryDecoderCapabilityReport();
      if (report === undefined || !this.pageVisible) {
        return;
      }
      this.decoderCapabilityReport = report;
      // The real HAR returns advertised_metadata with h264_decoder/hevc_decoder
      // and not_measured throughput/HDR. It has no old recommendation rows.
      // Do not overwrite selected codec, FPS, Surface path or measured UI state.
      const serverGeneration = this.serverTestGeneration;
      const serverReply = await this.mainBridge.loadServerConfig();
      if (!this.pageVisible || serverGeneration !== this.serverTestGeneration ||
        state.ownerGeneration !== rustDeskRuntimeController.state().ownerGeneration) {
        return;
      }
      this.applyServerProfileReply(serverReply);
      this.serverConfig = this.serverConfigFromReply(serverReply);
      this.apiServer = this.serverConfig.effectiveApiServer;
    } catch (error) {
      if (!this.pageVisible || state.ownerGeneration !== rustDeskRuntimeController.state().ownerGeneration) {
        return;
      }
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
      // The envelope can carry clipboard text and file paths, so only its size is
      // reported: the failure itself is what the operator needs here.
      hilog.error(DOMAIN, TAG, 'parseResponse failed: %{public}s length=%{public}d', String(error), raw.length);
      throw new Error(String(error));
    }
  }

  private beginConnectionAttempt(kind: PrimarySessionKind, target: string): void {
    this.clearConnectionTimeout();
    this.connectionAttemptKind = 'primary';
    this.lastConnectionKind = kind;
    this.connectionUiTarget = target;
    this.connectionUiPhase = 'connecting';
    this.connectionUiMessage = kind === 'vnc'
      ? '正在按 RFB 协议连接 VNC 服务端。'
      : (kind === 'rdp'
        ? '正在协商 RDP 连接与安全通道。'
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
    if (this.connectionUiPhase === 'waiting_for_easytier') {
      this.cancelEasyTierRequest();
      return;
    }
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
    if (this.sessionTransitionBusy()) {
      // A wrong credential is answered by closing the wire and dialling a fresh
      // viewer, so a retry that lands while that close is still releasing is
      // remembered and run when it finishes instead of being dropped.
      this.pendingConnectionRetry = target;
      hilog.info(DOMAIN, TAG, 'retry deferred until the failed attempt finished releasing');
      return;
    }
    void this.preparePeerLaunch(target, this.lastConnectionKind, this.lastConnectionRustdeskIdOnly);
  }

  private dismissConnectionAttempt(): void {
    this.clearConnectionTimeout();
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    this.connectionAttemptKind = 'primary';
  }

  private async connectRemoteSession(): Promise<void> {
    await this.preparePeerLaunch(this.peerTarget, 'remote_control');
  }

  private async connectVncSession(): Promise<void> {
    await this.preparePeerLaunch(this.peerTarget, 'vnc');
  }

  private async connectRdpSession(): Promise<void> {
    await this.preparePeerLaunch(this.peerTarget, 'rdp');
  }

  private syncRemoteSessionTabs(): void {
    this.remoteSessionTabs = this.remoteSessionTabsController.snapshot();
  }

  private setSessionVideoPaused(sessionId: string, paused: boolean): boolean {
    if (sessionId.length === 0) {
      return false;
    }
    const response = this.nativeSessionBridge.setVideoPaused(sessionId, paused);
    if (!response.ok) {
      hilog.warn(
        DOMAIN,
        TAG,
        'setSessionVideoPaused sessionId=%{public}s paused=%{public}s message=%{public}s',
        sessionId,
        String(paused),
        response.message ?? '',
      );
    }
    return response.ok;
  }

  private async suspendActiveSessionForNewConnection(): Promise<void> {
    if (this.activeSessionId.length === 0) {
      return;
    }
    const sessionId = this.activeSessionId;
    const tab = this.remoteSessionTabsController.get(sessionId);
    if (tab !== undefined) {
      tab.coreSessionId = this.activeCoreSessionId;
      tab.phase = this.sessionPhase;
      tab.message = this.sessionMessage;
      tab.connectionSummary = this.connectionSummary;
      tab.connected = this.sessionPhase === 'connected';
      tab.paused = true;
      tab.audioMuted = this.remoteAudioState.muted;
      tab.audioPreferenceCaptured = this.remoteAudioState.available;
      tab.uiStateCaptured = true;
      tab.touchMode = this.touchMode;
      tab.relativeMouseMode = this.relativeMouseMode;
      tab.inputEnabled = this.inputEnabled;
      tab.toolbarExpanded = this.isMiniBarExpanded;
      tab.displayIndex = this.viewportModel.getCurrentDisplayIndex();
      if (tab.peerInfo !== undefined) {
        tab.peerInfo.current_display = String(tab.displayIndex);
      }
      tab.viewScale = this.previewUserScale;
      tab.viewOffsetX = this.previewUserOffsetX;
      tab.viewOffsetY = this.previewUserOffsetY;
      tab.viewRotation = this.previewUserRotation;
      tab.refreshRate = this.sessionDisplayController.getRefreshRate();
      tab.sessionDefaults = this.copySessionDefaults(this.activeSessionDefaults);
      tab.serverConfig = this.copyServerConfig(this.activeSessionServerConfig);
      tab.shareTargetKind = this.activeSessionShareTargetKind;
      tab.rustdeskIdOnly = this.activeSessionRustdeskIdOnly;
      tab.forceRelay = this.activeSessionForceRelay;
    }
    await this.clipboardController?.stopAndDrainRemoteWrite();
    this.inputController?.releasePressedButtons();
    this.hideSystemIme(false);
    this.hideSoftKeyboard();
    const surfaceReleased = this.clearSurfaceBinding();
    if (surfaceReleased) {
      this.previewSurfaceId = '';
      this.previewSurfaceDestroyAuthorized = true;
    } else {
      // The producer still owes a join, so the pane cannot be given back and
      // this is not claimed as a release. The holder id stays on its controller
      // for the real detach, and the native side keeps the viewer.
      this.previewSurfaceDestroyAuthorized = false;
      hilog.warn(DOMAIN, TAG, 'suspend kept session=%{public}s without a confirmed Surface release', sessionId);
    }
    this.setSessionVideoPaused(sessionId, true);
    this.nativeSessionBridge.setRemoteAudioMuted(sessionId, true);
    this.closeRemoteAudio();
    this.remoteInteractionReady = false;
    this.showPreviewModal = false;
    this.previewSurfaceVisible = false;
    this.connectionGeneration += 1;
    this.activeSessionId = '';
    this.activeCoreSessionId = '';
    this.syncClipboardController();
    this.syncInputInterceptor();
    this.syncRemoteSessionSharing();
    this.syncRemoteSessionTabs();
  }

  private async connectRemoteSessionHandoff(envelope: RemoteSessionHandoffEnvelope): Promise<void> {
    this.sessionReturnTabIndex = 0;
    try {
      await this.connectSessionDirect('remote_control', envelope);
    } finally {
      envelope.connToken = '';
      envelope.key = '';
    }
  }

  private async connectSessionDirect(
    kind: PrimarySessionKind,
    handoff?: RemoteSessionHandoffEnvelope,
    rustdeskIdOnly: boolean = false,
  ): Promise<void> {
    if (this.sessionTransitionBusy()) {
      this.connectionUiMessage = '已有连接请求正在处理，请稍候';
      return;
    }
    this.sessionConnectInFlight = true;
    try {
      await this.performConnectSessionDirect(kind, handoff, rustdeskIdOnly);
    } finally {
      this.pendingDirectCredentials?.wipePassword();
      this.pendingDirectCredentials = undefined;
      this.rdpDialCredentials?.wipePassword();
      this.rdpDialCredentials = undefined;
      this.sessionConnectInFlight = false;
      this.materializePendingTransitionClose();
      this.drainPendingSessionTransitions();
    }
  }

  private async performConnectSessionDirect(
    kind: PrimarySessionKind,
    handoff?: RemoteSessionHandoffEnvelope,
    rustdeskIdOnly: boolean = false,
  ): Promise<void> {
    if (this.sessionCloseInFlight) {
      return;
    }
    if (!this.runtimeInitialized) {
      void this.initializeRuntime();
    }
    let connectionTarget = handoff === undefined
      ? this.peerTarget.trim()
      : RemoteSessionHandoffService.buildConnectionTarget(handoff);
    const displayTarget = handoff === undefined ? connectionTarget : handoff.target.trim();
    const idOnly = kind === 'remote_control' && (rustdeskIdOnly ||
      (handoff?.targetKind === 'target' && this.handoffTargetKind(displayTarget) === 'ip'));
    this.lastConnectionRustdeskIdOnly = idOnly;
    if (connectionTarget.length === 0 || displayTarget.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    if (handoff === undefined) {
      // The mode bar names the protocol; the field holds only an address, so a
      // typed scheme is refused rather than allowed to override the chosen mode.
      const issue = targetFieldIssue(kind, connectionTarget);
      if (issue !== '') {
        this.errorText = targetFieldIssueText(kind, issue);
        return;
      }
    }
    this.peerTarget = displayTarget;
    this.connectPageMode = this.connectPageModeForKind(kind);
    this.preferences?.saveTarget(displayTarget, this.connectPageMode);
    // The selected mode is the wire: the credential dialog is only ever opened for
    // a wire this client can speak, and the engine is given that wire's scheme.
    const directWire: DirectWireProtocol | undefined = kind === 'rdp'
      ? 'rdp'
      : (kind === 'vnc' ? 'vnc' : undefined);
    const sessionKind: PrimarySessionKind = kind;
    const existingTab = this.remoteSessionTabs.find((tab: RemoteSessionTab) =>
      tab.target === displayTarget && tab.kind === sessionKind && tab.rustdeskIdOnly === idOnly && tab.phase !== 'closed');
    if (existingTab !== undefined) {
      await this.switchRemoteSessionTab(existingTab.sessionId);
      return;
    }
    if (!this.remoteSessionTabsController.canAdd()) {
      this.errorText = '最多可同时保留 6 个远控会话，请先关闭一个标签页';
      return;
    }
    // A direct VNC/RDP viewer consumes its password when it dials and its endpoint
    // has to name the RDP account, so the answers are collected before anything is
    // registered. Nothing is created here, which is why a cancel can leave no
    // session, no Surface and no secret behind. The stash is matched by the wire
    // the dial will really use, so an answer collected for one protocol is never
    // spent on the other.
    let directCredentials: DirectWireCredentials | undefined = undefined;
    if (directWire !== undefined) {
      directCredentials = this.takePendingDirectCredentials(directWire, displayTarget);
      if (directCredentials === undefined) {
        this.openDirectCredentialsDialog(directWire, displayTarget);
        return;
      }
      connectionTarget = directCredentials.dialTarget;
    }
    const credentialGeneration = this.rdpCredentialGeneration;
    this.rdpDialCredentials = directWire === 'rdp' ? directCredentials : undefined;
    if (this.activeSessionId.length > 0) {
      await this.suspendActiveSessionForNewConnection();
    }
    // Initial RDP credentials wait in memory for TLS trust resolution. Once a
    // certificate has been accepted, the redial clears its password immediately.
    let sessionPassword: string = directCredentials === undefined ? '' : directCredentials.password;
    this.activeSessionPassword = sessionPassword;
    this.clearDirectWireFailure();
    this.trustThisDevice = false;
    this.canTrustDevice = true;
    this.activeSessionShareTarget = displayTarget;
    const targetKind = handoff?.targetKind ?? (idOnly ? 'target' : this.handoffTargetKind(displayTarget));
    this.activeSessionShareTargetKind = targetKind;
    this.activeSessionRustdeskIdOnly = idOnly;
    this.activeSessionApprovedProfile = targetKind === 'ip'
      ? undefined : this.serverProfile.captureApproved();
    this.activeSessionServerConfig = targetKind === 'ip'
      ? new ServerConfig()
      : (handoff === undefined
        ? this.savedRouteConfig(this.activeSessionApprovedProfile)
        : this.serverConfigFromHandoff(handoff));
    // The peer ID stays bare. Only approvedServerProfile selects its server;
    // the retired id@server?key spelling is not this engine's target grammar.
    this.activeSessionPasswordEphemeral = handoff !== undefined || directWire !== undefined;
    this.handoffPasswordAutoSubmitAttempted = false;
    if (handoff !== undefined) {
      hilog.info(
        DOMAIN,
        TAG,
        'handoff received source=%{public}s targetKind=%{public}s connTokenPresent=%{public}s',
        handoff.source,
        targetKind,
        String((handoff.connToken ?? '').length > 0),
      );
    }
    this.activeSessionForceRelay = targetKind === 'target' ? (handoff?.forceRelay ?? false) : false;
    await this.applySessionFullscreen(false, true);
    if (directWire === 'rdp' && (credentialGeneration !== this.rdpCredentialGeneration ||
      !this.pageVisible || !this.appForeground)) {
      directCredentials?.wipePassword();
      this.rdpDialCredentials = undefined;
      this.activeSessionPassword = '';
      return;
    }
    this.beginConnectionAttempt(sessionKind, displayTarget);
    this.activeSessionKind = sessionKind;
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
    this.connectionSummary = sessionKind === 'vnc'
      ? '正在连接 VNC 服务端...'
      : (sessionKind === 'rdp' ? '正在连接远程桌面...' : '正在建立远控连接...');
    this.sessionMessage = sessionKind === 'vnc'
      ? '正在连接 VNC'
      : (sessionKind === 'rdp' ? '正在连接远程桌面' : '正在连接远端');
    hilog.info(DOMAIN, TAG, 'connectSession kind=%{public}s target=%{public}s', sessionKind, displayTarget);
    this.showTransferWorkspace = false;
    this.showPreviewModal = false;
    this.performanceTuningApplied = false;
    this.resetPreviewState();
    const connectionGeneration = this.connectionGeneration + 1;
    this.connectionGeneration = connectionGeneration;
    if (sessionKind === 'rdp') {
      const measured = await this.measureRdpPaneBeforeAdd(connectionGeneration);
      if (!measured || connectionGeneration !== this.connectionGeneration ||
        credentialGeneration !== this.rdpCredentialGeneration || !this.pageVisible || !this.appForeground) {
        if (directCredentials !== undefined) {
          directCredentials.password = '';
        }
        this.activeSessionPassword = '';
        this.rdpDialCredentials = undefined;
        if (connectionGeneration === this.connectionGeneration) {
          this.failConnectionAttempt('无法测量本机预览区域，未创建 RDP 连接');
        }
        return;
      }
    }
    const sessionCreated = await this.createSession(
      connectionTarget,
      sessionKind,
      sessionPassword,
      this.activeSessionPasswordEphemeral,
      this.activeSessionForceRelay,
      handoff?.connToken ?? '',
      directCredentials === undefined ? '' : directCredentials.certificateSha256,
    );
    sessionPassword = '';
    if (directCredentials !== undefined) {
      if (sessionCreated && sessionKind === 'rdp') {
        this.rdpCertificateCredentials.set(this.activeSessionId, directCredentials);
      }
      if (!sessionCreated || sessionKind !== 'rdp' || directCredentials.certificateAccepted) {
        directCredentials.wipePassword();
      }
      this.rdpDialCredentials = undefined;
      this.activeSessionPassword = '';
    }
    if (sessionKind === 'rdp' && credentialGeneration !== this.rdpCredentialGeneration) {
      this.forgetRdpCertificateCredentials(this.activeSessionId);
      this.failConnectionAttempt(this.certificateMessage($r('app.string.rdp_certificate_privacy_cancelled')));
      return;
    }
    if (connectionGeneration !== this.connectionGeneration) {
      return;
    }
    if (!sessionCreated) {
      this.failConnectionAttempt(this.errorText || '无法创建连接会话');
      return;
    }
    const createdTab = this.remoteSessionTabsController.add(this.activeSessionId, displayTarget, sessionKind);
    if (createdTab === undefined) {
      const rejectedSessionId = this.activeSessionId;
      this.forgetRdpCertificateCredentials(rejectedSessionId);
      this.nativeSessionBridge.closeSession(rejectedSessionId);
      this.activeSessionId = '';
      this.activeCoreSessionId = '';
      this.failConnectionAttempt('远控会话标签数量已达到上限');
      return;
    }
    createdTab.coreSessionId = this.activeCoreSessionId;
    createdTab.phase = this.sessionPhase;
    createdTab.message = this.sessionMessage;
    createdTab.connectionSummary = this.connectionSummary;
    createdTab.sessionDefaults = this.copySessionDefaults(this.activeSessionDefaults);
    createdTab.serverConfig = this.copyServerConfig(this.activeSessionServerConfig);
    createdTab.shareTargetKind = this.activeSessionShareTargetKind;
    createdTab.rustdeskIdOnly = this.activeSessionRustdeskIdOnly;
    createdTab.forceRelay = this.activeSessionForceRelay;
    this.syncRemoteSessionTabs();
    // The engine latches its software-only path for the whole round when the first
    // login has no Surface to reserve against, and a later bind cannot undo it. So
    // the real Surface is created and bound before start/login rather than when the
    // first peer_info arrives: the pane is already visible and this waits, bounded
    // and cancelable, for the component the framework really created.
    const surfaceBound = await this.bindPreviewSurfaceBeforeStart(connectionGeneration);
    if (connectionGeneration !== this.connectionGeneration) {
      return;
    }
    if (sessionKind === 'rdp' && credentialGeneration !== this.rdpCredentialGeneration) {
      this.failConnectionAttempt(this.certificateMessage($r('app.string.rdp_certificate_privacy_cancelled')));
      return;
    }
    if (!surfaceBound) {
      // Without a real Surface the session is refused with its reason instead of
      // being started into a degraded path nobody chose.
      this.failConnectionAttempt(this.errorText || '视频 Surface 未能在连接前绑定，已取消连接');
      return;
    }
    // The operator's codec preference is applied before the session starts, so the
    // first LoginRequest already advertises the chosen codec instead of letting the
    // peer pick a default and switching afterwards. The native side stores it in the
    // session's own option store and answers with the value it read back; a
    // pre-start refusal is a bridge defect to be fixed there, not a reason to
    // reorder this call.
    this.applyCodecPreference();
    const sessionStarted = await this.startSession();
    if (connectionGeneration !== this.connectionGeneration || !sessionStarted) {
      if (connectionGeneration === this.connectionGeneration) {
        this.failConnectionAttempt(this.errorText || '无法启动连接');
      }
      return;
    }
    if (sessionKind === 'rdp' && credentialGeneration !== this.rdpCredentialGeneration) {
      this.failConnectionAttempt(this.certificateMessage($r('app.string.rdp_certificate_privacy_cancelled')));
      return;
    }
    this.connectionUiPhase = 'connecting';
    this.connectionUiMessage = '正在等待远端响应；可随时取消。';
    this.scheduleConnectionTimeout();
    this.publishDataTransferChanged();
    this.applyRemoteAudioPollingForKind(sessionKind);
    this.startPolling();
    void this.pollSessionEvents();
  }

  /**
   * Creates and binds the real preview Surface before a session starts.
   *
   * Returns whether a real Surface was bound. The wait is bounded and cancelable:
   * a generation change (a cancel, a newer connection, the page going away) ends
   * it without any claim, and a bind the native side refuses is reported as its
   * own reason rather than replaced by a fake destination or a blind delay. A
   * session that is not a video session does not come through here at all.
   */
  private async bindPreviewSurfaceBeforeStart(connectionGeneration: number): Promise<boolean> {
    this.previewSurfaceBindFailure = '';
    try {
      await this.preparePreviewSurface(connectionGeneration);
    } catch (error) {
      if (connectionGeneration === this.connectionGeneration) {
        // A native refusal names the reason itself; only a bounded wait that ran
        // out has no native text and uses this client's own wording.
        this.errorText = this.previewSurfaceBindFailure.length > 0
          ? this.previewSurfaceBindFailure
          : `视频 Surface 未能在连接前就绪：${String(error)}`;
        hilog.error(DOMAIN, TAG, 'bindPreviewSurfaceBeforeStart failed: %{public}s', this.errorText);
      }
      return false;
    }
    return connectionGeneration === this.connectionGeneration
      && this.activeSessionId.length > 0
      && this.previewComponentId.length > 0;
  }

  private async createSession(
    target: string,
    kind: PrimarySessionKind,
    password: string,
    passwordEphemeral: boolean,
    forceRelay: boolean,
    connToken: string = '',
    rdpCertificateSha256: string = '',
  ): Promise<boolean> {
    try {
      const options: SessionStartOptions = {
        password,
        connToken,
        forceRelay,
        isFileTransfer: false,
        isViewOnly: false,
        passwordEphemeral,
      };
      if (kind === 'remote_control') {
        // The controlled host reads the rate once, from the login options, and
        // holds it for the whole session, so the choice has to travel with the
        // start rather than follow it. The direct VNC/RDP wires have no rate
        // control and refuse a non-zero rate at add time, so it is only named
        // for a Core session.
        options.customFps = this.selectedRefreshRate;
        options.rustdeskIdOnly = this.activeSessionRustdeskIdOnly;
        // The route is the approval captured for this attempt, not a draft the
        // operator may still be editing; the engine refuses an ID route without one.
        const approvedRoute = this.activeSessionApprovedProfile;
        if (approvedRoute !== undefined) {
          options.approvedServerProfile = approvedRoute;
        }
      }
      if (kind === 'rdp') {
        const size = computeRdpDesktopSize(this.previewViewWidth, this.previewViewHeight,
          this.getUIContext().vp2px(1), this.activeSessionDefaults.rdpResolution);
        options.rdpDesktopWidth = size.width;
        options.rdpDesktopHeight = size.height;
        options.rdpScaleFactor = computeRdpScaleFactor(this.getUIContext().vp2px(1),
          this.activeSessionDefaults.rdpScaleFactor);
        options.rdpAudio = this.activeSessionDefaults.rdpAudioEnabled;
      } else if (kind === 'vnc') {
        options.vncQuality = this.activeSessionDefaults.vncQuality;
      }
      if (rdpCertificateSha256.length > 0 && kind === 'rdp') {
        // Only a remembered certificate or an explicit decision in the current
        // certificate dialog supplies a pin; absence keeps system-root validation.
        options.rdpCertificateSha256 = rdpCertificateSha256;
      }
      const response = this.nativeSessionBridge.addSession(this.nextSessionId(), target, options);
      this.updateSessionState(response);
      if (!response.ok || this.activeSessionId.length === 0) {
        return false;
      }
      this.syncClipboardController();
      if (kind === 'vnc' || kind === 'rdp') {
        // The engine decides input policy for these protocols from what the
        // server grants, so the viewer must not also force a local view-only
        // ceiling on top of it.
        return true;
      }
      const policy = this.nativeSessionBridge.setViewOnly(this.activeSessionId, false);
      this.updateSessionState(policy);
      return policy.ok;
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'createSession failed target=%{public}s error=%{public}s', target, this.errorText);
      return false;
    }
  }
  private async measureRdpPaneBeforeAdd(generation: number): Promise<boolean> {
    try {
      await this.applySessionFullscreen(true);
      await this.waitForPreviewWindowReady();
      if (generation !== this.connectionGeneration || !this.pageVisible || !this.appForeground) {
        return false;
      }
      this.previewViewWidth = 0;
      this.previewViewHeight = 0;
      this.showPreviewModal = true;
      this.registerFoldHoverListeners();
      for (let index = 0; index < PREVIEW_SURFACE_WAIT_ATTEMPTS; index += 1) {
        if (generation !== this.connectionGeneration || !this.pageVisible || !this.appForeground) {
          return false;
        }
        if (this.previewViewWidth > 0 && this.previewViewHeight > 0) {
          return true;
        }
        await new Promise<void>((resolve) => setTimeout((): void => resolve(), PREVIEW_SURFACE_WAIT_INTERVAL_MS));
      }
    } catch (error) {
      this.errorText = String(error);
    }
    return false;
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

  private openPasswordDialog(kind: PasswordSessionKind = 'primary', message: string = '', initialMode: AuthDialogMode = 'password'): void {
    const wasVisible = this.passwordDialogVisible;
    this.passwordSessionKind = kind;
    if (!wasVisible) {
      this.passwordDraft = '';
      this.code2faDraft = '';
    }
    this.authChallengeMode = initialMode;
    this.authDialogMode = initialMode;
    this.authErrorMessage = message;
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

  private dismissPasswordDialogFor(kind: PasswordSessionKind): void {
    if (!this.passwordDialogVisible || this.passwordSessionKind !== kind) {
      return;
    }
    this.passwordDialogVisible = false;
    this.passwordDraft = '';
    this.code2faDraft = '';
    this.authChallengeMode = 'password';
    this.authErrorMessage = '';
    this.clearPasswordTimeout();
  }

  /**
   * Whether this attempt can really persist the password it collects.
   *
   * The remember switch writes the credential into Core's peer config on login,
   * so it is offered only where the login carries the flag: a handoff password is
   * explicitly one-time and Core folds that in, and a switch whose value could not
   * be stored would be a promise this component cannot keep.
   */
  private canPersistSessionPassword(): boolean {
    if (this.passwordSessionKind === 'file_transfer') {
      return true;
    }
    return !this.activeSessionPasswordEphemeral;
  }

  private async submitPassword(passwordInput?: string, rememberPasswordInput?: boolean): Promise<void> {
    if (this.passwordSessionKind === 'primary' && !this.activeSessionId) {
      return;
    }
    if (this.passwordSessionKind === 'file_transfer' && !this.transferManager.isReady()) {
      return;
    }
    if (this.authDialogMode === '2fa') {
      const code = this.code2faDraft.trim();
      if (this.authChallengeMode !== '2fa') {
        this.authErrorMessage = '远端尚未请求 2FA。RustDesk 必须先完成密码验证，再提交第二因素验证码。';
        this.errorText = this.authErrorMessage;
        hilog.warn(
          DOMAIN,
          TAG,
          'blocked premature 2fa submit sessionId=%{public}s challenge=%{public}s',
          this.activeSessionId,
          this.authChallengeMode,
        );
        return;
      }
      if (!/^\d{6}$/.test(code)) {
        this.authErrorMessage = '请输入完整的 6 位 2FA 验证码';
        this.errorText = this.authErrorMessage;
        return;
      }
      this.passwordDialogVisible = false;
      this.authErrorMessage = '';
      this.clearPasswordTimeout();
      this.connectionUiPhase = 'authenticating';
      this.connectionUiMessage = '2FA 验证码已提交，正在等待远端验证。';
      this.scheduleConnectionTimeout();
      try {
        const response = this.nativeSessionBridge.send2fa(this.activeSessionId, code, this.trustThisDevice);
        hilog.info(
          DOMAIN,
          TAG,
          'submit2fa sessionId=%{public}s codeLength=%{public}d trust=%{public}s ok=%{public}s phase=%{public}s message=%{public}s',
          this.activeSessionId,
          code.length,
          String(this.trustThisDevice),
          String(response.ok),
          response.session?.phase ?? '',
          response.message ?? '',
        );
        this.updateSessionState(response);
        if (!response.ok) {
          if ((response.message ?? '').includes('has not requested 2FA')) {
            this.connectionUiPhase = 'awaiting_password';
            this.connectionUiMessage = '远端尚未请求 2FA，请先完成密码验证。';
            this.openPasswordDialog('primary', this.connectionUiMessage, 'password');
            return;
          }
          this.failConnectionAttempt(response.message ?? '2FA 验证失败');
        }
      } catch (error) {
        this.errorText = String(error);
        this.failConnectionAttempt(this.errorText);
      }
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
    if (this.passwordSessionKind === 'primary') {
      this.activeSessionPassword = password;
    }
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
      const remember = this.activeSessionPasswordEphemeral ? false : this.rememberPassword;
      const response = this.nativeSessionBridge.login(this.activeSessionId, password, remember);
      hilog.info(DOMAIN, TAG, 'submitPassword sessionId=%{public}s remember=%{public}s ok=%{public}s', this.activeSessionId, String(remember), String(response.ok));
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

  /**
   * Asks for the credentials one direct wire needs before it is registered.
   *
   * `protocol` is the wire the selected mode names, so the fields asked for are
   * the ones that dial will use. Nothing is created here: no session id is taken,
   * no Surface is
   * bound and no viewer is dialled, so cancelling this dialog leaves the previous
   * session and the credential state exactly as they were.
   */
  private openDirectCredentialsDialog(
    protocol: DirectWireProtocol,
    displayTarget: string,
  ): void {
    this.discardDirectCredentialSecrets();
    this.directCredentialsProtocol = protocol;
    this.directCredentialsTarget = displayTarget;
    // The account last answered for this same endpoint is offered back: a retry
    // after a refused password asks for the password alone rather than for an
    // account that has not changed.
    const saved = this.findDirectoryPeer(displayTarget, protocol, false);
    const username: string = protocol === 'rdp' && this.directWireUsernameTarget === displayTarget
      ? this.directCredentialsUsername : saved.rdpUsername;
    this.directCredentialsUsername = username;
    this.directCredentialPassword = '';
    this.directCredentialsError = '';
    this.directCredentialsVisible = true;
    this.clearConnectionTimeout();
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    hilog.info(
      DOMAIN,
      TAG,
      'direct credentials requested protocol=%{public}s target=%{public}s userPresent=%{public}s',
      protocol,
      displayTarget,
      String(this.directCredentialsUsername.length > 0),
    );
  }

  /** Drops the secret copies one direct credential request had collected. */
  private discardDirectCredentialSecrets(): void {
    this.pendingDirectCredentials?.wipePassword();
    this.pendingDirectCredentials = undefined;
    this.directCredentialPassword = '';
    this.rdpCredentialPinOverride = '';
    this.rdpCredentialPinOverrideTarget = '';
  }

  /** Drops the request and every secret it had collected. */
  private cancelDirectCredentials(): void {
    this.directCredentialsVisible = false;
    this.directCredentialsError = '';
    this.discardDirectCredentialSecrets();
    this.directCredentialsUsername = '';
    this.directWireUsernameTarget = '';
    this.directCredentialsTarget = '';
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = '';
    hilog.info(DOMAIN, TAG, 'direct credentials cancelled protocol=%{public}s', this.directCredentialsProtocol);
  }

  /**
   * Validates the answers against the engine's own rules and starts the dial.
   *
   * A refused answer stays in the dialog with its reason instead of being
   * normalized into something the engine would reject later. What is accepted is
   * held until the start call takes it, and the drafts are cleared immediately so
   * no copy of the secret outlives the one the dial needs.
   */
  private submitDirectCredentials(): void {
    if (!this.directCredentialsVisible) {
      return;
    }
    const protocol = this.directCredentialsProtocol;
    const displayTarget = this.directCredentialsTarget;
    const password = this.directCredentialPassword;
    const user = this.directCredentialsUsername.trim();
    if (protocol === 'rdp') {
      const userCheck = checkRdpUser(user);
      if (!userCheck.ok) {
        this.directCredentialsError = userCheck.reason === 'required'
          ? $r('app.string.direct_credentials_username_required')
          : (userCheck.reason === 'too_long'
            ? $r('app.string.direct_credentials_username_too_long')
            : $r('app.string.direct_credentials_username_invalid'));
        return;
      }
    }
    const dialTarget = directDialTarget(protocol, displayTarget, user);
    let certificateSha256 = '';
    const certificateAccepted = protocol === 'rdp' && this.rdpCredentialPinOverrideTarget === displayTarget;
    if (protocol === 'rdp') {
      try {
        certificateSha256 = certificateAccepted ? this.rdpCredentialPinOverride
          : (this.preferences?.rdpCertificateSha256(displayTarget) ?? '');
      } catch (error) {
        this.directCredentialsError = String(error);
        return;
      }
    }
    const credentials = new DirectWireCredentials();
    credentials.kind = protocol;
    credentials.displayTarget = displayTarget;
    credentials.dialTarget = dialTarget;
    credentials.username = user;
    credentials.password = password;
    credentials.certificateSha256 = certificateSha256;
    credentials.certificateAccepted = certificateAccepted;
    this.pendingDirectCredentials = credentials;
    this.directCredentialsVisible = false;
    this.directCredentialsError = '';
    this.directCredentialPassword = '';
    this.rdpCredentialPinOverride = '';
    this.rdpCredentialPinOverrideTarget = '';
    // The account is not a secret and is offered back if this same endpoint asks
    // again (a refused password is answered by a fresh viewer and a fresh prompt).
    this.directWireUsernameTarget = protocol === 'rdp' ? displayTarget : '';
    hilog.info(
      DOMAIN,
      TAG,
      'direct credentials submitted protocol=%{public}s target=%{public}s passwordPresent=%{public}s pinPresent=%{public}s',
      protocol,
      displayTarget,
      String(password.length > 0),
      String(certificateSha256.length > 0),
    );
    // The answers are for the wire the operator asked for; resuming through the
    // same entry point keeps every other step (EasyTier already ran, the target
    // was already saved) exactly where it was.
    void this.connectSessionDirect(protocol === 'rdp' ? 'rdp' : 'vnc');
  }

  /**
   * Takes the credentials one dial was waiting for, exactly once.
   *
   * Both halves of the match are what the dial will really use: the wire the
   * target resolved to (not the button that was pressed) and the endpoint the
   * operator typed. A stash that does not belong to this request is dropped rather
   * than reused, so a secret answered for one target can never be spent on another.
   */
  private takePendingDirectCredentials(
    protocol: string,
    displayTarget: string,
  ): DirectWireCredentials | undefined {
    const pending = this.pendingDirectCredentials;
    this.pendingDirectCredentials = undefined;
    if (pending === undefined || pending.kind !== protocol || pending.displayTarget !== displayTarget) {
      pending?.wipePassword();
      return undefined;
    }
    return pending;
  }
  private certificateMessage(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }

  private forgetRdpCertificateCredentials(sessionId: string): void {
    this.rdpCertificateCredentials.get(sessionId)?.wipePassword();
    this.rdpCertificateCredentials.delete(sessionId);
  }

  private discardRdpCertificateDecision(): void {
    this.rdpCertificateDecisionGeneration += 1;
    this.forgetRdpCertificateCredentials(this.rdpCertificateSessionId);
    this.rdpCertificateDialogVisible = false;
    this.rdpCertificateChallenge = undefined;
    this.rdpCertificateSessionId = '';
    this.rdpCertificateReplaceConfirmation = false;
    this.rdpCertificateBusy = false;
    this.rdpCertificateError = '';
  }

  /** Page/background/privacy teardown invalidates even a redial waiting on an await. */
  private discardAllRdpCertificateSecrets(): void {
    this.rdpCredentialGeneration += 1;
    this.discardRdpCertificateDecision();
    for (const credentials of this.rdpCertificateCredentials.values()) {
      credentials.wipePassword();
    }
    this.rdpCertificateCredentials.clear();
    this.rdpCertificateRejectedSessions.clear();
    this.rdpDialCredentials?.wipePassword();
    this.rdpDialCredentials = undefined;
  }

  private certificateEventMatchesSession(challenge: RdpCertificateChallenge, sessionId: string): boolean {
    const credentials = this.rdpCertificateCredentials.get(sessionId);
    return credentials !== undefined && challenge.target === rdpCertificateTrustKey(credentials.displayTarget) &&
      challenge.pinnedSha256 === credentials.certificateSha256;
  }

  private openRdpCertificateDialog(event: NativeEvent): void {
    const sessionId = this.activeSessionId;
    const challenge = rdpCertificateChallengeFromEvent(event);
    if (this.activeSessionKind !== 'rdp' || challenge === undefined ||
      !this.certificateEventMatchesSession(challenge, sessionId)) {
      this.failConnectionAttempt('服务器证书信息无效或凭据已清除，未允许连接；请重新连接。');
      return;
    }
    if (this.rdpCertificateDialogVisible && this.rdpCertificateSessionId === sessionId) {
      return;
    }
    this.discardRdpCertificateDecision();
    this.rdpCertificateChallenge = challenge;
    this.rdpCertificateSessionId = sessionId;
    this.rdpCertificateRejectedSessions.add(sessionId);
    this.rdpCertificateDialogVisible = true;
    this.clearConnectionTimeout();
    const message = this.certificateMessage($r('app.string.rdp_certificate_waiting'));
    this.connectionUiPhase = 'failed';
    this.connectionUiMessage = message;
    this.sessionPhase = 'failed';
    this.sessionMessage = message;
    this.errorText = '';
    this.remoteInteractionReady = false;
    this.remoteSessionTabsController.markPhase(sessionId, 'failed', message);
    this.syncRemoteSessionTabs();
  }

  private cancelRdpCertificateDialog(): void {
    const sessionId = this.rdpCertificateSessionId;
    if (!this.rdpCertificateDialogVisible) {
      return;
    }
    this.discardRdpCertificateDecision();
    const message = this.certificateMessage($r('app.string.rdp_certificate_cancelled'));
    this.connectionUiPhase = 'idle';
    this.connectionUiMessage = message;
    this.sessionPhase = 'failed';
    this.sessionMessage = message;
    this.errorText = message;
    if (this.activeSessionId === sessionId) {
      void this.closeSession(message, true);
    }
  }

  private async acceptRdpCertificate(remember: boolean): Promise<void> {
    const challenge = this.rdpCertificateChallenge;
    const sessionId = this.rdpCertificateSessionId;
    const credentials = this.rdpCertificateCredentials.get(sessionId);
    if (!this.rdpCertificateDialogVisible || this.rdpCertificateBusy || challenge === undefined ||
      credentials === undefined || this.sessionTransitionBusy()) {
      return;
    }
    if (remember && challenge.reason === 'pin_mismatch' && !this.rdpCertificateReplaceConfirmation) {
      this.rdpCertificateReplaceConfirmation = true;
      return;
    }
    if (remember && !this.preferences?.rememberRdpCertificate(challenge, this.rdpCertificateReplaceConfirmation)) {
      this.rdpCertificateError = $r('app.string.rdp_certificate_save_failed');
      return;
    }
    this.rdpCertificateBusy = true;
    const generation = this.rdpCertificateDecisionGeneration;
    const passwordAvailable = credentials.passwordAvailable;
    try {
      if (remember && this.preferences !== undefined) {
        this.savedDevices = this.preferences.loadSavedPeers(undefined);
        this.refreshDirectorySnapshot();
      }
      // The rejected native wire is already stopped. Its Surface still needs the
      // normal close/ACK path, while this explicit decision owns the only secret.
      await this.closeSession(this.certificateMessage($r('app.string.rdp_certificate_waiting')), true, true);
      if (generation !== this.rdpCertificateDecisionGeneration || !this.pageVisible || !this.appForeground) {
        credentials.wipePassword();
        return;
      }
      if (this.activeSessionId === sessionId) {
        this.rdpCertificateError = $r('app.string.rdp_certificate_release_failed');
        return;
      }
      this.rdpCertificateCredentials.delete(sessionId);
      this.rdpCertificateRejectedSessions.delete(sessionId);
      this.rdpCertificateDialogVisible = false;
      this.rdpCertificateChallenge = undefined;
      this.rdpCertificateSessionId = '';
      this.peerTarget = credentials.displayTarget;
      this.directCredentialsUsername = credentials.username;
      this.directWireUsernameTarget = credentials.displayTarget;
      credentials.certificateSha256 = challenge.sha256;
      credentials.certificateAccepted = true;
      if (!passwordAvailable) {
        // An already accepted redial wiped its password. A second TLS rejection
        // can display its certificate, but must collect a fresh secret, not invent one.
        this.openDirectCredentialsDialog('rdp', credentials.displayTarget);
        this.rdpCredentialPinOverride = challenge.sha256;
        this.rdpCredentialPinOverrideTarget = credentials.displayTarget;
        return;
      }
      this.pendingDirectCredentials = credentials;
      await this.connectSessionDirect('rdp');
      credentials.wipePassword();
    } catch (error) {
      credentials.wipePassword();
      this.rdpCertificateError = String(error);
    } finally {
      this.rdpCertificateBusy = false;
      if (!this.rdpCertificateDialogVisible) {
        credentials.wipePassword();
      }
    }
  }


  private isDirectWireSession(): boolean {
    return isDirectWireKind(this.activeSessionKind);
  }

  private async switchRemoteSessionTab(sessionId: string): Promise<void> {
    if (this.sessionTransitionBusy()) {
      this.pendingSessionSwitchId = sessionId;
      return;
    }
    this.sessionSwitchInFlight = true;
    try {
      await this.performRemoteSessionTabSwitch(sessionId);
    } finally {
      this.finishRemoteSessionSwitch();
    }
  }

  private async performRemoteSessionTabSwitch(sessionId: string): Promise<void> {
    const nextTab = this.remoteSessionTabsController.get(sessionId);
    if (nextTab === undefined) {
      return;
    }
    if (this.activeSessionId === sessionId) {
      this.showPreviewModal = true;
      this.syncRemoteSessionTabs();
      return;
    }
    if (this.activeSessionId.length > 0) {
      await this.suspendActiveSessionForNewConnection();
    }
    const switched = this.remoteSessionTabsController.activate(sessionId);
    if (switched === undefined) {
      return;
    }
    this.connectionGeneration += 1;
    this.passwordDialogVisible = false;
    // A credential request that was still open belongs to the session being left:
    // the dialog is dismissed and what it had collected is dropped with it, so no
    // secret waits in memory for a wire this switch has already moved away from.
    this.directCredentialsVisible = false;
    this.directCredentialsError = '';
    this.discardDirectCredentialSecrets();
    if (this.rdpCertificateDialogVisible) {
      this.discardRdpCertificateDecision();
    }
    this.clearPasswordTimeout();
    this.authErrorMessage = '';
    this.code2faDraft = '';
    this.trustThisDevice = false;
    this.activeSessionId = nextTab.sessionId;
    this.activeCoreSessionId = nextTab.coreSessionId;
    this.activeSessionKind = nextTab.kind;
    this.activeSessionShareTarget = nextTab.target;
    this.activeSessionShareTargetKind = nextTab.shareTargetKind;
    this.activeSessionRustdeskIdOnly = nextTab.rustdeskIdOnly;
    this.activeSessionServerConfig = this.copyServerConfig(nextTab.serverConfig);
    this.activeSessionForceRelay = nextTab.forceRelay;
    this.peerTarget = nextTab.target;
    this.connectPageMode = this.connectPageModeForKind(nextTab.kind);
    this.sessionPhase = nextTab.phase;
    this.sessionMessage = nextTab.message.length > 0 ? nextTab.message : nextTab.phase;
    this.connectionSummary = nextTab.connectionSummary.length > 0
      ? nextTab.connectionSummary
      : `${nextTab.target} · ${nextTab.phase}`;
    this.connectionUiTarget = nextTab.target;
    this.connectionUiPhase = nextTab.connected ? 'connected' : 'connecting';
    this.connectionUiMessage = nextTab.connected ? '已切换到此设备' : '会话仍在连接';
    this.activeSessionDefaults = this.copySessionDefaults(nextTab.sessionDefaults);
    this.clipboardSyncEnabled = this.activeSessionDefaults.clipboardEnabled;
    this.performanceTuningApplied = false;
    this.remoteInteractionReady = false;
    this.clipboardFileRootSessionId = '';
    this.resetPreviewState();
    if (nextTab.uiStateCaptured) {
      this.sessionDisplayController.restoreRefreshRate(nextTab.refreshRate);
      this.selectedRefreshRate = this.sessionDisplayController.getRefreshRate();
      this.touchMode = nextTab.touchMode;
      this.relativeMouseMode = nextTab.relativeMouseMode;
      this.inputEnabled = nextTab.inputEnabled;
      this.isMiniBarExpanded = nextTab.toolbarExpanded;
      this.previewUserScale = nextTab.viewScale;
      this.previewUserOffsetX = nextTab.viewOffsetX;
      this.previewUserOffsetY = nextTab.viewOffsetY;
      this.previewUserRotation = nextTab.viewRotation;
      this.viewportModel.setViewTransform(
        nextTab.viewScale,
        nextTab.viewOffsetX,
        nextTab.viewOffsetY,
        nextTab.viewRotation,
      );
    } else {
      this.sessionDisplayController.restoreRefreshRate(this.selectedRefreshRate);
    }
    // The generation this tab's session last reported, so input after a switch
    // starts from the boundary the native side gave instead of none; a stale
    // value is refused with the current one, which the next poll adopts.
    this.activeInputGeneration = nextTab.inputGeneration;
    this.showPreviewModal = true;
    this.syncClipboardController();
    this.syncInputInterceptor();
    this.syncRemoteSessionTabs();
    if (nextTab.peerInfo !== undefined) {
      this.handleSessionEvent(nextTab.peerInfo);
      if (nextTab.uiStateCaptured) {
        this.viewportModel.selectDisplay(nextTab.displayIndex);
        this.currentDisplayIndex = this.viewportModel.getCurrentDisplayIndex();
      }
    }
    await this.restoreRemoteCursorState(nextTab.sessionId);
    const pendingEvents = this.remoteSessionTabsController.takePendingEvents(sessionId);
    for (const event of pendingEvents) {
      this.handleSessionEvent(event);
    }
    if (nextTab.kind === 'remote_control' || nextTab.kind === 'rdp') {
      this.refreshRemoteAudioState();
      if (nextTab.audioPreferenceCaptured) {
        this.nativeSessionBridge.setRemoteAudioMuted(nextTab.sessionId, nextTab.audioMuted);
        this.refreshRemoteAudioState();
      }
      this.startRemoteAudioPolling();
    } else {
      this.closeRemoteAudio();
    }
    this.startPolling();
    this.syncRemoteSessionTabs();
  }

  private openNewRemoteSession(): void {
    void this.performOpenNewRemoteSession();
  }

  private async performOpenNewRemoteSession(): Promise<void> {
    if (this.sessionTransitionBusy()) {
      this.pendingSessionSwitchId = NEW_REMOTE_SESSION_SWITCH_TARGET;
      return;
    }
    this.sessionSwitchInFlight = true;
    this.discardRdpCertificateDecision();
    this.discardDirectCredentialSecrets();
    this.directCredentialsVisible = false;
    try {
      await this.suspendActiveSessionForNewConnection();
      await this.applySessionFullscreen(false, true);
      this.clearConnectionTimeout();
      this.connectionUiPhase = 'idle';
      this.connectionUiTarget = '';
      this.connectionUiMessage = '';
      this.connectionAttemptKind = 'primary';
      this.errorText = '';
      this.peerTarget = '';
      this.sessionReturnTabIndex = 0;
      this.currentTabIndex = 0;
      if (!this.isWideMainLayout()) {
        this.hdsTabsController.changeIndex(0);
      }
    } finally {
      this.finishRemoteSessionSwitch();
    }
  }

  private resumeRemoteSessionFromHome(): void {
    const sessionId = this.remoteSessionTabsController.activeId();
    if (sessionId.length > 0) {
      void this.switchRemoteSessionTab(sessionId);
    }
  }

  private finishRemoteSessionSwitch(): void {
    this.sessionSwitchInFlight = false;
    this.materializePendingTransitionClose();
    this.drainPendingSessionTransitions();
  }

  private sessionTransitionBusy(): boolean {
    return this.sessionConnectInFlight || this.sessionSwitchInFlight || this.sessionCloseInFlight;
  }

  private queueClosedSession(sessionId: string): void {
    if (sessionId.length > 0 && !this.pendingClosedSessionIds.includes(sessionId)) {
      this.pendingClosedSessionIds.push(sessionId);
    }
  }

  private materializePendingTransitionClose(): void {
    if (!this.pendingTransitionClose) {
      return;
    }
    this.pendingTransitionClose = false;
    this.queueClosedSession(this.activeSessionId);
  }

  private drainPendingSessionTransitions(): void {
    if (this.sessionTransitionBusy()) {
      return;
    }
    const closedSessionId = this.pendingClosedSessionIds.shift();
    if (closedSessionId !== undefined) {
      void this.closeRemoteSessionTab(closedSessionId).finally((): void => {
        this.drainPendingSessionTransitions();
      });
      return;
    }
    const retryTarget = this.pendingConnectionRetry;
    this.pendingConnectionRetry = '';
    if (retryTarget.length > 0) {
      // The failed attempt has finished releasing its wire, so the retry dials a
      // fresh viewer and asks for the credential again.
      void this.preparePeerLaunch(retryTarget, this.lastConnectionKind, this.lastConnectionRustdeskIdOnly);
      return;
    }
    const pendingSessionId = this.pendingSessionSwitchId;
    this.pendingSessionSwitchId = '';
    if (pendingSessionId === NEW_REMOTE_SESSION_SWITCH_TARGET) {
      void this.performOpenNewRemoteSession();
    } else if (pendingSessionId.length > 0 && pendingSessionId !== this.activeSessionId) {
      void this.switchRemoteSessionTab(pendingSessionId);
    }
  }

  private async closeRemoteSessionTab(sessionId: string): Promise<void> {
    this.forgetRdpCertificateCredentials(sessionId);
    if (this.rdpCertificateSessionId === sessionId) {
      this.discardRdpCertificateDecision();
    }
    if (this.sessionTransitionBusy()) {
      this.queueClosedSession(sessionId);
      return;
    }
    if (sessionId === this.activeSessionId) {
      await this.closeSession('已手动断开连接');
      return;
    }
    this.sessionCloseInFlight = true;
    try {
      await this.clipboardController?.cleanupIncomingRootForClosedSession(sessionId);
      const tab = this.remoteSessionTabsController.get(sessionId);
      const released = await this.releaseNativeSession(sessionId, tab === undefined ? '' : tab.lifecycleEpoch);
      if (!released) {
        // A destination this session still holds keeps its record and its tab: it
        // is not presented anywhere, so there is nothing to destroy, and removing
        // the tab would only hide a session the native side still owns.
        hilog.warn(DOMAIN, TAG, 'closeRemoteSessionTab kept session=%{public}s: a destination is still held', sessionId);
        return;
      }
      this.remoteSessionTabsController.remove(sessionId);
      this.rdpCertificateRejectedSessions.delete(sessionId);
      this.syncRemoteSessionTabs();
    } finally {
      this.sessionCloseInFlight = false;
      this.drainPendingSessionTransitions();
    }
  }

  private async closeSession(reason?: string, preserveConnectionFailure: boolean = false,
    preserveRdpCertificateDecision: boolean = false): Promise<void> {
    if (!preserveRdpCertificateDecision) {
      this.forgetRdpCertificateCredentials(this.activeSessionId);
      if (this.rdpCertificateSessionId === this.activeSessionId) {
        this.discardRdpCertificateDecision();
      }
    }
    if (this.sessionConnectInFlight || this.sessionSwitchInFlight) {
      if (this.activeSessionId.length > 0) {
        this.queueClosedSession(this.activeSessionId);
      } else {
        this.pendingTransitionClose = true;
      }
      return;
    }
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
      const holdsOwedBeforeClose = this.activeInputHoldsOwed;
      this.rejectPendingInsecureConnection();
      hilog.info(DOMAIN, TAG, 'closeSession sessionId=%{public}s reason=%{public}s', sessionId, reason ?? '');
      this.hideSystemIme(false);
      this.releaseSoftKeyboardKeys();
      if (this.relativeMouseMode && sessionId) {
        this.syncRelativeMouseMode(false);
      }
      this.remoteInteractionReady = false;
      this.stopInputInterceptor();
      await this.clipboardController?.stopAndDrainRemoteWrite();
      await this.clipboardController?.cleanupIncomingRootForClosedSession(sessionId);
      if (this.remoteSessionTabsController.count() > 1) {
        this.clipboardController?.stop();
      } else {
        this.clipboardController?.reset();
      }
      this.clipboardFileRootSessionId = '';
      this.clipboardPeerUpdateSessions.delete(sessionId);
      this.clearPreviewKeyboardBlurTimer();
      this.previewKeyboardCaptureFocused = false;
      this.setSessionKeyboardEntered(false);
      await this.applySessionFullscreen(false, true);
      this.unregisterFoldHoverListeners();
      this.passwordDialogVisible = false;
      this.directCredentialsVisible = false;
      this.directCredentialsError = '';
      const shouldRestoreMainTab = reason !== '正在切换会话';
      this.clearActiveSessionHandoffState(preserveRdpCertificateDecision);
      this.clearPasswordTimeout();
      this.inputController?.releasePressedButtons();
      // The native media owner still holds this Surface. Request the close and
      // wait for its join receipt before hiding the pane or unbinding, then
      // acknowledge the epoch the native side issued.
      let released = true;
      if (sessionId.length > 0) {
        released = await this.releaseNativeSession(sessionId, this.activeSessionLifecycleEpoch);
      }
      if (!released) {
        // A producer still owes a join, so the Surface may not be destroyed. The
        // component is kept and the destination given back until the native side
        // reports nothing holds it; the close only completes on a real verdict.
        const releasedLater = await this.awaitSurfaceRelease(sessionId);
        if (releasedLater) {
          released = await this.releaseNativeSession(sessionId, this.activeSessionLifecycleEpoch);
        }
      }
      if (!released) {
        hilog.warn(DOMAIN, TAG, 'closeSession kept session=%{public}s: a destination is still held', sessionId);
        this.sessionPhase = preserveConnectionFailure ? this.sessionPhase : 'connected';
        this.sessionMessage = '远端仍在释放画面连接，暂时保留会话';
        this.connectionSummary = `${this.activeSessionShareTarget} · 正在关闭`;
        return;
      }
      // Every destination was really released, which is what authorizes this
      // Surface to be destroyed. The acknowledged close also retired the native
      // session, so there is no binding left to give back: asking it would only
      // be refused as an unknown session.
      this.previewSurfaceDestroyAuthorized = true;
      this.showPreviewModal = false;
      this.previewSurfaceId = '';
      this.closeRemoteAudio();
      this.resetPreviewState();
      this.connectionSummary = preserveConnectionFailure
        ? `连接失败 · ${this.connectionUiTarget || this.peerTarget}`
        : '未连接';
      if (reason) {
        this.sessionMessage = reason;
      }
      if (holdsOwedBeforeClose.length > 0 && holdsOwedBeforeClose !== '0') {
        // The connection attempted releases the peer refused: the session is not
        // reported as cleanly stopped while that count is outstanding.
        this.sessionMessage = `${this.sessionMessage}；仍有 ${holdsOwedBeforeClose} 个按键释放未获远端确认`;
      }
      if (!sessionId) {
        const fallbackSessionId = this.remoteSessionTabsController.activeId();
        if (fallbackSessionId.length > 0) {
          await this.switchRemoteSessionTab(fallbackSessionId);
          return;
        }
        this.stopPolling();
        this.sessionPhase = preserveConnectionFailure ? 'failed' : 'idle';
        this.activeSessionKind = 'remote_control';
        this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
        this.applySessionDefaultsToIdleState(this.decoderCapabilities);
        this.refreshDirectorySnapshot();
        if (shouldRestoreMainTab) {
          this.restoreSessionReturnTab();
        }
        return;
      }
      this.activeSessionId = '';
      this.activeCoreSessionId = '';
      this.activeSessionLifecycleEpoch = '';
      const nextSessionId = this.remoteSessionTabsController.remove(sessionId);
      if (!preserveRdpCertificateDecision) {
        this.rdpCertificateRejectedSessions.delete(sessionId);
      }
      this.syncRemoteSessionTabs();
      this.publishDataTransferChanged();
      if (preserveRdpCertificateDecision) {
        this.sessionPhase = 'failed';
        this.refreshDirectorySnapshot();
      } else if (nextSessionId.length > 0) {
        await this.switchRemoteSessionTab(nextSessionId);
      } else {
        this.stopPolling();
        this.sessionPhase = preserveConnectionFailure ? 'failed' : 'idle';
        this.activeSessionKind = 'remote_control';
        this.activeSessionDefaults = this.copySessionDefaults(this.sessionDefaults);
        this.applySessionDefaultsToIdleState(this.decoderCapabilities);
        this.refreshDirectorySnapshot();
        if (shouldRestoreMainTab) {
          this.restoreSessionReturnTab();
        }
      }
    } finally {
      this.sessionCloseInFlight = false;
      this.drainPendingSessionTransitions();
    }
  }

  /**
   * Closes one native session and acknowledges its lifecycle epoch.
   *
   * `sessionClose` only resolves with the native join receipt, so the epoch is
   * acknowledged after it: a UI-close event alone is not evidence that the
   * decoder released the surface. Returns whether every destination was really
   * released and the epoch acknowledged; a `false` means the Surface may not be
   * destroyed yet.
   */
  private async releaseNativeSession(sessionId: string, lifecycleEpoch: string): Promise<boolean> {
    const epoch = lifecycleEpoch;
    let release: ActionResponse;
    try {
      release = await this.nativeSessionBridge.closeSession(sessionId);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'native session close failed: %{public}s', String(error));
      return false;
    }
    this.updateSessionState(release);
    if (!release.ok) {
      hilog.warn(DOMAIN, TAG, 'native session close refused action=%{public}s message=%{public}s',
        release.action, release.message ?? '');
      return false;
    }
    // The native close receipt always states `released`; an absent verdict is a
    // protocol failure, never a release. Only an explicit true permits destroying
    // the Surface and acknowledging the epoch.
    const released = release.released === true;
    if (!released) {
      hilog.warn(DOMAIN, TAG,
        'native session close did not release every destination session=%{public}s settle=%{public}s',
        sessionId, release.settle ?? '');
      return false;
    }
    if (epoch.length === 0) {
      hilog.warn(DOMAIN, TAG, 'session close had no lifecycle epoch to acknowledge');
      return false;
    }
    try {
      const ack = this.nativeSessionBridge.acknowledgeClose(sessionId, epoch);
      if (!ack.ok) {
        hilog.warn(DOMAIN, TAG, 'session close ACK refused action=%{public}s message=%{public}s',
          ack.action, ack.message ?? '');
        return false;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'session close ACK failed: %{public}s', String(error));
      return false;
    }
    return true;
  }

  /**
   * Waits, bounded, for a destination the producer still owed to be released.
   *
   * The Surface may not be destroyed before that, so this only gives the
   * destination back on each attempt and reports whether the native side says
   * nothing holds it any more. It never claims a release the native side did not
   * report.
   */
  private async awaitSurfaceRelease(sessionId: string): Promise<boolean> {
    for (let attempt = 0; attempt < SURFACE_RELEASE_WAIT_ATTEMPTS; attempt += 1) {
      await new Promise<void>((resolve) => setTimeout(() => resolve(), SURFACE_RELEASE_WAIT_INTERVAL_MS));
      if (sessionId !== this.activeSessionId) {
        return false;
      }
      if (this.clearSurfaceBinding()) {
        return true;
      }
    }
    return false;
  }

  private handleRemoteDisconnect(message: string): void {
    if (this.rdpCertificateRejectedSessions.has(this.activeSessionId)) {
      return;
    }
    if (this.sessionCloseInFlight) {
      return;
    }
    hilog.warn(DOMAIN, TAG, 'handleRemoteDisconnect sessionId=%{public}s message=%{public}s', this.activeSessionId, message);
    this.failConnectionAttempt(message);
  }

  /**
   * Records a session the native side closed outside this bridge.
   *
   * A privacy revocation closes a VNC/RDP wire underneath the UI: the poll
   * carries `closed_externally` and a `close` event, and the tab must not be left
   * looking connected while its own close verdict is still pending.
   */
  private noteExternallyClosedSession(sessionId: string, settle: string): void {
    this.discardAllRdpCertificateSecrets();
    this.discardDirectCredentialSecrets();
    this.directCredentialsVisible = false;
    hilog.warn(DOMAIN, TAG, 'session closed externally session=%{public}s settle=%{public}s',
      sessionId, settle.length > 0 ? settle : 'unreported');
    this.remoteSessionTabsController.markPhase(sessionId, 'closed', '连接已由外部关闭');
  }

  private resetPreviewState(): void {
    // The preview's measured viewport belongs to the ArkUI container, not to
    // any remote session. Preserve it across A -> B tab switches because an
    // unchanged layout does not emit another onAreaChange callback.
    this.viewportModel.resetSessionGeometry();
    this.inputController?.reset();
    this.keyboardEnteredSessionId = '';
    this.frameStatus = 'Surface not ready';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.previewUserScale = 1;
    this.previewUserOffsetX = 0;
    this.previewUserOffsetY = 0;
    this.previewUserRotation = 0;
    this.softKeyboardVisible = false;
    this.systemImeActive = false;
    this.systemImeText = this.imeInputController.reset();
    this.softKeyboardDockTop = false;
    this.softKeyboardX = 0;
    this.softKeyboardY = 12;
    this.softKeyboardDragStartX = 0;
    this.softKeyboardDragStartY = 12;
    this.clearSoftKeyboardKeyState();
    this.androidNavigationDragStartX = 0;
    this.androidNavigationDragStartY = 0;
    this.miniBarDragStartX = 0;
    this.miniBarDragStartY = 0;
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
    this.currentDisplayIndex = 0;
    // The generation belongs to one session's boundary: it is cleared with the
    // session state and only ever refilled from a value the native side reported.
    this.activeInputGeneration = '';
    // The owed-hold count belongs to that same boundary; empty means unknown.
    this.activeInputHoldsOwed = '';
    this.previewSurfaceVisible = false;
    // This is a process-local Surface epoch. Never reset it: A→B→A must not
    // accept a delayed callback from A's previous XComponent generation.
    this.previewSurfaceSetupInFlight = false;
    this.previewSurfaceSetupGeneration = -1;
    this.pendingPreviewPeerInfo = undefined;
    this.releasePreviewFramePixelMap();
    this.qualityTelemetry = emptyQualityTelemetry();
    this.codecPreferenceApplied = false;
    this.touchMode = this.activeSessionDefaults.touchMode;
    this.relativeMouseMode = !this.touchMode && !this.isDirectWireSession() && this.activeSessionDefaults.relativeMouseMode;
    this.inputEnabled = this.activeSessionDefaults.inputEnabled;
    this.rightClickGesture = this.activeSessionDefaults.rightClickGesture;
    this.resetRemoteCursorVisualState();
    this.cursorModel.reset();
    this.remoteCursorOptionApplied = false;
    this.remoteCursorOptionLastAppliedAt = 0;
    this.remoteCursorOptionFirstAppliedAt = 0;
    this.remoteCursorEnableAttempts = 0;
    this.relativeModeActivatedAt = 0;
    this.remoteCursorEventLogCounter = 0;
    this.overlayState.close();
    this.activeOverlayPanel = 'home';
    this.selectedRefreshRate = this.defaultRefreshRate(this.activeSessionDefaults);
    this.remoteAudioState = this.unavailableRemoteAudioState();
    this.remoteAudioDefaultApplied = false;
    this.directAudioCapability = '';
    this.clearRdpFollowResize();
    this.isMiniBarExpanded = this.activeSessionDefaults.toolbarExpanded;
    this.initialDisplayCommandIssued = false;
    this.pendingDisplayIndex = -1;
    this.pendingResolutionDisplay = -1;
    this.pendingResolutionWidth = 0;
    this.pendingResolutionHeight = 0;
  }

  private openOverlayPanel(panel: SessionOverlayPanel): void {
    if (!this.overlayState.open(panel)) {
      return;
    }
    this.hideSystemIme(false);
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

  private unavailableRemoteAudioState(): RemoteAudioState {
    return {
      available: false,
      muted: false,
      rendererActive: false,
      errorText: '',
    };
  }

  private isInteractiveSessionActive(): boolean {
    return (this.activeSessionKind === 'remote_control' || this.isDirectWireSession())
      && this.activeSessionId.length > 0;
  }

  private isRemoteControlSessionActive(): boolean {
    return this.activeSessionKind === 'remote_control' && this.activeSessionId.length > 0;
  }

  /**
   * Whether the session's clipboard policy admits text at all: a selected session,
   * the operator's switch, a wire that carries clipboard text, and the session's own
   * `disable-clipboard` option. It says nothing about whether the app is in front,
   * which is the transient half checked by isClipboardTextSyncAllowed().
   */
  private isClipboardTextAdmitted(): boolean {
    return this.activeSessionId.length > 0 && clipboardTextSyncAllowed(
      this.clipboardSyncEnabled,
      this.activeSessionKind,
      this.nativeSessionBridge.getToggleOption(this.activeSessionId, 'disable-clipboard'),
    );
  }

  /**
   * Whether clipboard text may be synchronized with the active session right now.
   *
   * Policy plus the app actually being in front: the native admission deliberately
   * does not look at foreground, and a backgrounded app must neither write the
   * peer's text into the system pasteboard nor forward a local read. The option is
   * read per use because it can change mid-session.
   */
  private isClipboardTextSyncAllowed(): boolean {
    return this.appForeground && this.pageVisible && this.isClipboardTextAdmitted();
  }

  private applyRemoteAudioPollingForKind(kind: PrimarySessionKind): void {
    if (kind === 'remote_control' || kind === 'rdp') {
      this.refreshRemoteAudioState();
      this.startRemoteAudioPolling();
      return;
    }
    this.closeRemoteAudio();
  }

  private remoteTextInputAvailable(): boolean {
    return !this.isPcDevice()
      && this.isInteractiveSessionActive()
      && this.remoteKeyboardPermissionAllowed
      && this.showPreviewModal
      && !this.showTransferWorkspace;
  }

  private systemImeAvailable(): boolean {
    return this.remoteTextInputAvailable();
  }

  private softKeyboardAvailable(): boolean {
    return this.remoteTextInputAvailable() && !this.isFoldHoverMode;
  }

  private toggleSystemIme(): void {
    const available = this.systemImeAvailable();
    this.logRelativeDebug(
      'system_ime_toggle',
      `available=${available} active=${this.systemImeActive}`,
    );
    if (!available || this.systemImeActive) {
      this.hideSystemIme();
      return;
    }
    this.hideSoftKeyboard();
    this.systemImeText = this.imeInputController.reset();
    this.systemImeActive = true;
    setTimeout(() => this.requestSystemImeFocus(), 40);
  }

  private requestSystemImeFocus(): void {
    if (!this.systemImeActive || !this.systemImeAvailable()) {
      return;
    }
    this.clearSystemImeBlurTimer();
    try {
      this.getUIContext().getFocusController().requestFocus(SYSTEM_IME_INPUT_FOCUS_ID);
      this.systemImeTextController.caretPosition(this.systemImeText.length);
    } catch (error) {
      this.logRelativeDebug('system_ime_focus', `request failed=${String(error)}`);
      return;
    }
    setTimeout(() => {
      if (!this.systemImeActive) {
        return;
      }
      try {
        inputMethod.getController().showTextInput()
          .then((): void => this.logRelativeDebug('system_ime_focus', 'shown'))
          .catch((error: BusinessError): void => {
            this.logRelativeDebug('system_ime_focus', `show failed=${error.code}:${error.message}`);
          });
      } catch (error) {
        this.logRelativeDebug('system_ime_focus', `show failed=${String(error)}`);
      }
    }, 80);
  }

  private hideSystemIme(restorePreviewFocus: boolean = true): void {
    this.clearSystemImeBlurTimer();
    const wasActive = this.systemImeActive;
    this.systemImeActive = false;
    this.systemImeText = this.imeInputController.reset();
    try {
      this.systemImeTextController.stopEditing();
    } catch (error) {
      this.logRelativeDebug('system_ime_focus', `stop failed=${String(error)}`);
    }
    if (wasActive) {
      try {
        inputMethod.getController().hideTextInput()
          .catch((error: BusinessError): void => {
            this.logRelativeDebug('system_ime_focus', `hide failed=${error.code}:${error.message}`);
          });
      } catch (error) {
        this.logRelativeDebug('system_ime_focus', `hide failed=${String(error)}`);
      }
    }
    if (restorePreviewFocus && this.showPreviewModal) {
      setTimeout(() => this.requestPreviewInputFocus(), 80);
    }
  }

  private scheduleSystemImeDeactivate(): void {
    if (!this.systemImeActive) {
      return;
    }
    this.clearSystemImeBlurTimer();
    this.systemImeBlurTimer = setTimeout(() => {
      this.systemImeBlurTimer = -1;
      if (this.systemImeActive) {
        this.hideSystemIme(true);
      }
    }, 80) as number;
  }

  private clearSystemImeBlurTimer(): void {
    if (this.systemImeBlurTimer >= 0) {
      clearTimeout(this.systemImeBlurTimer);
      this.systemImeBlurTimer = -1;
    }
  }

  private handleSystemImeChange(value: string, previewText?: PreviewText, options?: TextChangeOptions): void {
    const oldPreviewText: PreviewText | undefined = options === undefined ? undefined : options.oldPreviewText;
    const delta: RustDeskImeInputDelta = this.imeInputController.applyTextChange(
      value,
      previewText?.offset ?? -1,
      previewText?.value ?? '',
      options?.oldContent,
      oldPreviewText?.offset ?? -1,
      oldPreviewText?.value ?? '',
    );
    this.systemImeText = delta.localText;
    if (!this.systemImeActive || !this.isInteractiveSessionActive()) {
      return;
    }
    for (let index = 0; index < delta.backspaceCount; index += 1) {
      this.sendSoftKeyboardKey('VK_BACK', true, false, false, false, false);
    }
    if (delta.insertedText.length > 0) {
      this.sendSystemImeText(delta.insertedText);
    }
    if (previewText === undefined || previewText.value.length === 0) {
      this.clearSystemImeCaretTimer();
      this.systemImeCaretTimer = setTimeout(() => {
        this.systemImeCaretTimer = -1;
        if (this.systemImeActive) {
          this.systemImeTextController.caretPosition(this.systemImeText.length);
        }
      }, 0) as number;
    }
  }

  private clearSystemImeCaretTimer(): void {
    if (this.systemImeCaretTimer < 0) {
      return;
    }
    clearTimeout(this.systemImeCaretTimer);
    this.systemImeCaretTimer = -1;
  }

  private sendSystemImeText(value: string): void {
    try {
      const response = this.nativeSessionBridge.inputString(
        this.activeSessionId,
        value,
        this.currentInputGeneration(),
      );
      this.logRelativeDebug('system_ime_text', `ok=${response.ok} length=${value.length}`);
      if (!response.ok) {
        // A refusal names the generation the session is at now, so stale input
        // state for a boundary that has gone is retired rather than resent.
        this.adoptInputGeneration(response);
        this.errorText = response.message ?? '输入法文本发送失败';
      }
    } catch (error) {
      this.errorText = `输入法文本发送失败: ${String(error)}`;
      this.logRelativeDebug('system_ime_text', `failed=${String(error)}`);
    }
  }

  private handleSystemImeSubmit(event: SubmitEvent): void {
    event.keepEditableState();
    if (!this.systemImeActive) {
      return;
    }
    this.sendSoftKeyboardKey('VK_RETURN', true, false, false, false, false);
    setTimeout(() => this.requestSystemImeFocus(), 0);
  }

  private toggleSoftKeyboard(): void {
    const available = this.softKeyboardAvailable();
    this.logRelativeDebug(
      'soft_keyboard_toggle',
      `available=${available} visible=${this.softKeyboardVisible}`,
    );
    if (!available) {
      this.hideSoftKeyboard();
      return;
    }
    if (this.softKeyboardVisible) {
      this.hideSoftKeyboard();
      setTimeout(() => this.requestPreviewInputFocus(), 80);
      return;
    }
    this.hideSystemIme(false);
    this.resetSoftKeyboardPosition();
    this.softKeyboardVisible = true;
    this.logRelativeDebug('soft_keyboard_toggle', 'visible=true');
  }

  private moveSoftKeyboardToOtherEdge(): void {
    this.softKeyboardDockTop = !this.softKeyboardDockTop;
    this.resetSoftKeyboardPosition();
  }

  private clampSoftKeyboardX(value: number): number {
    const maxX = Math.max(0, this.previewViewWidth - this.softKeyboardWidth());
    return Math.max(0, Math.min(value, maxX));
  }

  private clampSoftKeyboardY(value: number): number {
    const maxY = Math.max(0, this.previewViewHeight - REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT);
    return Math.max(0, Math.min(value, maxY));
  }

  private resetSoftKeyboardPosition(): void {
    this.softKeyboardX = this.clampSoftKeyboardX(
      Math.max(0, (this.previewViewWidth - this.softKeyboardWidth()) / 2),
    );
    this.softKeyboardY = this.clampSoftKeyboardY(this.softKeyboardOffsetY());
    this.softKeyboardDragStartX = this.softKeyboardX;
    this.softKeyboardDragStartY = this.softKeyboardY;
  }

  private startSoftKeyboardDrag(): void {
    this.softKeyboardDragStartX = this.softKeyboardX;
    this.softKeyboardDragStartY = this.softKeyboardY;
  }

  private updateSoftKeyboardDrag(offsetX: number, offsetY: number): void {
    this.softKeyboardX = this.clampSoftKeyboardX(this.softKeyboardDragStartX + offsetX);
    this.softKeyboardY = this.clampSoftKeyboardY(this.softKeyboardDragStartY + offsetY);
  }

  private finishSoftKeyboardDrag(): void {
    this.softKeyboardX = this.clampSoftKeyboardX(this.softKeyboardX);
    this.softKeyboardY = this.clampSoftKeyboardY(this.softKeyboardY);
    const maxY = Math.max(0, this.previewViewHeight - REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT);
    this.softKeyboardDockTop = this.softKeyboardY <= maxY / 2;
    this.softKeyboardDragStartX = this.softKeyboardX;
    this.softKeyboardDragStartY = this.softKeyboardY;
  }

  private reclampSoftKeyboardPosition(): void {
    if (!this.softKeyboardVisible) {
      return;
    }
    this.finishSoftKeyboardDrag();
  }

  private softKeyboardCharacter(name: string, shift: boolean): string {
    if (name === 'VK_SPACE') {
      return ' ';
    }
    if (name.length === 1) {
      return name;
    }
    if (name.length !== 4 || name.indexOf('VK_') !== 0) {
      return '';
    }
    const key = name.substring(3);
    if (key.length !== 1) {
      return '';
    }
    const code = key.charCodeAt(0);
    if (code >= 65 && code <= 90) {
      return shift ? key : key.toLowerCase();
    }
    if (code >= 48 && code <= 57) {
      if (!shift) {
        return key;
      }
      const shiftedDigits: string = ')!@#$%^&*('.charAt(code - 48);
      return shiftedDigits;
    }
    return '';
  }

  private softKeyboardUsbHid(name: string): number | undefined {
    if (name === 'VK_SPACE') {
      return 0x2C;
    }
    if (name === 'VK_TAB') {
      return 0x2B;
    }
    if (name === 'VK_RETURN') {
      return 0x28;
    }
    if (name === 'VK_BACK') {
      return 0x2A;
    }
    if (name === 'VK_ESCAPE') {
      return 0x29;
    }
    if (name === 'VK_DELETE') {
      return 0x4C;
    }
    if (name === ',' || name === '<') {
      return 0x36;
    }
    if (name === '.' || name === '>') {
      return 0x37;
    }
    if (name === '/' || name === '?') {
      return 0x38;
    }
    if (name === ';' || name === ':') {
      return 0x33;
    }
    if (name === '\'' || name === '"') {
      return 0x34;
    }
    if (name === '[' || name === '{') {
      return 0x2F;
    }
    if (name === ']' || name === '}') {
      return 0x30;
    }
    if (name === '\\' || name === '|') {
      return 0x31;
    }
    if (name === '-' || name === '_') {
      return 0x2D;
    }
    if (name === '=' || name === '+') {
      return 0x2E;
    }
    if (name === '`' || name === '~') {
      return 0x35;
    }
    if (name.length !== 4 || name.indexOf('VK_') !== 0) {
      return undefined;
    }
    const key = name.substring(3);
    if (key.length !== 1) {
      return undefined;
    }
    const code = key.charCodeAt(0);
    if (code >= 65 && code <= 90) {
      return 0x04 + code - 65;
    }
    if (code >= 49 && code <= 57) {
      return 0x1E + code - 49;
    }
    if (code === 48) {
      return 0x27;
    }
    return undefined;
  }

  private sendSoftKeyboardKey(
    name: string,
    down: boolean,
    alt: boolean,
    ctrl: boolean,
    shift: boolean,
    command: boolean,
  ): void {
    if (!this.isInteractiveSessionActive()) {
      this.clearSoftKeyboardKeyState();
      return;
    }
    const modifier = this.isSoftKeyboardModifier(name);
    if (modifier && !down && this.softKeyboardPressedKeys.indexOf(name) < 0) {
      return;
    }

    // Functional keys (Backspace, Enter, Tab, Delete, Esc, Arrows, Fn) go through sessionInputKey (ControlKey)
    if (this.isFunctionalKey(name)) {
      if (!down) {
        return;
      }
      const payload = new RustDeskKeyPayload(name, false);
      payload.press = true;
      payload.alt = alt;
      payload.ctrl = ctrl;
      payload.shift = shift;
      payload.command = command;
      this.sendKeyPayloadObject(payload);
      return;
    }

    // Optimized direct text input for Android remote peers:
    if (this.isPeerAndroid() && down && !modifier) {
      const character = this.softKeyboardCharacter(name, shift);
      if (character.length > 0 && !ctrl && !alt && !command) {
        try {
          this.nativeSessionBridge.inputString(
            this.activeSessionId,
            character,
            this.currentInputGeneration(),
          );
          return;
        } catch (_) {
        }
      }
      if (name === 'VK_SPACE') {
        try {
          this.nativeSessionBridge.inputString(
            this.activeSessionId,
            ' ',
            this.currentInputGeneration(),
          );
          return;
        } catch (_) {
        }
      }
    }

    const usbHid = this.softKeyboardUsbHid(name);
    let rawRouteAttempted = false;
    // Core raw keys cannot serve direct sessions. Their legacy bridge remains
    // responsible for admitting or rejecting its supported key vocabulary.
    if (!modifier && usbHid !== undefined && !this.isDirectWireSession()) {
      const character = down ? this.softKeyboardCharacter(name, shift) : '';
      let lockModes = 0;
      if (shift) {
        lockModes |= (1 << 0);
      }
      if (ctrl) {
        lockModes |= (1 << 1);
      }
      if (alt) {
        lockModes |= (1 << 2);
      }
      const payload = new RustDeskFlutterKeyPayload(character, usbHid, lockModes, down);
      rawRouteAttempted = true;
      if (this.sendFlutterKeyPayloadObject(payload)) {
        return;
      }
    }
    if (rawRouteAttempted) {
      // The raw key route was chosen for this event and the native side refused it,
      // so its generation is what refused it. Re-sending the same event through the
      // legacy route would launder it into the newly adopted generation, so it is
      // dropped; only an event whose raw route was never chosen falls through.
      return;
    }
    if (!modifier && !down) {
      return;
    }
    const payload = new RustDeskKeyPayload(name, modifier ? down : false);
    payload.press = !modifier;
    payload.alt = alt;
    payload.ctrl = ctrl;
    payload.shift = shift;
    payload.command = command;
    if (this.sendKeyPayloadObject(payload) && modifier) {
      this.rememberSoftKeyboardKey(name, down, alt, ctrl, shift, command);
    }
  }

  private isSoftKeyboardModifier(name: string): boolean {
    return name === 'VK_CONTROL' || name === 'VK_MENU' || name === 'VK_SHIFT' || name === 'Meta';
  }

  private isFunctionalKey(name: string): boolean {
    return name === 'VK_BACK'
      || name === 'VK_DELETE'
      || name === 'VK_RETURN'
      || name === 'VK_TAB'
      || name === 'VK_ESCAPE'
      || name === 'VK_HOME'
      || name === 'VK_END'
      || name === 'VK_PRIOR'
      || name === 'VK_NEXT'
      || name === 'VK_LEFT'
      || name === 'VK_RIGHT'
      || name === 'VK_UP'
      || name === 'VK_DOWN'
      || name.indexOf('VK_F') === 0;
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
    if (!this.isInteractiveSessionActive()) {
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
    return Math.max(280, Math.min(this.previewViewWidth - 16, 560));
  }

  private softKeyboardOffsetY(): number {
    if (this.softKeyboardDockTop || this.previewViewHeight <= 0) {
      return 12;
    }
    return Math.max(12, this.previewViewHeight - REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT - 12);
  }

  private sendClipboardText(content: string): boolean {
    if (!this.remoteInteractionReady || !this.isClipboardTextSyncAllowed()) {
      return false;
    }
    const response = this.nativeSessionBridge.sendClipboard(this.activeSessionId, content);
    if (!response.ok) {
      this.logRelativeDebug('clipboard_local', `native failed=${String(response.message ?? '')}`);
      return false;
    }
    if (response.queued === true) {
      // A direct wire's receipt is the queue, not the peer: the write verdict
      // arrives later as `clipboard_write_result`.
      this.logRelativeDebug('clipboard_local', `queued length=${content.length}`);
    }
    return true;
  }

  private sendClipboardImage(content: Uint8Array): boolean {
    if (!this.remoteInteractionReady || !this.isRemoteControlSessionActive()) {
      return false;
    }
    const response = this.nativeSessionBridge.sendClipboardImage(this.activeSessionId, content);
    if (!response.ok) {
      this.logRelativeDebug('clipboard_local', `native image failed=${String(response.message ?? '')}`);
    }
    return response.ok;
  }

  private sendClipboardFiles(paths: Array<string>): boolean {
    if (!this.remoteInteractionReady || !this.isRemoteControlSessionActive()) {
      return false;
    }
    const response = this.nativeSessionBridge.sendClipboardFiles(this.activeSessionId, paths);
    if (!response.ok) {
      this.logRelativeDebug('clipboard_local', `native files failed=${String(response.message ?? '')}`);
    }
    return response.ok;
  }

  private applyRemoteNativeClipboard(): void {
    const response = this.nativeSessionBridge.takeClipboard(this.activeSessionId);
    if (!response.ok) {
      // No pending payload is neither a failure nor a clear: there is nothing to
      // apply, and the peer has not said its clipboard is empty.
      this.logRelativeDebug('clipboard_remote', `native take pending=false message=${String(response.message ?? '')}`);
      return;
    }
    const payload: RustDeskRemoteClipboardPayload = {};
    if (response.text !== undefined) {
      payload.text = response.text;
    }
    if (response.html !== undefined) {
      payload.html = response.html;
    }
    if (response.image !== undefined && response.image !== null && this.isRemoteControlSessionActive()) {
      const bytes = this.nativeSessionBridge.takeClipboardImage(this.activeSessionId);
      if (bytes.length !== response.image.byteLength) {
        this.logRelativeDebug(
          'clipboard_remote',
          `image length mismatch expected=${response.image.byteLength} actual=${bytes.length}`,
        );
        return;
      }
      payload.image = {
        format: response.image.format,
        width: response.image.width,
        height: response.image.height,
        bytes,
      };
    }
    this.clipboardController?.applyRemoteClipboard(this.activeSessionId, payload);
  }

  /**
   * The peer's verdict on a clipboard write that was already queued.
   *
   * A capability refusal is reported, never treated as a session failure: the
   * peer's clipboard channel is optional, and the session stays usable without it.
   * Only the verdict and the engine's own error metadata are logged, never the
   * text that was submitted.
   */
  private handleClipboardWriteResult(event: NativeEvent): void {
    if (event.ok === true) {
      this.logRelativeDebug('clipboard_write', 'ok=true');
      return;
    }
    const message = String(event.message ?? '');
    this.logRelativeDebug('clipboard_write', `ok=false message=${message}`);
    if (this.isClipboardTextSyncAllowed()) {
      this.showSessionNotice(`剪贴板未同步到远端：${message.length > 0 ? message : '对端拒绝了此操作'}`);
    }
  }

  private syncClipboardController(): void {
    if (this.clipboardSyncEnabled && this.isRemoteControlSessionActive()
      && this.clipboardFileRootSessionId !== this.activeSessionId) {
      const root = this.clipboardController?.incomingFileRoot(this.activeSessionId);
      if (root !== undefined) {
        const response = this.nativeSessionBridge.setClipboardFileRoot(this.activeSessionId, root);
        if (!response.ok) {
          this.logRelativeDebug('clipboard_files', `root failed=${String(response.message ?? '')}`);
        } else {
          this.clipboardFileRootSessionId = this.activeSessionId;
        }
      }
    }
    if (this.isClipboardTextSyncAllowed() && this.remoteInteractionReady) {
      if (this.clipboardPeerUpdateSessions.has(this.activeSessionId)) {
        // The peer's latest text is retrieved before the local clipboard is read, so
        // this session's own — possibly stale — clipboard is not sent over it. The
        // controller retains the payload and applies it when it starts below.
        this.clipboardPeerUpdateSessions.delete(this.activeSessionId);
        this.applyRemoteNativeClipboard();
      }
      this.clipboardController?.start(this.activeSessionId);
      return;
    }
    this.clipboardController?.stop();
  }

  // Hardware keys are captured at the input service for every interactive session:
  // the ArkUI key path loses them once focus leaves the session container, and the
  // intercepted path already routes a direct wire's key to its legacy vocabulary.
  private shouldEnableInputInterceptor(): boolean {
    return this.pageVisible &&
      this.remoteInteractionReady &&
      this.isInteractiveSessionActive() &&
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
        `start ok=${response.ok} active=${this.inputInterceptorActive} admitting=${String(response.admitting === true)} result=${String(response.result ?? '')} message=${String(response.message ?? '')}`,
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
    this.inputController?.releaseHeldKeys();
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
      if (response.sealed === true) {
        // Capture was closed on purpose and the queue was discarded: nothing from
        // this poll may be forwarded. Release every key this client still holds so
        // no key-up is lost, then stop the native owner.
        this.inputController?.releaseHeldKeys();
        this.stopInputInterceptor();
        this.logRelativeDebug('input_interceptor',
          `poll sealed: released held keys and stopped interception message=${String(response.message ?? '')}`);
        return;
      }
      if (response.overflow === true) {
        // The native queue overflowed and closed admission. Release every key
        // this client still holds so no key-up is lost, then stop the native
        // owner; a later start re-arms with a fresh queue.
        this.inputController?.releaseHeldKeys();
        this.stopInputInterceptor();
        this.logRelativeDebug('input_interceptor', 'poll overflow: released held keys and stopped interception');
        return;
      }
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
    return (this.isRemoteControlSessionActive() || (this.activeSessionKind === 'rdp' && this.activeSessionId.length > 0)) &&
      this.sessionPhase !== 'idle' &&
      this.sessionPhase !== 'closed' &&
      this.sessionPhase !== 'start_failed' &&
      this.sessionPhase !== 'blocked_transport_bootstrap' &&
      this.sessionPhase !== 'invalid_core_session_id' &&
      this.sessionPhase !== 'reconnect_failed';
  }

  private refreshRemoteAudioState(): void {
    if (!this.isRemoteAudioSessionActive() || !this.pageVisible || !this.appForeground) {
      this.closeRemoteAudio();
      return;
    }
    let state = this.nativeSessionBridge.getRemoteAudioState(this.activeSessionId);
    if (state.available && !this.remoteAudioDefaultApplied) {
      this.remoteAudioDefaultApplied = true;
      const shouldMute = !(this.activeSessionKind === 'rdp'
        ? this.activeSessionDefaults.rdpAudioEnabled : this.activeSessionDefaults.audioEnabled);
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
    // Display mode and zoom are local presentation, so every desktop wire has
    // them; what each wire offers for displays and sizes is the sheet's content.
    if (!this.isInteractiveSessionActive()) {
      this.sessionMessage = '请先建立远程桌面连接';
      return;
    }
    this.logRelativeDebug(
      'display_panel',
      `open current=${this.currentDisplayIndex} displays=${this.peerDisplays.length} resolutions=${this.supportedResolutions.length}`,
    );
    this.openOverlayPanel('display');
  }

  private openQualitySheet(): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    this.selectedRefreshRate = this.sessionDisplayController.getRefreshRate();
    this.directQualityDefaults = this.copySessionDefaults(this.sessionDefaults);
    if (this.activeSessionKind === 'rdp') {
      this.directQualityDefaults.rdpResolution = this.activeSessionDefaults.rdpResolution;
    }
    this.openOverlayPanel('quality');
  }
  private clearRdpFollowResize(): void {
    if (this.rdpFollowResizeTimer >= 0) {
      clearTimeout(this.rdpFollowResizeTimer);
      this.rdpFollowResizeTimer = -1;
    }
  }

  private requestRdpDesktopSize(size: ResolutionInfo): boolean {
    if (this.activeSessionKind !== 'rdp' || this.sessionPhase !== 'connected') {
      return false;
    }
    const shown = this.peerDisplays[0];
    if ((shown !== undefined && shown.width === size.width && shown.height === size.height) ||
      (this.pendingResolutionWidth === size.width && this.pendingResolutionHeight === size.height)) {
      return true;
    }
    if (!this.sessionDisplayController.requestResolution(this.activeSessionId, 0, size, this.peerPlatform)) {
      return false;
    }
    this.pendingResolutionDisplay = 0;
    this.pendingResolutionWidth = size.width;
    this.pendingResolutionHeight = size.height;
    this.sessionMessage = `已请求 RDP 桌面 ${size.width}×${size.height}，等待远端确认`;
    return true;
  }

  private scheduleRdpFollowResize(): void {
    this.clearRdpFollowResize();
    if (this.activeSessionKind !== 'rdp' || this.activeSessionDefaults.rdpResolution !== 'follow' ||
      this.sessionPhase !== 'connected' || !this.pageVisible || !this.appForeground || !this.showPreviewModal) {
      return;
    }
    const sessionId = this.activeSessionId;
    this.rdpFollowResizeTimer = setTimeout((): void => {
      this.rdpFollowResizeTimer = -1;
      if (sessionId !== this.activeSessionId || !this.pageVisible || !this.appForeground ||
        this.activeSessionDefaults.rdpResolution !== 'follow') {
        return;
      }
      this.requestRdpDesktopSize(computeRdpDesktopSize(this.previewViewWidth, this.previewViewHeight,
        this.getUIContext().vp2px(1)));
    }, 600) as number;
  }

  private updateDirectQualityDefaults(defaults: SessionDefaults): void {
    const next = this.copySessionDefaults(this.sessionDefaults);
    if (this.activeSessionKind === 'vnc') {
      next.vncQuality = defaults.vncQuality;
    } else if (this.activeSessionKind === 'rdp') {
      next.rdpResolution = defaults.rdpResolution;
      next.rdpScaleFactor = defaults.rdpScaleFactor;
      if (defaults.rdpResolution !== this.activeSessionDefaults.rdpResolution) {
        const size = computeRdpDesktopSize(this.previewViewWidth, this.previewViewHeight,
          this.getUIContext().vp2px(1), defaults.rdpResolution);
        if (this.requestRdpDesktopSize(size)) {
          this.activeSessionDefaults.rdpResolution = defaults.rdpResolution;
          this.scheduleRdpFollowResize();
        }
      }
    }
    this.directQualityDefaults = this.copySessionDefaults(defaults);
    this.saveSessionDefaults(next);
  }

  private remoteAudioUnavailableText(): ResourceStr {
    if (this.activeSessionKind === 'vnc') {
      return $r('app.string.direct_vnc_audio_unsupported');
    }
    if (this.activeSessionKind !== 'rdp') {
      return '';
    }
    if (this.remoteAudioState.errorText.length > 0) {
      return this.remoteAudioState.errorText;
    }
    return this.directAudioCapability === 'unsupported' || !this.activeSessionDefaults.rdpAudioEnabled
      ? $r('app.string.direct_rdp_audio_unsupported') : $r('app.string.direct_rdp_audio_waiting');
  }

  private remoteKeyboardUnavailableText(): ResourceStr {
    if (!this.isDirectWireSession()) {
      return '';
    }
    if (!this.remoteKeyboardPermissionAllowed) {
      return $r('app.string.direct_keyboard_permission_reason');
    }
    if (this.isPcDevice()) {
      return $r('app.string.direct_keyboard_pc_reason');
    }
    return this.isFoldHoverMode ? $r('app.string.direct_keyboard_fold_reason') : '';
  }


  private async openTransferWorkspace(): Promise<void> {
    if (this.transferManager.isReady() && this.transferSessionTarget === this.peerTarget.trim()) {
      this.captureSessionReturnTab();
      await this.openTransferWorkspaceDirect();
      return;
    }
    await this.preparePeerLaunch(this.peerTarget, 'file_transfer');
  }

  private async openTransferWorkspaceDirect(): Promise<void> {
    if (!this.runtimeInitialized) {
      void this.initializeRuntime();
    }
    const target = this.peerTarget.trim();
    if (target.length === 0) {
      this.errorText = '请输入目标地址';
      return;
    }
    this.peerTarget = target;
    this.preferences?.saveTarget(target, this.connectPageMode);
    if (this.transferManager.isReady()
      && this.transferSessionTarget.length > 0
      && this.transferSessionTarget !== target) {
      this.errorText = `已有 ${this.transferSessionTarget} 的文件传输会话，请先结束该会话再切换设备`;
      if (this.transferManager.canTransfer()) {
        this.hideSystemIme(false);
        this.hideSoftKeyboard();
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
        this.hideSystemIme(false);
        this.hideSoftKeyboard();
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
      this.restoreSessionReturnTab();
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
      const transferError = this.transferManager.consumeTransferError();
      if (transferError !== undefined) {
        this.reportTransferError(transferError);
      }
      const passwordMessage = this.transferManager.consumePasswordRequest();
      if (passwordMessage !== undefined) {
        this.openPasswordDialog('file_transfer', passwordMessage);
      }
      this.syncTransferState();
      if (this.transferManager.canTransfer() && this.transferConnectionPending) {
        this.clearConnectionTimeout();
        this.dismissPasswordDialogFor('file_transfer');
        this.errorText = '';
        this.transferConnectionPending = false;
        this.connectionUiPhase = 'idle';
        this.connectionUiMessage = '';
        this.hideSystemIme(false);
        this.hideSoftKeyboard();
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
      return;
    }
    this.reportPendingTransferError();
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
      return;
    }
    this.reportPendingTransferError();
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
    this.restoreSessionReturnTab();
  }

  private reportPendingTransferError(): void {
    const message = this.transferManager.consumeTransferError();
    if (message !== undefined) {
      this.reportTransferError(message);
    }
  }

  private reportTransferError(message: string): void {
    this.errorText = message;
    this.transferConnectionStatus = message;
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 5000 });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Failed to show transfer error: %{public}s', String(error));
    }
    this.syncTransferState();
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

  private isImmersiveFullscreenStatus(status: window.WindowStatusType): boolean {
    // HarmonyOS distinguishes ordinary MAXIMIZE (title/Dock retained) from
    // FULL_SCREEN entered through ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER.
    return status === window.WindowStatusType.FULL_SCREEN;
  }

  private applyFreeMultiWindowChrome(status: window.WindowStatusType): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow) {
      this.freeMultiWindow = false;
      return;
    }
    this.sessionWindowFullscreen = this.isImmersiveFullscreenStatus(status);
    const isFreeMultiWindow = status === window.WindowStatusType.FLOATING;
    if (isFreeMultiWindow) {
      this.sessionWindowResizeCapable = true;
    } else if (status === window.WindowStatusType.FULL_SCREEN) {
      this.sessionWindowResizeCapable = false;
    }
    if (this.isPcDevice() || deviceInfo.deviceType === 'tablet' || isFreeMultiWindow) {
      this.sessionWindowControlCapable = true;
    }
    const hideForRemoteSession = status !== window.WindowStatusType.MINIMIZE
      && (this.showPreviewModal || this.pcSessionImmersiveRequested || this.manualSessionWindowImmersiveApplied);

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
    if (hideForRemoteSession) {
      try {
        currentWindow.setWindowDecorVisible(false);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to keep remote session decor hidden: %{public}s', String(error));
        return;
      }
      this.freeWindowChromeOwned = true;
      currentWindow.setTitleAndDockHoverShown(false, false)
        .catch((error: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'Failed to keep remote session title and dock hover hidden: %{public}s',
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
    this.sessionWindowControlCapable = false;
    this.sessionWindowResizeCapable = false;
    this.sessionWindowFullscreen = false;
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

  private sessionWindowControlsAvailable(): boolean {
    return this.freeWindow !== undefined && this.sessionWindowControlCapable;
  }

  private sessionWindowFullscreenAvailable(): boolean {
    return this.sessionWindowControlsAvailable()
      && (this.isPcDevice() || this.sessionWindowResizeCapable || this.sessionWindowFullscreen);
  }

  private reportSessionWindowControlFailure(action: string, error: Error | BusinessError): void {
    const message = `${action}失败：${String(error)}`;
    this.errorText = message;
    this.sessionMessage = message;
    hilog.error(DOMAIN, TAG, '%{public}s', message);
  }

  private minimizeSessionWindow(): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow || this.sessionWindowControlBusy) {
      return;
    }
    this.sessionWindowControlBusy = true;
    currentWindow.minimize()
      .catch((error: BusinessError) => {
        this.reportSessionWindowControlFailure('最小化窗口', error);
      })
      .finally((): void => {
        this.sessionWindowControlBusy = false;
      });
  }

  private toggleSessionWindowFullscreen(): void {
    const currentWindow = this.freeWindow;
    if (!currentWindow || this.sessionWindowControlBusy) {
      return;
    }
    let status: window.WindowStatusType;
    try {
      status = currentWindow.getWindowStatus();
    } catch (error) {
      this.reportSessionWindowControlFailure('读取窗口状态', error as Error);
      return;
    }
    this.sessionWindowControlBusy = true;
    const shouldRecover = this.isImmersiveFullscreenStatus(status);
    if (shouldRecover) {
      currentWindow.recover()
        .then((): void => {
          this.manualSessionWindowImmersiveApplied = false;
          this.pcSessionImmersiveApplied = false;
          this.pcSessionImmersiveRequested = false;
          this.pcSessionWindowStatusBeforeImmersive = window.WindowStatusType.UNDEFINED;
          this.sessionWindowFullscreen = false;
          this.refreshFreeWindowChrome();
        })
        .catch((error: BusinessError) => {
          this.reportSessionWindowControlFailure('退出全屏', error);
        })
        .finally((): void => {
          this.sessionWindowControlBusy = false;
        });
      return;
    }
    currentWindow.maximize(window.MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER)
      .then((): Promise<void> => {
        this.manualSessionWindowImmersiveApplied = true;
        this.sessionWindowFullscreen = true;
        currentWindow.setWindowDecorVisible(false);
        this.freeWindowChromeOwned = true;
        return currentWindow.setTitleAndDockHoverShown(false, false);
      })
      .then((): void => {
        this.refreshFreeWindowChrome();
      })
      .catch((error: BusinessError) => {
        this.manualSessionWindowImmersiveApplied = false;
        this.reportSessionWindowControlFailure('全屏窗口', error);
      })
      .finally((): void => {
        this.sessionWindowControlBusy = false;
      });
  }

  private async restoreManualSessionWindow(currentWindow: window.Window): Promise<void> {
    if (!this.manualSessionWindowImmersiveApplied) {
      return;
    }
    try {
      const status = currentWindow.getWindowStatus();
      if (this.isImmersiveFullscreenStatus(status)) {
        await currentWindow.recover();
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Failed to restore manually fullscreen window: %{public}s', String(error));
    } finally {
      this.manualSessionWindowImmersiveApplied = false;
      this.sessionWindowFullscreen = false;
    }
  }

  private async closeSessionWindow(): Promise<void> {
    if (this.sessionWindowControlBusy) {
      return;
    }
    this.sessionWindowControlBusy = true;
    try {
      await this.closeSession('窗口已关闭');
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await hostContext.terminateSelf();
    } catch (error) {
      this.reportSessionWindowControlFailure('关闭窗口', error as Error);
      this.sessionWindowControlBusy = false;
    }
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
    if (this.isDirectWireSession()) {
      // A direct wire reports exactly one display and the engine presents it into
      // the Surface itself, so there is no switch/size/refresh to ask the Core
      // for; issuing them here would only be refused by name. The Surface binding
      // above already happened and is what this wire needs.
      this.initialDisplayCommandIssued = true;
      this.currentDisplayIndex = this.sessionDisplayController.getCurrentDisplayIndex();
      return;
    }
    if (!this.sessionDisplayController.selectDisplay(this.activeSessionId, display)) {
      return;
    }
    this.initialDisplayCommandIssued = true;
    this.currentDisplayIndex = this.sessionDisplayController.getCurrentDisplayIndex();
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
    if (this.isDirectWireSession()) {
      // These wires carry one display and the engine owns its presentation, so
      // there is no second display to switch to; saying so is honest where a
      // refused Core command would look like a failed operation.
      this.sessionMessage = '当前协议仅有一个显示器';
      return;
    }
    if (!this.sessionDisplayController.selectDisplay(this.activeSessionId, display)) {
      this.logRelativeDebug('display_select', `rejected target=${display}`);
      return;
    }
    this.initialDisplayCommandIssued = true;
    this.currentDisplayIndex = this.sessionDisplayController.getCurrentDisplayIndex();
    this.pendingDisplayIndex = display;
    this.lastAppliedDisplay = -1;
    this.lastAppliedVideoWidth = 0;
    this.lastAppliedVideoHeight = 0;
    this.sessionMessage = `已请求切换到显示器 ${display + 1}`;
    this.logRelativeDebug('display_select', `pending=${display} current=${this.currentDisplayIndex}`);
  }

  private requestResolutionChange(resolution: ResolutionInfo): void {
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    if (this.activeSessionKind === 'vnc') {
      // An RFB framebuffer is the server's own size; nothing a client sends
      // changes it.
      this.sessionMessage = '桌面尺寸由 VNC 服务端决定';
      return;
    }
    const display = this.sessionDisplayController.getCurrentDisplayIndex();
    if (!this.sessionDisplayController.requestResolution(
      this.activeSessionId,
      display,
      resolution,
      this.peerPlatform,
    )) {
      this.logRelativeDebug(
        'resolution_select',
        `rejected display=${display} width=${resolution.width} height=${resolution.height}`,
      );
      return;
    }
    if (this.activeSessionKind === 'rdp') {
      this.activeSessionDefaults.rdpResolution = `${resolution.width}x${resolution.height}`;
      this.clearRdpFollowResize();
    }
    this.pendingResolutionDisplay = display;
    this.pendingResolutionWidth = resolution.width;
    this.pendingResolutionHeight = resolution.height;
    this.sessionMessage = `已请求远端分辨率 ${resolution.width}x${resolution.height}`;
    this.logRelativeDebug(
      'resolution_select',
      `pending display=${display} width=${resolution.width} height=${resolution.height}`,
    );
  }

  private applyRefreshRateSelection(rate: number): void {
    this.logRelativeDebug('refresh_rate', `requested=${rate} valid=${isValidRefreshRate(rate)} session=${this.activeSessionId}`);
    if (!isValidRefreshRate(rate)) {
      return;
    }
    if (!this.activeSessionId) {
      this.sessionMessage = '请先建立远控连接';
      return;
    }
    const remoteRateSupported = this.activeSessionKind === 'remote_control';
    if (remoteRateSupported) {
      const applied = this.sessionDisplayController.applyRefreshRate(this.activeSessionId, rate);
      this.logRelativeDebug('refresh_rate', `remote=${String(applied)} stored=${this.sessionDisplayController.getRefreshRate()}`);
      if (!applied) {
        this.sessionMessage = '远端拒绝了此刷新率';
        return;
      }
    } else {
      // A direct VNC/RDP wire has no remote rate control, so only the local
      // display expectation and the remembered choice change here: the local
      // panel rate keeps working exactly as it did.
      this.sessionDisplayController.restoreRefreshRate(rate);
      this.logRelativeDebug('refresh_rate',
        `remote=unsupported local=${this.sessionDisplayController.getRefreshRate()}`);
    }
    this.selectedRefreshRate = this.sessionDisplayController.getRefreshRate();
    // Remembered so the next session from this device starts where this one left
    // off, including across an app restart.
    this.activeSessionDefaults.refreshRate = this.selectedRefreshRate;
    // The panel is asked for the new rate as well: it is what the picture is
    // shown at, and a panel left at its old rate caps the session regardless of
    // what the peer was asked to send.
    this.declarePanelFrameRate();
    this.sessionMessage = remoteRateSupported
      ? `已请求 ${this.selectedRefreshRate} Hz 采集`
      : `本机显示已设为 ${this.selectedRefreshRate} Hz；当前协议不支持远端采集帧率`;
  }

  private syncInputEnabled(enabled: boolean): void {
    this.getInputController().setInputSuppressed(!enabled);
    if (!enabled) {
      this.remoteCursorVisible = false;
    }
  }

  private syncTouchMode(active: boolean): void {
    this.getInputController().setMouseMode(!active);
    if (!active || this.relativeMouseMode) {
      this.ensureRelativeCursorOverlay();
      return;
    }
    this.remoteCursorVisible = false;
  }

  private syncRelativeMouseMode(active: boolean): void {
    this.getInputController().setRelativeMode(active);
    this.relativeModeActivatedAt = active ? Date.now() : 0;
    if (active || !this.touchMode) {
      this.ensureRelativeCursorOverlay();
    }
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
        const isPcDevice = this.isPcDevice();
        if (landscapeMultiWindowChanged && !isPcDevice) {
          await this.applyLandscapeMultiWindow(currentWindow, landscapeMultiWindowEnabled, force);
        } else if (isPcDevice) {
          this.landscapeMultiWindowEnabled = false;
        }
        if (orientationChanged) {
          if (!isPcDevice) {
            await currentWindow.setPreferredOrientation(this.toWindowOrientation(orientationMode));
          }
          this.sessionOrientationMode = orientationMode;
        }
        if (fullscreenChanged) {
          if (active) {
            await this.applyPcSessionImmersive(currentWindow, true);
            if (!isPcDevice) {
              await currentWindow.setWindowLayoutFullScreen(true);
              await currentWindow.setSpecificSystemBarEnabled('status', false, true);
              await currentWindow.setSpecificSystemBarEnabled('navigationIndicator', false, true);
            }
          } else {
            if (!isPcDevice) {
              await currentWindow.setSpecificSystemBarEnabled('status', true, true);
              await currentWindow.setSpecificSystemBarEnabled('navigationIndicator', true, true);
              await currentWindow.setWindowLayoutFullScreen(true);
            }
            await this.restoreManualSessionWindow(currentWindow);
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
      const cutoutArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      this.updateWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT, cutoutArea);
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
    } else if (type === window.AvoidAreaType.TYPE_CUTOUT) {
      this.windowCutoutLeftWidth = Math.max(Math.round(uiContext.px2vp(area.leftRect.width)), 0);
      this.windowCutoutRightWidth = Math.max(Math.round(uiContext.px2vp(area.rightRect.width)), 0);
    }
    // The toolbar's baseline is part of the safe area, so a change re-seats it.
    this.reclampMiniBarAnchor();
  }

  /** The pane insets the toolbar keeps clear: side cutouts, and the gesture bar. */
  private miniBarLeftInset(): number {
    return Math.max(0, this.windowCutoutLeftWidth);
  }

  private miniBarRightInset(): number {
    return Math.max(0, this.windowCutoutRightWidth);
  }

  private miniBarBottomBound(): number {
    return Math.max(0, this.windowBottomAvoidInset) + MINI_BAR_BOTTOM_MARGIN;
  }

  /** The pane's own size, with the window as the stand-in before it is measured. */
  private miniBarViewportWidth(): number {
    return this.previewViewWidth > 0 ? this.previewViewWidth : this.mainViewportWidth;
  }

  private miniBarViewportHeight(): number {
    return this.previewViewHeight > 0 ? this.previewViewHeight : this.mainViewportHeight;
  }

  /** The collapsed entry's default anchor: flush with the pane's right edge. */
  private defaultMiniBarAnchorRight(viewportWidth: number): number {
    return Math.max(MINI_BAR_COLLAPSED_TOUCH_WIDTH + this.miniBarLeftInset(),
      viewportWidth - this.miniBarRightInset());
  }

  /** The top both states default to, clear of the status-bar band. */
  private defaultMiniBarAnchorTop(): number {
    return Math.max(MINI_BAR_TOP_BASELINE, this.windowTopAvoidInset + MINI_BAR_TOP_AVOID_OFFSET);
  }

  /**
   * The expanded panel's width: its share of the pane, capped by what the side
   * cutouts leave. The panel is laid out with this same value.
   */
  private miniBarExpandedWidth(): number {
    const viewportWidth = this.miniBarViewportWidth();
    if (viewportWidth <= 0) {
      return 0;
    }
    const available = Math.max(0, viewportWidth - this.miniBarLeftInset() - this.miniBarRightInset());
    return Math.min(viewportWidth * MINI_BAR_EXPANDED_WIDTH_RATIO, available);
  }

  /**
   * The anchor is the collapsed entry's own corner, so only the collapsed bounds
   * may move it. A panel too wide for the pane is drawn clamped instead of
   * dragging the tab with it, which is what lets a dragged tab keep its place.
   */
  private clampMiniBarAnchorRight(value: number, viewportWidth: number): number {
    const maxRight = Math.max(0, viewportWidth - this.miniBarRightInset());
    const minRight = Math.min(MINI_BAR_COLLAPSED_TOUCH_WIDTH + this.miniBarLeftInset(), maxRight);
    return Math.min(Math.max(value, minRight), maxRight);
  }

  private clampMiniBarAnchorTop(value: number, viewportHeight: number): number {
    const maxTop = Math.max(
      0,
      viewportHeight - MINI_BAR_COLLAPSED_HEIGHT - this.miniBarBottomBound(),
    );
    const minTop = Math.min(this.defaultMiniBarAnchorTop(), maxTop);
    return Math.min(Math.max(value, minTop), maxTop);
  }

  /** Where the visible state is drawn: clamped per state, never written back. */
  private clampMiniBarX(value: number, itemWidth: number): number {
    const left = this.miniBarLeftInset();
    const maxX = Math.max(left, this.miniBarViewportWidth() - itemWidth - this.miniBarRightInset());
    return Math.min(Math.max(value, left), maxX);
  }

  private clampMiniBarY(value: number, itemHeight: number): number {
    const maxY = Math.max(0, this.miniBarViewportHeight() - itemHeight - this.miniBarBottomBound());
    const minY = Math.min(this.defaultMiniBarAnchorTop(), maxY);
    return Math.min(Math.max(value, minY), maxY);
  }

  /** An unset anchor still lays out at its default, so the first frame is placed. */
  private miniBarResolvedAnchorRight(): number {
    if (this.miniBarAnchorInitialized) {
      return this.miniBarAnchorRight;
    }
    const viewportWidth = this.miniBarViewportWidth();
    return viewportWidth > 0 ? this.defaultMiniBarAnchorRight(viewportWidth) : viewportWidth;
  }

  private miniBarResolvedAnchorTop(): number {
    return this.miniBarAnchorInitialized ? this.miniBarAnchorTop : this.defaultMiniBarAnchorTop();
  }

  private miniBarCollapsedX(): number {
    return this.clampMiniBarX(
      this.miniBarResolvedAnchorRight() - MINI_BAR_COLLAPSED_TOUCH_WIDTH,
      MINI_BAR_COLLAPSED_TOUCH_WIDTH,
    );
  }

  private miniBarCollapsedY(): number {
    return this.clampMiniBarY(this.miniBarResolvedAnchorTop(), MINI_BAR_COLLAPSED_HEIGHT);
  }

  private miniBarExpandedX(): number {
    const panelWidth = this.miniBarExpandedWidth();
    return this.clampMiniBarX(this.miniBarResolvedAnchorRight() - panelWidth, panelWidth);
  }

  private miniBarExpandedY(): number {
    return this.clampMiniBarY(this.miniBarResolvedAnchorTop(), this.miniBarExpandedHeight);
  }

  /**
   * Re-seat the toolbar for the current viewport.
   *
   * An untouched toolbar follows the pane's right/top corner; a dragged one is
   * only clamped, so a rotation, a resize or a safe-area change can never strand
   * it off screen. The anchor holds the collapsed entry's own corner, which is
   * why a dragged position survives expanding and collapsing again.
   */
  private reclampMiniBarAnchor(): void {
    const width = this.previewViewWidth;
    const height = this.previewViewHeight;
    if (width <= 0 || height <= 0) {
      return;
    }
    if (!this.miniBarAnchorInitialized || !this.miniBarDragged) {
      this.miniBarAnchorRight = this.clampMiniBarAnchorRight(
        this.defaultMiniBarAnchorRight(width),
        width,
      );
      this.miniBarAnchorTop = this.clampMiniBarAnchorTop(this.defaultMiniBarAnchorTop(), height);
      this.miniBarAnchorInitialized = true;
      return;
    }
    this.miniBarAnchorRight = this.clampMiniBarAnchorRight(this.miniBarAnchorRight, width);
    this.miniBarAnchorTop = this.clampMiniBarAnchorTop(this.miniBarAnchorTop, height);
  }

  private measureMiniBarExpandedHeight(height: number): void {
    // The panel is drawn from this height, so recording it re-clamps by itself.
    if (height <= 0 || Math.abs(height - this.miniBarExpandedHeight) <= 0.5) {
      return;
    }
    this.miniBarExpandedHeight = height;
  }

  private startMiniBarDrag(): void {
    // A drag continues from where the toolbar is actually drawn, not from the
    // anchor: the two differ whenever the visible state had to be clamped.
    this.miniBarDragStartX = this.isMiniBarExpanded ? this.miniBarExpandedX() : this.miniBarCollapsedX();
    this.miniBarDragStartY = this.isMiniBarExpanded ? this.miniBarExpandedY() : this.miniBarCollapsedY();
    this.miniBarDragged = true;
  }

  private updateMiniBarDrag(offsetX: number, offsetY: number): void {
    if (this.miniBarViewportWidth() <= 0 || this.miniBarViewportHeight() <= 0) {
      return;
    }
    this.miniBarDragged = true;
    this.miniBarAnchorInitialized = true;
    if (this.isMiniBarExpanded) {
      // A real drag of the panel does move the shared anchor: the tab follows it.
      const panelWidth = this.miniBarExpandedWidth();
      const x = this.clampMiniBarX(this.miniBarDragStartX + offsetX, panelWidth);
      const y = this.clampMiniBarY(this.miniBarDragStartY + offsetY, this.miniBarExpandedHeight);
      this.miniBarAnchorRight = x + panelWidth;
      this.miniBarAnchorTop = y;
      return;
    }
    const x = this.clampMiniBarX(this.miniBarDragStartX + offsetX, MINI_BAR_COLLAPSED_TOUCH_WIDTH);
    const y = this.clampMiniBarY(this.miniBarDragStartY + offsetY, MINI_BAR_COLLAPSED_HEIGHT);
    this.miniBarAnchorRight = x + MINI_BAR_COLLAPSED_TOUCH_WIDTH;
    this.miniBarAnchorTop = y;
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
    this.syncRemoteSessionSharing();
    this.syncInputInterceptor();
    this.registerFoldHoverListeners();
    this.previewSurfaceVisible = false;
    this.previewSurfaceId = '';
    // The holder identity belongs to the generation being replaced: its own
    // detach still names it through that controller instance, so this field is
    // dropped here instead of being reused for the new pane.
    this.previewComponentId = '';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.frameStatus = 'Preparing preview surface';
    this.previewSurfaceGeneration += 1;
    this.previewController = this.createPreviewSurfaceController(
      this.previewSurfaceGeneration,
      this.activeSessionId,
    );
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
      if (this.previewComponentId.length > 0 && this.syncSurfaceBinding()) {
        return;
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), PREVIEW_SURFACE_WAIT_INTERVAL_MS));
    }
    if (this.previewComponentId.length === 0) {
      throw new Error('Preview XComponent holder was not attached before session start');
    }
    throw new Error('Preview XComponent holder was attached but could not be bound before session start');
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
      // Asked for while the picture is on screen, so an idle panel is not held
      // at a high rate when nothing is being shown.
      this.declarePanelFrameRate();
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

  private setPointerMode(mode: RustDeskInputMode): void {
    if (!this.isInteractiveSessionActive()) {
      return;
    }
    if (mode === 'relative' && !this.relativeMouseModeSupported()) {
      this.sessionMessage = '当前远端不支持相对鼠标模式';
      return;
    }
    // Choosing any mode is also how input comes back on, so there is no way to
    // select a mode that silently sends nothing.
    const nextEnabled = mode !== 'off';
    if (this.inputEnabled !== nextEnabled) {
      this.inputEnabled = nextEnabled;
      this.activeSessionDefaults.inputEnabled = nextEnabled;
      this.syncInputEnabled(nextEnabled);
    }
    if (mode === 'off') {
      this.sessionMessage = '输入已关闭，远端仍可观看';
      return;
    }
    const nextTouchMode = mode === 'touch';
    const nextRelativeMode = mode === 'relative';
    if (this.relativeMouseMode && !nextRelativeMode) {
      this.relativeMouseMode = false;
      this.syncRelativeMouseMode(false);
    }
    if (this.touchMode !== nextTouchMode) {
      this.touchMode = nextTouchMode;
      this.syncTouchMode(nextTouchMode);
    }
    if (!this.relativeMouseMode && nextRelativeMode) {
      this.relativeMouseMode = true;
      this.syncRelativeMouseMode(true);
    }
    this.sessionMessage = `已切换到${this.getPointerModeName()}`;
  }

  private async cyclePointerMode(): Promise<void> {
    if (!this.inputEnabled) {
      this.setPointerMode('touch');
      return;
    }
    if (this.touchMode) {
      this.setPointerMode('mouse');
      return;
    }
    if (!this.relativeMouseMode && this.relativeMouseModeSupported()) {
      this.setPointerMode('relative');
      return;
    }
    this.setPointerMode('off');
  }

  private setRightClickGesture(gesture: RustDeskRightClickGesture): void {
    this.rightClickGesture = gesture;
    if (gesture === 'double_tap') {
      this.sessionMessage = '右键手势已切换为双击';
    } else if (gesture === 'two_finger_tap') {
      this.sessionMessage = '右键手势已切换为双指点击';
    } else {
      this.sessionMessage = '右键手势已切换为长按';
    }
  }

  private getPointerModeName(): string {
    if (!this.inputEnabled) {
      return '输入关闭';
    }
    if (this.touchMode) {
      return '触控模式';
    }
    return this.relativeMouseMode ? '相对鼠标模式' : '鼠标模式';
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

  private applyPreviewTouchTransform(
    scaleFactor: number,
    panX: number,
    panY: number,
    focalX: number,
    focalY: number,
  ): void {
    if (!this.activeSessionDefaults.gesturesEnabled || !Number.isFinite(scaleFactor) || scaleFactor <= 0) {
      return;
    }
    const previousScale = this.previewUserScale;
    const nextScale = this.clampPreviewScale(previousScale * scaleFactor);
    const appliedScaleFactor = nextScale / Math.max(previousScale, 0.001);
    const centerX = this.previewViewWidth / 2;
    const centerY = this.previewViewHeight / 2;
    this.previewUserScale = nextScale;
    this.previewUserOffsetX = this.clampPreviewOffsetX(
      this.previewUserOffsetX * appliedScaleFactor
        + (focalX - centerX) * (1 - appliedScaleFactor)
        + panX,
    );
    this.previewUserOffsetY = this.clampPreviewOffsetY(
      this.previewUserOffsetY * appliedScaleFactor
        + (focalY - centerY) * (1 - appliedScaleFactor)
        + panY,
    );
    this.syncPreviewViewTransform();
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

  /**
   * The height budget for the toolbar's middle slot: the panel body, or the cap
   * the home block may occupy.
   *
   * The panel is drawn from its anchor, and that anchor can never sit above its
   * default top, so the whole expanded box has to fit between that top and the
   * bound the toolbar keeps clear of the gesture bar. What is left after the
   * panel's own padding and the toolbar's measured chrome is the slot's. The
   * floor is 0 rather than a minimum: a minimum would push the box past the
   * bound it is computed from, which is the overflow this budget exists to
   * prevent. The panel's own sheets scroll, so a small slot still reaches all
   * of their content.
   */
  private sessionOverlayContentHeight(): number {
    const viewportHeight = this.miniBarViewportHeight();
    if (viewportHeight <= 0) {
      return 0;
    }
    const chromeHeight = this.sessionToolbarChromeHeight > 0
      ? this.sessionToolbarChromeHeight
      : SESSION_TOOLBAR_CHROME_FALLBACK_HEIGHT;
    const available = viewportHeight
      - this.defaultMiniBarAnchorTop()
      - this.miniBarBottomBound()
      - MINI_BAR_EXPANDED_PADDING * 2
      - chromeHeight;
    if (available <= 0) {
      return 0;
    }
    // The wide input sheet is a short list of selectors, so it keeps a shorter
    // ceiling than the scrolling quality and display sheets.
    const ceiling = this.activeOverlayPanel === 'input' && this.previewViewWidth >= 700 ? 300 : 560;
    return Math.min(ceiling, available);
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
    return this.isInteractiveSessionActive()
      && (this.inputEnabled && (!this.touchMode || this.relativeMouseMode))
      && this.remoteCursorVisible
      && !this.isCurrentDisplayCursorEmbedded();
  }

  /**
   * Whether the peer paints its pointer into the picture of the shown display,
   * as upstream RustDesk reports it; a second, local arrow would then only
   * trail the real one.
   */
  private isCurrentDisplayCursorEmbedded(): boolean {
    const display = this.currentDisplayIndex >= 0 && this.currentDisplayIndex < this.peerDisplays.length
      ? this.peerDisplays[this.currentDisplayIndex]
      : undefined;
    return display !== undefined && display.cursor_embedded === 1;
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
      this.logRelativeDebug('keyboard_enter',
        `enter=${enter} ok=${response.ok} applied=${String(response.applied === true)} notSupported=${String(response.notSupported === true)} session=${targetSessionId} message=${String(response.message ?? '')}`);
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
    if (!this.isInteractiveSessionActive()) {
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
      const response = this.parseResponse(native.sessionSendMouse(
        sessionId,
        JSON.stringify(payload),
        this.currentInputGeneration(),
      ));
      if (!response.ok && reportFailure && this.activeSessionId === sessionId) {
        // A refusal names the generation the session is at now.
        this.adoptInputGeneration(response);
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
        `raw=(${remoteX},${remoteY}) seeded=${hadVirtualCursor ? 'no' : 'yes'} mode=${this.touchMode ? 'touch' : 'mouse'} relative=${this.relativeMouseMode}`,
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
    void this.cursorModel.updateCursorData(
      event,
      (message: string) => this.logRelativeDebug('cursor_data', message),
      () => {
        this.applyCursorSnapshotToVisualState();
        this.reprojectVirtualCursorOverlay();
      },
    );
  }

  private async restoreRemoteCursorState(sessionId: string): Promise<void> {
    const cachedData = this.remoteSessionTabsController.cursorDataSnapshot(sessionId);
    for (const event of cachedData) {
      await this.cursorModel.updateCursorData(
        event,
        (message: string) => this.logRelativeDebug('cursor_restore', message),
        () => {},
      );
    }
    const lastCursorId = this.remoteSessionTabsController.lastCursorId(sessionId);
    if (lastCursorId.length > 0) {
      this.cursorModel.updateCursorId(lastCursorId);
    }
    this.applyCursorSnapshotToVisualState();
    this.reprojectVirtualCursorOverlay();
  }

  private handlePreviewTouchEvent(event: TouchEvent): void {
    if (!this.isInteractiveSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleTouchEvent(event);
  }

  private sendKeyPayloadObject(payload: RustDeskKeyPayload): boolean {
    if (!this.isInteractiveSessionActive()) {
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionInputKey(
        this.activeSessionId,
        JSON.stringify(payload),
        this.currentInputGeneration(),
      ));
      // The key itself is never named here: a key name identifies a keystroke, and a
      // sequence of them reconstructs what was typed, which can be a password.
      this.logRelativeDebug('keyboard_send_legacy', `ok=${response.ok} down=${payload.down} press=${payload.press}`);
      if (!response.ok) {
        // A refusal names the generation the session is at now.
        this.adoptInputGeneration(response);
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
    if (payload.inputGeneration === undefined) {
      // The mapper that built this payload is not bound to a session, so the value
      // is captured here, at the moment the real event is sent. A payload that
      // already names a generation keeps it: an older event is never rewritten onto
      // the current generation.
      const generation = this.currentInputGeneration();
      if (generation === undefined) {
        // Nothing has been adopted yet, so there is no real value to name. The event
        // is refused here instead of being sent as 0 or without one; the next poll,
        // or any input refusal, adopts the value the native side reports.
        this.logRelativeDebug('keyboard_send_flutter', 'skipped: no adopted input generation yet');
        return false;
      }
      payload.inputGeneration = generation;
    }
    try {
      const response = this.parseResponse(native.sessionHandleFlutterKeyEvent(this.activeSessionId, JSON.stringify(payload)));
      this.logRelativeDebug('keyboard_send_flutter', `ok=${response.ok} down=${payload.down_or_up}`);
      if (!response.ok) {
        // The refusal names the generation the session is at now; adopting it is how
        // the next event is admitted. This event is not replayed.
        this.adoptInputGeneration(response);
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
    if (!this.isInteractiveSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleMouseEvent(event);
  }

  private handlePreviewAxisEvent(event: AxisEvent): void {
    if (!this.isInteractiveSessionActive()) {
      return;
    }
    this.requestPreviewInputFocus();
    this.getInputController().handleAxisEvent(event);
  }

  private handlePreviewKeyEvent(event: KeyEvent): boolean {
    if (!this.isInteractiveSessionActive()) {
      return false;
    }
    this.requestPreviewInputFocus();
    if (this.inputInterceptorActive) {
      // The native interceptor already owns this keystroke; forwarding it from
      // ArkUI as well would send it twice.
      return true;
    }
    this.logRelativeDebug('keyboard_event', `type=${String(event.type)}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private handlePreviewRootKeyEvent(event: KeyEvent): boolean {
    if (!this.isInteractiveSessionActive()) {
      return false;
    }
    if (this.inputInterceptorActive) {
      return true;
    }
    this.logRelativeDebug('keyboard_root_event', `type=${String(event.type)}`);
    return this.getInputController().handleKeyEvent(event);
  }

  private requestPreviewInputFocus(): void {
    if (!this.showPreviewModal || this.systemImeActive) {
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
  }

  private startPolling(): void {
    if ((this.activeSessionId.length === 0 && this.remoteSessionTabsController.count() === 0)
      || this.pollTimer >= 0) {
      return;
    }
    this.isPolling = true;
    this.pollTimer = setInterval(() => {
      this.pollSessionEvents();
    }, EVENT_POLL_INTERVAL_MS);
  }

  private sessionToolbarMetrics(): SessionToolbarMetrics {
    return formatSessionToolbarMetrics(
      this.qualityTelemetry.submittedFps,
      this.qualityTelemetry.networkRttMs,
      this.qualityTelemetry.codec,
    );
  }


  private shortRemoteStatusText(): string {
    const metrics = this.sessionToolbarMetrics();
    return `提交 ${metrics.fps} FPS | RTT ${metrics.delay} ms | ${metrics.codec} | ${this.getPointerModeName()}`;
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
      if (event.resolutions !== undefined) {
        this.supportedResolutions = this.parseSupportedResolutions(event.resolutions);
      }
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
        event.resolutions === undefined ? undefined : this.supportedResolutions,
        this.peerPlatform,
      );
      const currentDisplay = this.sessionDisplayController.getCurrentDisplayIndex();
      this.currentDisplayIndex = currentDisplay;
      const shown = this.peerDisplays[currentDisplay];
      if (shown !== undefined) {
        // A direct RDP session reports its new desktop through peer_info.
        this.confirmPendingResolution(currentDisplay, shown.width, shown.height);
      }
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
    const updatedDisplays = this.peerDisplays.slice();
    updatedDisplays[display] = {
      width: Math.round(width),
      height: Math.round(height),
      x: Number.isFinite(x) ? x : previous.x,
      y: Number.isFinite(y) ? y : previous.y,
      cursor_embedded: previous.cursor_embedded,
      original_width: previous.original_width,
      original_height: previous.original_height,
    };
    this.peerDisplays = updatedDisplays;
    if (event.resolutions !== undefined) {
      this.supportedResolutions = this.parseSupportedResolutions(event.resolutions);
    }
    this.sessionDisplayController.updatePeerInfo(
      this.peerDisplays,
      undefined,
      event.resolutions === undefined ? undefined : this.supportedResolutions,
      this.peerPlatform,
    );
    this.currentDisplayIndex = this.sessionDisplayController.getCurrentDisplayIndex();
    this.refreshSessionOrientation();
    if (this.pendingDisplayIndex === display) {
      this.pendingDisplayIndex = -1;
      this.sessionMessage = `显示器 ${display + 1} 已确认切换`;
      if (this.previewSurfaceId.length > 0) {
        this.syncSurfaceBinding(false);
      }
    }
    this.confirmPendingResolution(display, width, height);
    this.applyDisplayConfiguration();
    this.reprojectVirtualCursorOverlay();
  }

  /** Clears a resolution request once the display it named really reports that size. */
  private confirmPendingResolution(display: number, width: number, height: number): void {
    if (this.pendingResolutionDisplay !== display
      || this.pendingResolutionWidth !== Math.round(width)
      || this.pendingResolutionHeight !== Math.round(height)) {
      return;
    }
    this.pendingResolutionDisplay = -1;
    this.pendingResolutionWidth = 0;
    this.pendingResolutionHeight = 0;
    this.sessionMessage = `远端分辨率已确认 ${Math.round(width)}x${Math.round(height)}`;
  }

  /**
   * Measured rectangle the video Surface is laid out at.
   *
   * Every input is an ArkUI-observed field. `viewportModel` is a plain object,
   * so its internal geometry mutations do not invalidate XComponent layout;
   * using the observed mirrors makes the first viewport/display report resize
   * the initial Surface without waiting for a display-mode toggle.
   */
  private previewSurfaceSize(): RustDeskSize {
    const display = this.currentDisplayIndex >= 0 && this.currentDisplayIndex < this.peerDisplays.length
      ? this.peerDisplays[this.currentDisplayIndex]
      : undefined;
    return computeSurfaceGeometry(
      this.previewDisplayMode,
      display === undefined ? 0 : display.width,
      display === undefined ? 0 : display.height,
      this.previewViewWidth,
      this.previewViewHeight,
      this.getUIContext().vp2px(1),
    );
  }

  /**
   * Fit of the RGBA fallback picture.
   *
   * The fallback draws in the view rather than in the native Surface, so it has
   * to follow the same control instead of its own fixed choice.
   */
  private previewFallbackFit(): ImageFit {
    if (this.previewDisplayMode === 'stretch') {
      return ImageFit.Fill;
    }
    return this.previewDisplayMode === 'original' ? ImageFit.None : ImageFit.Contain;
  }

  /**
   * Changes how the remote frame is fitted.
   *
   * The surface re-measures on its own, but the renderer is only told the new
   * rectangle from `applyDisplayConfiguration`, and that call skips its work
   * when the display and video size are unchanged -- which is exactly the case
   * here. The applied geometry is therefore invalidated first.
   */
  private selectPreviewDisplayMode(mode: RustDeskDisplayMode): void {
    if (this.previewDisplayMode === mode) {
      return;
    }
    this.previewDisplayMode = mode;
    this.lastAppliedDisplay = -1;
    this.lastAppliedVideoWidth = 0;
    this.lastAppliedVideoHeight = 0;
    this.applyDisplayConfiguration();
    this.reprojectVirtualCursorOverlay();
  }

  private applyDisplayConfiguration(): void {
    if (!this.activeSessionId || this.peerDisplays.length === 0) {
      return;
    }
    // Input is mapped through the rectangle the picture occupies, which is the
    // mode's own rectangle, and through the clip of whichever presentation is on
    // screen, so the model is told both before it is read.
    this.viewportModel.setDisplayMode(this.previewDisplayMode);
    this.viewportModel.setFallbackPresentation(this.previewFramePixelMap !== undefined && this.rgbaFallbackActive);
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

  private createPreviewSurfaceController(
    generation: number,
    sessionId: string,
  ): RustDeskSurfaceController {
    const controller = new RustDeskSurfaceController();
    const nodeId = `rustdesk-preview-surface-${generation.toString()}`;
    controller.onAttached = (): void => this.adoptPreviewSurfaceComponent(nodeId, controller);
    controller.onDetached = (): void => this.detachPreviewSurfaceComponent(controller.adoptedComponentId);
    controller.onCreated = (surfaceId: string): void =>
      this.handlePreviewSurfaceCreated(surfaceId, generation, sessionId);
    controller.onChanged = (surfaceId: string, rect: SurfaceRect): void =>
      this.handlePreviewSurfaceChanged(surfaceId, rect, generation, sessionId);
    controller.onDestroyed = (surfaceId: string): void =>
      this.handlePreviewSurfaceDestroyed(surfaceId, generation, sessionId);
    return controller;
  }

  private isCurrentPreviewSurface(generation: number, sessionId: string): boolean {
    return generation === this.previewSurfaceGeneration
      && sessionId.length > 0
      && sessionId === this.activeSessionId;
  }

  private handlePreviewSurfaceCreated(surfaceId: string, generation: number, sessionId: string): void {
    setTimeout(() => {
      if (!this.isCurrentPreviewSurface(generation, sessionId)
        || !this.showPreviewModal || !this.previewSurfaceVisible) {
        return;
      }
      this.previewSurfaceId = surfaceId;
      this.previewSurfaceDestroyAuthorized = false;
      this.frameStatus = `Surface created ${surfaceId}`;
      this.declarePanelFrameRate();
      this.syncSurfaceBinding();
    }, 0);
  }

  private recoverPreviewSurfaceIdFromController(): void {
    if (this.previewSurfaceId.length > 0 || !this.showPreviewModal || !this.previewSurfaceVisible) {
      return;
    }
    try {
      const surfaceId = this.previewController.getSurfaceId();
      if (surfaceId.length > 0) {
        this.previewSurfaceId = surfaceId;
        this.frameStatus = `Surface recovered ${surfaceId}`;
      }
    } catch (_error) {
      // Surface 尚未创建完成，等待正式生命周期回调。
    }
  }

  private handlePreviewSurfaceChanged(
    surfaceId: string,
    rect: SurfaceRect,
    generation: number,
    sessionId: string,
  ): void {
    setTimeout(() => {
      if (!this.isCurrentPreviewSurface(generation, sessionId) || surfaceId !== this.previewSurfaceId) {
        return;
      }
      this.frameWidth = rect.surfaceWidth;
      this.frameHeight = rect.surfaceHeight;
      this.viewportModel.setSurfaceSize(rect.surfaceWidth, rect.surfaceHeight);
      this.frameStatus = `Surface ready ${rect.surfaceWidth}x${rect.surfaceHeight}`;
      // The node exists from here on, which is what the panel expectation needs.
      this.declarePanelFrameRate();
      this.applyDisplayConfiguration();
      this.reprojectVirtualCursorOverlay();
    }, 0);
  }

  private handlePreviewSurfaceDestroyed(surfaceId: string, generation: number, sessionId: string): void {
    setTimeout(() => {
      // The pane is identified by its generation: a stale callback from an older
      // component must not touch the current one, and the session the pane serves
      // is the one captured when it was created.
      if (generation !== this.previewSurfaceGeneration || sessionId.length === 0) {
        return;
      }
      const authorized = this.previewSurfaceDestroyAuthorized;
      this.previewSurfaceDestroyAuthorized = false;
      this.inputController?.releasePressedButtons();
      if (!authorized) {
        // The native holder already revoked admission and requested this viewer's
        // close when its Surface was destroyed, and this bridge exports no destroy
        // notification. Nothing here is a release or an ACK: the session's own
        // close/poll/ACK order settles it, and the holder id stays on the
        // controller until a detach really answers released:true.
        hilog.warn(DOMAIN, TAG,
          'surface destroyed without a confirmed release session=%{public}s surface=%{public}s component=%{public}s',
          sessionId, surfaceId,
          this.previewController.adoptedComponentId.length > 0
            ? this.previewController.adoptedComponentId : '-');
      }
      if (surfaceId !== this.previewSurfaceId) {
        return;
      }
      this.previewSurfaceId = '';
      this.frameWidth = 0;
      this.frameHeight = 0;
      this.viewportModel.setSurfaceSize(0, 0);
      this.frameStatus = 'Surface destroyed';
    }, 0);
  }

  private syncSurfaceBinding(refreshAfterBind: boolean = true): boolean {
    if (!this.activeSessionId) {
      return false;
    }
    if (this.previewComponentId.length === 0) {
      // The third argument is the opaque componentId xcomponentAttach allocated on
      // this UI environment. An empty string is the give-back request, so it is
      // never sent from here, and no node label or Surface id is substituted.
      this.previewSurfaceBindFailure = '没有已接管的原生 XComponent holder（componentId 为空）';
      return false;
    }
    try {
      const response = this.parseResponse(native.sessionBindSurface(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
        this.previewComponentId,
        this.activeSessionLifecycleEpoch
      ));
      this.updateSessionState(response);
      if (!response.ok) {
        // A bind refusal carries only this message, so it is kept verbatim for the
        // caller to render instead of being replaced by a guessed reason.
        this.previewSurfaceBindFailure = response.message ?? '';
        hilog.warn(DOMAIN, TAG, 'surface bind refused session=%{public}s message=%{public}s',
          this.activeSessionId, this.previewSurfaceBindFailure);
        return false;
      }
      this.setSessionVideoPaused(this.activeSessionId, false);
      const activeTab = this.remoteSessionTabsController.get(this.activeSessionId);
      if (activeTab !== undefined) {
        activeTab.paused = false;
        this.syncRemoteSessionTabs();
      }
      if (this.isInteractiveSessionActive()) {
        this.remoteInteractionReady = true;
        this.syncClipboardController();
        this.syncInputInterceptor();
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

  /**
   * Gives the Surface back to the native side.
   *
   * Returns whether the destination was really released. A destination whose
   * producer still owes a join stays held: the native side keeps it, the
   * component must not be destroyed, and the caller keeps polling instead of
   * being told a release happened.
   */
  private clearSurfaceBinding(): boolean {
    if (!this.activeSessionId) {
      return true;
    }
    // A give-back carries no componentId: it asks this session's own record to
    // drop its destination. Whether that happened is read from released below,
    // never from an id the UI still happens to hold.
    try {
      const response = this.parseResponse(native.sessionBindSurface(
        this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex(),
        '',
        this.activeSessionLifecycleEpoch
      ));
      this.updateSessionState(response);
      if (response.released !== true) {
        // Only an explicit released:true clears the local destination. A held
        // holder or an unproven answer keeps it, so the next give-back is still
        // possible and no release is claimed without a receipt.
        hilog.warn(DOMAIN, TAG,
          'surface give-back not released session=%{public}s ok=%{public}s held=%{public}s surfaces=%{public}d message=%{public}s',
          this.activeSessionId, String(response.ok === true), String(response.held === true),
          (response.surfaces ?? []).length, response.message ?? '');
        return false;
      }
      this.previewSurfaceId = '';
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'surface give-back failed session=%{public}s error=%{public}s',
        this.activeSessionId, String(error));
      return false;
    }
  }

  /**
   * Adopts the engine input generation the viewer published in this poll.
   *
   * The viewer refuses input carrying a stale generation, so the value must come
   * from the poll that just proved the session is alive on that generation; it is
   * never derived from a local counter.
   */
  private adoptInputGeneration(response: ActionResponse): void {
    // The owed-hold count travels with the same answers as the generation and is
    // adopted whenever native names one: an absent value is unknown, never zero.
    const holdsOwed = response.session?.inputHoldsOwed ?? response.inputHoldsOwed;
    if (holdsOwed !== undefined) {
      this.activeInputHoldsOwed = holdsOwed;
    }
    const generation = response.session?.inputGeneration ?? response.inputGeneration;
    if (generation === undefined || generation.length === 0) {
      return;
    }
    this.activeInputGeneration = generation;
    const tab = this.remoteSessionTabsController.get(this.activeSessionId);
    if (tab !== undefined) {
      tab.inputGeneration = generation;
    }
  }

  /**
   * The generation to send with this session's input, or `undefined` while the
   * session has not reported one yet.
   *
   * Every kind sends the value the native side itself published — a poll's
   * `session.inputGeneration` or an input refusal's `inputGeneration` — because
   * Main ruled that a cached older generation being refused after a permission
   * flip is the correct boundary, not a lost event to be avoided by naming the
   * call-time live generation. Nothing is ever derived locally: before the first
   * native value the generation is simply not sent, and a refusal's value is
   * adopted for the next (new) event; a refused event is never replayed.
   */
  private currentInputGeneration(): string | undefined {
    return this.activeInputGeneration.length > 0 ? this.activeInputGeneration : undefined;
  }

  private updateSessionState(response: ActionResponse): void {
    if (response.session) {
      this.activeSessionId = response.session.sessionId;
      this.activeCoreSessionId = response.session.coreSessionId ?? '';
      this.sessionPhase = response.session.phase;
      const epoch = response.session.lifecycleEpoch;
      if (epoch !== undefined && epoch.length > 0) {
        this.activeSessionLifecycleEpoch = epoch;
        const activeTab = this.remoteSessionTabsController.get(response.session.sessionId);
        if (activeTab !== undefined) {
          activeTab.lifecycleEpoch = epoch;
        }
      }
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
      // A Core session is the only wire this client can ask for a capture rate:
      // the direct VNC/RDP wires have no rate control, so the request is not sent
      // there at all rather than being refused into the session's error state.
      if (this.activeSessionKind === 'remote_control'
        && this.sessionDisplayController.applyRefreshRate(
          this.activeSessionId,
          this.selectedRefreshRate,
        )) {
        this.selectedRefreshRate = this.sessionDisplayController.getRefreshRate();
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
    if (this.isDirectWireSession()) {
      // The engine owns a direct wire's codec, and the codec-preference call is
      // the Core's own option store: on these wires it is refused by name, and
      // reporting that refusal as a preference that failed to apply would be a
      // false operation. Nothing is asked for and nothing is claimed.
      this.codecPreferenceApplied = true;
      this.logRelativeDebug('codec_preference', `skipped kind=${this.activeSessionKind}`);
      return;
    }
    try {
      const response = this.parseResponse(native.sessionSetCodecPreference(this.activeSessionId, this.preferredCodec));
      // The answer carries the value the Core's own option store holds, not an echo
      // of the request: a mismatch is the native side's own refusal, and a real
      // failure is kept visible and retried after the connection is up rather than
      // being reported as applied.
      this.codecPreferenceApplied = response.ok;
      this.logRelativeDebug('codec_preference',
        `ok=${response.ok} requested=${this.preferredCodec} stored=${String(response.codec ?? '')} storedFlag=${String(response.stored === true)} coreAccepted=${String(response.coreAccepted === true)} message=${String(response.message ?? '')}`);
      if (!response.ok && response.stored === true && response.coreAccepted === false) {
        // The preference was verified in the Core's own option store, so it is what
        // the next handshake carries; only the re-advertisement was refused now.
        // That is a notice, not a failure of the operator's action, and the
        // post-connection retry below still runs.
        this.showSessionNotice(
          `偏好已保存，连接建立后将重新通告（原因：${response.message ?? '原生层未接受本次通告'}）`,
        );
      } else if (!response.ok && response.stored !== true) {
        // The Core did not store the preference, so it is not in force for the next
        // handshake; the session still starts on the peer's own default.
        this.showSessionNotice(
          `编码偏好未生效（${response.message ?? '原生层未保存该值'}）`,
        );
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
    this.adoptInputGeneration(response);
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
    if ((this.activeSessionId.length === 0 && this.remoteSessionTabsController.count() === 0)
      || this.eventPollInFlight) {
      return;
    }
    this.eventPollInFlight = true;
    try {
      const tabs = this.remoteSessionTabsController.snapshot();
      const pollBackgroundSessions = Date.now() - this.lastBackgroundSessionPollAt
        >= BACKGROUND_SESSION_POLL_INTERVAL_MS;
      if (pollBackgroundSessions) {
        this.lastBackgroundSessionPollAt = Date.now();
      }
      for (const tab of tabs) {
        if (tab.sessionId === this.activeSessionId) {
          const rawPoll = native.sessionPollEvents(tab.sessionId, 20);
          const response = this.parseResponse(rawPoll);
          this.updateSessionState(response);
          this.adoptInputGeneration(response);
          tab.coreSessionId = response.session?.coreSessionId ?? tab.coreSessionId;
          tab.phase = response.session?.phase ?? tab.phase;
          tab.connected = tab.phase === 'connected';
          const events = (response.events ?? []) as NativeEvent[];
          if (response.closed_externally === true) {
            this.noteExternallyClosedSession(tab.sessionId, response.settle ?? '');
          } else {
            const certificateEvent = events.find((event: NativeEvent): boolean => event.name === 'certificate_untrusted');
            if (certificateEvent !== undefined) {
              this.openRdpCertificateDialog(certificateEvent);
            }
            if (this.rdpCertificateRejectedSessions.has(tab.sessionId)) {
              continue;
            }
          }
          // A direct wire names its own failure in this envelope, and the close
          // event it sends in the same answer is the only thing that would
          // otherwise reach the operator as the generic "connection ended"
          // wording. It is read from the raw answer, and only when that answer
          // could end the session, so the ordinary poll pays nothing for it.
          if (!response.ok || events.some((event: NativeEvent) => event.name === 'close')) {
            this.noteDirectWireFailure(rawPoll, response, tab.kind, tab.sessionId);
          }
          if (!response.ok) {
            this.closeRemoteAudio();
            const directFailure = isDirectWireKind(tab.kind) ? this.directWireFailureFor(tab.sessionId) : '';
            if (directFailure.length > 0) {
              this.handleRemoteDisconnect(directFailure);
            }
            continue;
          }
          if (!this.isRemoteAudioSessionActive()) {
            this.closeRemoteAudio();
          }
          if (events.length > 0) {
            hilog.info(DOMAIN, TAG, 'pollSessionEvents count=%{public}d phase=%{public}s engine=%{public}s',
              events.length, this.sessionPhase, tab.phase);
          }
          // The batch's own names are logged by `logEventBatch` below. The raw
          // envelope is not: it can carry clipboard text and file paths, and the
          // direct wire's failure text is already read out by `noteDirectWireFailure`.
          this.logEventBatch(events, 'poll');
          this.logCursorEventBatch(events, 'poll');
          events.forEach((event: NativeEvent) => this.handleSessionEvent(event));
        } else if (pollBackgroundSessions) {
          this.pollBackgroundSessionEvents(tab);
        }
      }
      this.pollInputInterceptorEvents();
      if (this.isRemoteControlSessionActive()) {
        this.ensureRemoteCursorEnabled();
      }
      this.pollFrameRateTelemetry();
      this.syncRemoteSessionTabs();
    } catch (error) {
      this.errorText = String(error);
      hilog.error(DOMAIN, TAG, 'pollSessionEvents failed sessionId=%{public}s error=%{public}s', this.activeSessionId, this.errorText);
    } finally {
      this.eventPollInFlight = false;
    }
  }

  private pollFrameRateTelemetry(): void {
    if (!this.isInteractiveSessionActive() || this.activeSessionId.length === 0) {
      this.frameRateTelemetry.reset();
      this.qualityTelemetry = clearQualityFrameMetrics(this.qualityTelemetry);
      return;
    }
    const binding = `${this.activeSessionId}:${this.activeCoreSessionId}`;
    if (!this.frameRateTelemetry.shouldRead(binding, Date.now())) {
      return;
    }
    try {
      const display = this.viewportModel.getCurrentDisplayIndex();
      const raw = this.nativeSessionBridge.getFrameRateSnapshot(this.activeSessionId, display);
      const snapshot = this.frameRateTelemetry.sample(raw, display);
      hilog.info(DOMAIN, TAG, 'frame_rate_sample raw=%{public}s', raw);
      if (this.frameRateTelemetry.consumeFrameReset()) {
        this.qualityTelemetry = clearQualityFrameMetrics(this.qualityTelemetry);
      }
      if (snapshot !== undefined) {
        const requestedFps = Number.isFinite(this.selectedRefreshRate) && this.selectedRefreshRate > 0
          ? String(Math.round(this.selectedRefreshRate)) : '';
        // Replace the value so the toolbar and open quality sheet both update.
        this.qualityTelemetry = applyFrameRateSnapshot(this.qualityTelemetry, snapshot, requestedFps);
      }
      // The system panel rate is independent of requested and submitted FPS.
      const panel = this.currentPanelRefreshRate();
      if (panel !== this.panelRefreshRate) {
        hilog.info(DOMAIN, TAG, 'panel_refresh_rate changed %{public}d -> %{public}d', this.panelRefreshRate, panel);
      }
      this.panelRefreshRate = panel;
    } catch (error) {
      this.frameRateTelemetry.reset();
      this.qualityTelemetry = clearQualityFrameMetrics(this.qualityTelemetry);
      hilog.warn(DOMAIN, TAG, 'frame rate sample failed: %{public}s', String(error));
    }
  }


  private pollBackgroundSessionEvents(tab: RemoteSessionTab): void {
    const response = this.parseResponse(native.sessionPollEvents(tab.sessionId, 20));
    const backgroundGeneration = response.session?.inputGeneration ?? response.inputGeneration;
    if (backgroundGeneration !== undefined && backgroundGeneration.length > 0) {
      tab.inputGeneration = backgroundGeneration;
    }
    if (response.session !== undefined) {
      tab.coreSessionId = response.session.coreSessionId ?? tab.coreSessionId;
      tab.phase = response.session.phase;
      tab.connected = tab.phase === 'connected';
    }
    const events = (response.events ?? []) as NativeEvent[];
    if (response.closed_externally === true) {
      this.noteExternallyClosedSession(tab.sessionId, response.settle ?? '');
    } else {
      const certificateEvent = events.find((event: NativeEvent): boolean => event.name === 'certificate_untrusted');
      const challenge = certificateEvent === undefined ? undefined : rdpCertificateChallengeFromEvent(certificateEvent);
      if (certificateEvent !== undefined && challenge !== undefined &&
        this.certificateEventMatchesSession(challenge, tab.sessionId) &&
        !this.rdpCertificateRejectedSessions.has(tab.sessionId)) {
        this.rdpCertificateRejectedSessions.add(tab.sessionId);
        this.remoteSessionTabsController.markPhase(tab.sessionId, 'failed',
          this.certificateMessage($r('app.string.rdp_certificate_waiting')));
        this.remoteSessionTabsController.enqueue(tab.sessionId, certificateEvent, true);
      }
      if (this.rdpCertificateRejectedSessions.has(tab.sessionId)) {
        return;
      }
    }
    if (!response.ok) {
      this.forgetRdpCertificateCredentials(tab.sessionId);
      tab.needsAttention = true;
      tab.message = response.message ?? '后台会话不可用';
      return;
    }
    for (const event of events) {
      if (event.name === 'peer_info' || event.name === 'sync_peer_info') {
        this.forgetRdpCertificateCredentials(tab.sessionId);
        this.remoteSessionTabsController.markPeerInfo(tab.sessionId, event);
        this.setSessionVideoPaused(tab.sessionId, true);
        this.nativeSessionBridge.setRemoteAudioMuted(tab.sessionId, true);
        continue;
      }
      if (event.name === 'rgba') {
        native.sessionNextRgba(tab.sessionId, Number(event.display ?? 0));
        continue;
      }
      if (event.name === 'clipboard_multi') {
        if (isDirectWireKind(tab.kind)) {
          // A direct wire's take is non-consuming and its notification arrives once
          // per peer revision, so the fact is kept for activation: discarding it
          // here would lose the text the peer copied while this tab was in the
          // background, and no later notification would bring it back.
          this.clipboardPeerUpdateSessions.add(tab.sessionId);
        }
        const clipboard = this.nativeSessionBridge.takeClipboard(tab.sessionId);
        if (clipboard.image !== undefined && clipboard.image !== null) {
          this.nativeSessionBridge.takeClipboardImage(tab.sessionId);
        }
        continue;
      }
      if (event.name === 'cursor_data' || event.name === 'cursor_id') {
        this.remoteSessionTabsController.cacheCursorEvent(tab.sessionId, event);
        continue;
      }
      if (event.name === 'clipboard' || event.name === 'clipboard_files'
        || event.name === 'clipboard_write_result'
        || event.name === 'cursor_position' || event.name === 'update_quality_status') {
        continue;
      }
      if (event.name === 'close') {
        this.forgetRdpCertificateCredentials(tab.sessionId);
        this.remoteSessionTabsController.markPhase(tab.sessionId, 'closed', '远端连接已结束');
        this.remoteSessionTabsController.enqueue(tab.sessionId, event, true);
        continue;
      }
      const needsAttention = event.name === 'msgbox' || event.name === 'switch_display'
        || event.name === 'resolution_refused';
      this.remoteSessionTabsController.enqueue(tab.sessionId, event, needsAttention);
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

  /**
   * Remembers what one direct poll envelope said went wrong.
   *
   * The engine reports a direct wire's own cause in the envelope's `error` field,
   * and a refusal of the poll itself in `message`; both are kept as they arrived
   * rather than reworded, because this text is the whole cause the operator can
   * be given. Only the session that is actually in front is read and written, so a
   * background tab's poll can neither overwrite the active session's cause nor
   * leave its own behind for a later session to claim.
   */
  private noteDirectWireFailure(rawPoll: string, response: ActionResponse, kind: string, sessionId: string): void {
    if (!isDirectWireKind(kind) || sessionId.length === 0 || sessionId !== this.activeSessionId) {
      return;
    }
    const reported = this.pollEnvelopeError(rawPoll);
    if (reported.length > 0) {
      this.directWireFailureText = reported;
      this.directWireFailureSessionId = sessionId;
      hilog.warn(DOMAIN, TAG, 'direct wire reported a failure: %{public}s', reported);
      return;
    }
    const message = (response.message ?? '').trim();
    if (!response.ok && message.length > 0) {
      this.directWireFailureText = message;
      this.directWireFailureSessionId = sessionId;
      hilog.warn(DOMAIN, TAG, 'direct poll refused: %{public}s', message);
    }
  }

  /** Forgets the failure text held for whichever session reported it. */
  private clearDirectWireFailure(): void {
    this.directWireFailureText = '';
    this.directWireFailureSessionId = '';
  }

  /** The failure held for one session, or `''` when it belongs to another. */
  private directWireFailureFor(sessionId: string): string {
    if (sessionId.length === 0 || this.directWireFailureSessionId !== sessionId) {
      return '';
    }
    return this.directWireFailureText;
  }

  /**
   * The `error` one poll answer carried, read from the raw envelope.
   *
   * The typed response this client parses does not model that field, and the
   * envelope is the only place the engine's own wording for a direct wire lives,
   * so it is read here once instead of being guessed from a generic phase.
   */
  private pollEnvelopeError(rawPoll: string): string {
    try {
      const envelope: ESObject = JSON.parse(rawPoll);
      const reported: ESObject = envelope.error;
      if (typeof reported === 'string' && (reported as string).trim().length > 0) {
        return (reported as string).trim();
      }
      return '';
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'poll envelope error read failed: %{public}s', String(error));
      return '';
    }
  }

  /**
   * What one close really was, in the terms the operator can act on.
   *
   * A direct wire reports its own cause, and that text is shown; a session that
   * ended without naming one keeps the generic wording.
   */
  private closeReasonForActiveSession(): string {
    if (this.isDirectWireSession()) {
      const reported = this.directWireFailureFor(this.activeSessionId);
      if (reported.length > 0) {
        return reported;
      }
    }
    return '远端连接已结束';
  }

  private handleSessionEvent(event: NativeEvent): void {
    if (event.name === 'certificate_untrusted') {
      this.openRdpCertificateDialog(event);
      return;
    }
    if (event.name === 'close') {
      if (this.rdpCertificateRejectedSessions.has(this.activeSessionId)) {
        return;
      }
      const reason = this.closeReasonForActiveSession();
      this.remoteSessionTabsController.markPhase(this.activeSessionId, 'closed', reason);
      this.syncRemoteSessionTabs();
      this.handleRemoteDisconnect(reason);
      return;
    }
    if (event.name === 'permission') {
      if (event.keyboard !== undefined) {
        const keyboardPermission = String(event.keyboard).trim().toLowerCase();
        if (keyboardPermission === 'false') {
          this.remoteKeyboardPermissionAllowed = false;
          this.hideSystemIme(false);
          this.hideSoftKeyboard();
        } else if (keyboardPermission === 'true') {
          this.remoteKeyboardPermissionAllowed = true;
        }
      }
      return;
    }
    if (event.name === 'exit_relative_mouse_mode') {
      if (this.relativeMouseMode) {
        this.relativeMouseMode = false;
        this.syncRelativeMouseMode(false);
        this.sessionMessage = '远端已退出相对指针模式';
      }
      return;
    }
    if (event.name === 'connection_ready') {
      if (this.activeSessionKind === 'rdp') {
        this.forgetRdpCertificateCredentials(this.activeSessionId);
      }
      this.connectionSummary = `secure=${String(event.secure)}, direct=${String(event.direct)}, stream=${String(event.stream_type)}`;
      if (this.connectionUiPhase === 'connecting' || this.connectionUiPhase === 'authenticating') {
        const secure = String(event.secure).trim().toLowerCase() === 'true';
        this.connectionUiMessage = secure
          ? '安全通道已建立，正在读取远端会话信息。'
          : '传输通道已建立，正在等待安全确认。';
      }
      if (this.isRemoteControlSessionActive()) {
        this.ensureRemoteCursorEnabled();
      }
      this.performanceTuningApplied = false;
      return;
    }
    if (event.name === 'audio_capability') {
      if (this.activeSessionKind === 'rdp' && event.audio !== undefined) {
        this.directAudioCapability = event.audio;
        this.refreshRemoteAudioState();
      }
      return;
    }
    if (event.name === 'resolution_refused') {
      if (matchesResolutionRefusal(event, this.pendingResolutionDisplay,
        this.pendingResolutionWidth, this.pendingResolutionHeight)) {
        this.pendingResolutionDisplay = -1;
        this.pendingResolutionWidth = 0;
        this.pendingResolutionHeight = 0;
        this.clearRdpFollowResize();
      }
      this.sessionMessage = event.message ?? '';
      return;
    }
    if (event.name === 'peer_info' || event.name === 'sync_peer_info') {
      this.forgetRdpCertificateCredentials(this.activeSessionId);
      if (this.activeSessionKind === 'rdp' && event.audio !== undefined) {
        this.directAudioCapability = event.audio;
        this.refreshRemoteAudioState();
      }
      this.clearConnectionTimeout();
      this.dismissPasswordDialogFor('primary');
      this.errorText = '';
      this.connectionUiPhase = 'connected';
      this.connectionUiMessage = '连接成功，正在准备远端画面。';
      this.sessionPhase = 'connected';
      this.remoteSessionTabsController.markPeerInfo(this.activeSessionId, event);
      const activeTab = this.remoteSessionTabsController.get(this.activeSessionId);
      if (activeTab !== undefined) {
        activeTab.coreSessionId = this.activeCoreSessionId;
        activeTab.message = '已连接';
      }
      this.syncRemoteSessionTabs();
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
      if (this.isInteractiveSessionActive()) {
        this.remoteInteractionReady = this.showPreviewModal
          && this.previewSurfaceVisible
          && this.previewSurfaceId.length > 0;
        if (this.relativeMouseMode && !this.relativeMouseModeSupported()) {
          this.relativeMouseMode = false;
          this.sessionMessage = '当前远端不支持相对指针模式，已使用普通指针';
        }
        this.syncTouchMode(this.touchMode);
        this.syncRelativeMouseMode(this.relativeMouseMode);
        // The show-remote-cursor option is a Core toggle: a direct wire's cursor is
        // the engine's own, and the native layer refuses this request on one.
        if (this.isRemoteControlSessionActive()) {
          this.ensureRemoteCursorEnabled();
        }
      }
      if (!this.showPreviewModal || !this.previewSurfaceVisible) {
        this.enterPreviewMode(event);
      } else {
        this.configureDisplayFromPeerInfo(event);
      }
      if (event.name === 'peer_info') {
        this.rememberConnectedDevice(event);
        this.refreshDirectorySnapshot();
      }
      this.scheduleRdpFollowResize();
      return;
    }
    if (event.name === 'switch_display') {
      this.handleSwitchDisplayConfirmation(event);
      return;
    }
    if (event.name === 'update_quality_status') {
      this.qualityTelemetry = mergeQualityStatus(this.qualityTelemetry, {
        speed: event.speed ?? '',
        delay: event.delay ?? '',
        targetBitrate: event.target_bitrate ?? '',
        codec: event.codec_format ?? '',
      });
      return;
    }
    if (event.name === 'rgba' || event.name === 'texture') {
      this.handleFrameTransportEvent(event);
      return;
    }
    if (event.name === 'cursor_data') {
      this.remoteSessionTabsController.cacheCursorEvent(this.activeSessionId, event);
      this.updateRemoteCursorData(event);
      return;
    }
    if (event.name === 'cursor_id') {
      this.remoteSessionTabsController.cacheCursorEvent(this.activeSessionId, event);
      this.updateRemoteCursorId(event);
      return;
    }
    if (event.name === 'cursor_position') {
      this.updateCursorOverlayFromRemote(Number(event.x ?? '0'), Number(event.y ?? '0'));
      return;
    }
    if (event.name === 'clipboard') {
      if (this.isClipboardTextSyncAllowed()) {
        this.clipboardController?.applyRemoteText(this.activeSessionId, String(event.content ?? ''));
      }
      return;
    }
    if (event.name === 'clipboard_multi') {
      if (this.isClipboardTextSyncAllowed() && this.remoteInteractionReady) {
        this.applyRemoteNativeClipboard();
      } else if (this.isDirectWireSession() && this.isClipboardTextAdmitted()) {
        // Policy admits this session, but it is not usable right now — the app is not
        // in front, or its preview is not ready. The notification arrives once per
        // peer revision and the direct wire keeps the text in its own mailbox, so the
        // fact is remembered instead of handing the payload to a controller that is
        // not running: the newest text is retrieved when this session is admitted and
        // ready again, before its own local clipboard is read. Only a notification
        // consumed here is marked — work dropped at a lifecycle boundary stays
        // dropped, and a policy refusal is not marked at all.
        this.clipboardPeerUpdateSessions.add(this.activeSessionId);
      }
      return;
    }
    if (event.name === 'clipboard_write_result') {
      this.handleClipboardWriteResult(event);
      return;
    }
    if (event.name === 'clipboard_files') {
      if (this.clipboardSyncEnabled && this.isRemoteControlSessionActive()
        && event.paths !== undefined && event.paths.length > 0) {
        this.clipboardController?.applyRemoteClipboard(this.activeSessionId, { files: event.paths });
      }
      return;
    }
    if (event.name === 'msgbox') {
      this.handleMsgBoxEvent(event);
    }
  }

  private handleMsgBoxEvent(event: NativeEvent): void {
    if (this.rdpCertificateRejectedSessions.has(this.activeSessionId)) {
      return;
    }
    const title = String(event.title ?? '');
    const text = String(event.text ?? '');
    const type = String(event.type ?? '');
    const message = title.length > 0 ? `${title}: ${text}` : text;
    if (type.includes('insecure-connection')) {
      this.openInsecureConnectionDialog(text);
      return;
    }
    if (type === 'success' || title === 'Successful') {
      this.sessionMessage = message;
      this.errorText = '';
      return;
    }
    if (type === 'input-password' || type === 're-input-password') {
      const errorMsg = type === 're-input-password' ? '密码错误，请重新输入' : '';
      this.connectionSummary = '等待密码验证';
      this.errorText = message;
      if (this.isDirectWireSession()) {
        // A direct viewer consumes its credential when it dials; a password that
        // arrives now cannot reach that handshake, and the native side refuses a
        // login on a running viewer by name. The engine's own text is reported and
        // the wire is closed, so the operator retries into a fresh viewer with a
        // fresh prompt instead of a secret that would go nowhere.
        this.handleRemoteDisconnect(message.length > 0 ? message : '远端拒绝了凭据');
        return;
      }
      if (this.tryAutoSubmitHandoffPassword()) {
        return;
      }
      this.openPasswordDialog('primary', errorMsg, 'password');
      return;
    }
    if (type === 'input-2fa') {
      const errorMsg = (message.includes('wrong') || message.includes('Wrong') || message.includes('2fa-wrong'))
        ? '2FA 验证码错误或已过期，请重新输入'
        : '';
      this.connectionSummary = '等待二次验证 (2FA)';
      this.errorText = message;
      try {
        this.canTrustDevice = this.nativeSessionBridge.getEnableTrustedDevices(this.activeSessionId);
      } catch (error) {
        // Trust-device support is optional metadata. A stale/mismatched HAR
        // must never prevent the mandatory 2FA challenge from being shown.
        this.canTrustDevice = false;
        hilog.warn(
          DOMAIN,
          TAG,
          'sessionGetEnableTrustedDevices failed; continuing 2fa challenge: %{public}s',
          String(error),
        );
      }
      this.openPasswordDialog('primary', errorMsg, '2fa');
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

  private openInsecureConnectionDialog(text: string): void {
    if (this.activeSessionId.length === 0) {
      return;
    }
    // Every challenge the engine raises is answered for the session that raised
    // it: the Core holds the same policy per connection, and a stored acceptance
    // would let a later dial through without anyone answering for it.
    this.clearConnectionTimeout();
    this.insecureConnectionMessage = text === 'conn-e2ee-unavailable-tip'
      ? '无法验证端到端加密。远程设备可能仍在准备中，请稍后重试。如果此问题持续出现，服务器可能不受信任。仍要继续吗？'
      : text;
    this.insecureConnectionDialogVisible = true;
    this.insecureConnectionSessionId = this.activeSessionId;
    this.connectionUiPhase = 'authenticating';
    this.connectionUiMessage = '等待确认是否继续非安全连接。';
    this.sessionMessage = '等待非安全连接确认';
    this.errorText = '';
  }

  private continueInsecureConnection(): void {
    const sessionId = this.insecureConnectionSessionId;
    if (!this.insecureConnectionDialogVisible || sessionId.length === 0) {
      return;
    }
    this.applyInsecureContinuation(sessionId);
  }

  private applyInsecureContinuation(sessionId: string): void {
    if (sessionId !== this.activeSessionId) {
      this.insecureConnectionDialogVisible = false;
      this.insecureConnectionMessage = '';
      this.insecureConnectionSessionId = '';
      this.handleRemoteDisconnect('连接会话已结束，请重新连接');
      return;
    }
    try {
      // The native side reports whether the decision reached the viewer, so the
      // dialog is only cleared once the engine really took the key: a refused
      // key would otherwise show a confirmation the viewer never received.
      const outcome = this.nativeSessionBridge.setCommon(
        sessionId,
        'continue-insecure-connection',
        'Y',
      );
      this.logRelativeDebug('insecure_continue',
        `ok=${outcome.ok} action=${outcome.action} message=${outcome.message ?? ''}`);
      if (!outcome.ok) {
        throw new Error(outcome.message ?? '无法发送非安全连接确认');
      }
      this.insecureConnectionDialogVisible = false;
      this.insecureConnectionMessage = '';
      this.insecureConnectionSessionId = '';
      this.connectionUiPhase = 'connecting';
      this.connectionUiMessage = '已确认继续，正在等待远端会话信息。';
      this.sessionMessage = '正在继续非安全连接';
      this.scheduleConnectionTimeout();
    } catch (error) {
      this.errorText = `无法继续连接：${String(error)}`;
      if (this.insecureConnectionDialogVisible) {
        this.disconnectInsecureConnection();
      } else {
        // The dialog is already gone, so there is nothing left to close by hand:
        // end the session instead of leaving it waiting for a decision nobody
        // can make.
        this.rejectPendingInsecureConnection();
        void this.closeSession('无法继续非安全连接');
      }
    }
  }

  private disconnectInsecureConnection(): void {
    if (!this.insecureConnectionDialogVisible) {
      return;
    }
    this.rejectPendingInsecureConnection();
    void this.closeSession('已拒绝非安全连接');
  }

  private rejectPendingInsecureConnection(): void {
    if (!this.insecureConnectionDialogVisible) {
      return;
    }
    const sessionId = this.insecureConnectionSessionId;
    this.insecureConnectionDialogVisible = false;
    this.insecureConnectionMessage = '';
    this.insecureConnectionSessionId = '';
    if (sessionId.length === 0) {
      return;
    }
    try {
      this.nativeSessionBridge.setCommon(sessionId, 'continue-insecure-connection', 'N');
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'rejectPendingInsecureConnection failed: %{public}s', String(error));
    }
  }

  private tryAutoSubmitHandoffPassword(): boolean {
    if (!this.activeSessionPasswordEphemeral || this.activeSessionPassword.length === 0 ||
      this.handoffPasswordAutoSubmitAttempted || this.activeSessionId.length === 0) {
      return false;
    }
    this.handoffPasswordAutoSubmitAttempted = true;
    this.passwordSessionKind = 'primary';
    hilog.info(DOMAIN, TAG, 'retrying one-time handoff password automatically');
    void this.submitPassword(this.activeSessionPassword, false);
    return true;
  }

  private requestVideoRefresh(): void {
    if (!this.activeSessionId || this.sessionPhase !== 'connected') {
      return;
    }
    try {
      const response = this.nativeSessionBridge.refresh(this.activeSessionId,
        this.viewportModel.getCurrentDisplayIndex());
      if (this.isDirectWireSession() && response.ok) {
        if (response.requested === true) {
          this.sessionMessage = '已请求刷新画面，等待远端更新';
        } else {
          this.errorText = '原生未确认刷新请求已入队';
        }
      } else {
        this.updateSessionState(response);
      }
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
    // The fallback is the presentation no longer, so input goes back to the Surface's
    // own clip without waiting for the next display configuration pass.
    this.viewportModel.setFallbackPresentation(false);
    if (previous) {
      previous.release().catch((_error: BusinessError) => {});
    }
  }

  private updatePreviewFramePixelMap(pixelMap: image.PixelMap, width: number, height: number, display: number): void {
    const previous = this.previewFramePixelMap;
    this.previewFramePixelMap = pixelMap;
    this.rgbaFallbackActive = true;
    this.frameWidth = width;
    this.frameHeight = height;
    this.viewportModel.setSurfaceSize(width, height);
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
    } else {
      this.applyDisplayConfiguration();
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
    if (!this.isInteractiveSessionActive()) {
      return;
    }
    const payload = new RustDeskKeyPayload(name, false);
    payload.press = true;
    const sent = this.sendKeyPayloadObject(payload);
    this.logRelativeDebug('fold_keyboard_button', `name=${name} press=${sent}`);
    this.requestPreviewInputFocus();
  }

  @Builder
  private androidNavigationOverlay() {
    if (this.androidNavigationAvailable()) {
      Stack() {
        AndroidNavigationBar({
          collapsed: !this.androidNavigationVisible,
          onBack: () => this.sendAndroidBack(),
          onHome: () => this.sendAndroidHome(),
          onRecent: () => this.sendAndroidRecentApps(),
          onHide: () => this.setAndroidNavigationExpanded(!this.androidNavigationVisible),
        });
      }
      .width(this.androidNavigationOverlayWidth())
      .height(this.androidNavigationOverlayHeight())
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

  private activeRemoteSessionTab(): RemoteSessionTab | undefined {
    const activeId = this.remoteSessionTabsController.activeId();
    return this.remoteSessionTabs.find((tab: RemoteSessionTab): boolean => tab.sessionId === activeId)
      ?? this.remoteSessionTabs[0];
  }

  @Builder
  private remoteSessionResumeOverlay() {
    if (!this.showPreviewModal && !this.showTransferWorkspace && this.remoteSessionTabs.length > 0) {
      Row() {
        RemoteSessionResumeChip({
          sessionCount: this.remoteSessionTabs.length,
          label: this.activeRemoteSessionTab()?.label ?? '远程会话',
          needsAttention: this.remoteSessionTabs.some(
            (tab: RemoteSessionTab): boolean => tab.needsAttention,
          ),
          onResume: () => this.resumeRemoteSessionFromHome(),
        });
      }
      .width(this.isWideMainLayout() ? 230 : 196)
      .position({
        x: Math.max(
          this.windowCutoutLeftWidth + 8,
          this.mainViewportWidth - this.windowCutoutRightWidth - (this.isWideMainLayout() ? 246 : 208),
        ),
        y: Math.max(this.windowTopAvoidInset + 12, 14),
      })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .zIndex(140);
    }
  }

  @Builder
  remotePreviewPane() {
    Stack({ alignContent: Alignment.Top }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.previewSurfaceVisible) {
          Stack() {
            XComponent({
              type: XComponentType.SURFACE
            })
              .id(this.previewSurfaceNodeId())
              .onAttach(this.previewController.handleNodeAttach)
              .onDetach(this.previewController.handleNodeDetach)
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.black'))
              .scale({ x: this.previewUserScale, y: this.previewUserScale, centerX: '50%', centerY: '50%' })
              .rotate({ angle: this.previewUserRotation, centerX: '50%', centerY: '50%' })
              .translate({ x: this.previewUserOffsetX, y: this.previewUserOffsetY });
          }
          .width(this.previewSurfaceSize().width)
          .height(this.previewSurfaceSize().height)
          // `original` can exceed the pane, and a frame that hangs outside it
          // must not be drawn over the toolbar.
          .clip(true)
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
            .objectFit(this.previewFallbackFit())
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
        .focusOnTouch(!this.systemImeActive)
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
          this.viewportModel.setPixelDensity(this.getUIContext().vp2px(1));
          this.viewportModel.setViewportSize(width, height);
          this.updateAndroidNavigationViewport(width, height);
          this.reclampMiniBarAnchor();
          this.reclampSoftKeyboardPosition();
          this.applyDisplayConfiguration();
          this.reprojectVirtualCursorOverlay();
          this.scheduleRdpFollowResize();
        })
        .zIndex(10);

        if (this.systemImeAvailable()) {
          TextInput({
            text: this.systemImeText,
            controller: this.systemImeTextController,
          })
            .id(SYSTEM_IME_INPUT_FOCUS_ID)
            .type(InputType.Normal)
            .enterKeyType(EnterKeyType.NEW_LINE)
            .enablePreviewText(true)
            .enableKeyboardOnFocus(true)
            .selectionMenuHidden(true)
            .showUnderline(false)
            .fontColor($r('app.color.transparent'))
            .caretColor($r('app.color.transparent'))
            .backgroundColor($r('app.color.transparent'))
            .padding(0)
            .width(1)
            .height(1)
            .opacity(0.01)
            .position({ x: 0, y: 0 })
            .hitTestBehavior(HitTestMode.None)
            .focusable(true)
            .onFocus((): void => {
              this.clearSystemImeBlurTimer();
              if (this.systemImeActive) {
                this.systemImeTextController.caretPosition(this.systemImeText.length);
              }
            })
            .onBlur((): void => {
              this.scheduleSystemImeDeactivate();
            })
            .onEditChange((isEditing: boolean): void => {
              if (isEditing) {
                this.clearSystemImeBlurTimer();
              } else {
                this.scheduleSystemImeDeactivate();
              }
            })
            .onChange((value: string, previewText?: PreviewText, options?: TextChangeOptions): void => {
              this.handleSystemImeChange(value, previewText, options);
            })
            .onSubmit((_enterKey: EnterKeyType, event: SubmitEvent): void => {
              this.handleSystemImeSubmit(event);
            })
            .zIndex(11);
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
              // The latches the panel draws are the keys the engine accepted a
              // Down for, so a modifier the engine refused stays unlit and the
              // panel's toggle asks for the opposite of the state this page holds.
              altActive: this.softKeyboardAltActive,
              ctrlActive: this.softKeyboardCtrlActive,
              shiftActive: this.softKeyboardShiftActive,
              commandActive: this.softKeyboardCommandActive,
              onKey: (name: string, down: boolean): void => this.sendSoftKeyboardKey(
                name,
                down,
                this.softKeyboardAltActive,
                this.softKeyboardCtrlActive,
                this.softKeyboardShiftActive,
                this.softKeyboardCommandActive,
              ),
              onMoveDock: (): void => this.moveSoftKeyboardToOtherEdge(),
              onCollapse: (): void => this.toggleSoftKeyboard(),
              onKeyboardMoveStart: (): void => this.startSoftKeyboardDrag(),
              onKeyboardMoveUpdate: (offsetX: number, offsetY: number): void =>
                this.updateSoftKeyboardDrag(offsetX, offsetY),
              onKeyboardMoveEnd: (): void => this.finishSoftKeyboardDrag(),
            });
          }
          .width(this.softKeyboardWidth())
          .height(REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT)
          .position({ x: this.softKeyboardX, y: this.softKeyboardY })
          .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
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
        Column() {
          SessionToolbar({
            tabs: this.remoteSessionTabs,
            activeSessionId: this.remoteSessionTabsController.activeId(),
            canAddSession: this.remoteSessionTabsController.canAdd(),
            inputEnabled: this.inputEnabled,
            touchMode: this.touchMode,
            relativeMouseMode: this.relativeMouseMode,
            relativeModeSupported: this.relativeMouseModeSupported(),
            rightClickGesture: this.rightClickGesture,
            metrics: this.sessionToolbarMetrics(),
            statusMessage: this.errorText || this.sessionMessage,
            activeOverlayPanel: this.activeOverlayPanel,
            displayTransitionId: SESSION_OVERLAY_TRANSITION_DISPLAY,
            qualityTransitionId: SESSION_OVERLAY_TRANSITION_QUALITY,
            androidNavigationAvailable: this.androidNavigationAvailable(),
            androidNavigationVisible: this.androidNavigationVisible,
            softKeyboardAvailable: this.softKeyboardAvailable(),
            softKeyboardVisible: this.softKeyboardVisible,
            systemImeAvailable: this.systemImeAvailable(),
            systemImeActive: this.systemImeActive,
            audioAvailable: this.remoteAudioState.available,
            audioMuted: this.remoteAudioState.muted,
            directSession: this.isDirectWireSession(),
            audioUnavailableText: this.remoteAudioUnavailableText(),
            keyboardUnavailableText: this.remoteKeyboardUnavailableText(),
            windowUnavailableText: this.sessionWindowControlsAvailable() && this.sessionWindowFullscreenAvailable()
              ? '' : $r('app.string.direct_window_reason'),
            wideLayout: this.isInteractiveSessionActive() && this.previewViewWidth >= 700,
            transformSummary: this.previewTransformSummary(),
            canResetTransform: this.hasPreviewViewTransform(),
            panelContentHeight: this.sessionOverlayContentHeight(),
            windowControlsAvailable: this.sessionWindowControlsAvailable(),
            windowFullscreenAvailable: this.sessionWindowFullscreenAvailable(),
            windowFullscreen: this.sessionWindowFullscreen,
            windowControlBusy: this.sessionWindowControlBusy,
            refreshDisplayEnabled: this.sessionPhase === 'connected',
            onSelectInputMode: (mode: RustDeskInputMode) => this.setPointerMode(mode),
            onSelectRightClick: (gesture: RustDeskRightClickGesture) => this.setRightClickGesture(gesture),
            onResetTransform: () => this.resetPreviewViewTransform(),
            onAudioChange: (enabled: boolean) => this.setRemoteAudioEnabled(enabled),
            onOpenDisplay: () => this.openDisplaySheet(),
            onOpenQuality: () => this.openQualitySheet(),
            onRefreshDisplay: () => this.requestVideoRefresh(),
            onToggleSoftKeyboard: () => this.toggleSoftKeyboard(),
            onToggleSystemIme: () => this.toggleSystemIme(),
            onToggleAndroidNavigation: () => {
              const expanded = !this.androidNavigationVisible;
              if (expanded && this.previewViewWidth > 0 && this.previewViewHeight > 0) {
                if (this.androidNavigationX <= 0 && this.androidNavigationY <= 0) {
                  this.androidNavigationX = this.clampAndroidNavigationX(
                    (this.previewViewWidth - ANDROID_NAVIGATION_BAR_WIDTH) / 2,
                  );
                  this.androidNavigationY = this.clampAndroidNavigationY(
                    this.previewViewHeight - ANDROID_NAVIGATION_BAR_HEIGHT - ANDROID_NAVIGATION_BOTTOM_OFFSET,
                  );
                }
              }
              this.setAndroidNavigationExpanded(expanded);
            },
            onDisconnect: () => this.closeSession('已手动断开连接'),
            onCollapse: () => {
              // The tab is drawn from the anchor, so collapsing keeps the place.
              this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                this.isMiniBarExpanded = false;
              });
            },
            onToolbarMoveStart: () => this.startMiniBarDrag(),
            onToolbarMoveUpdate: (offsetX: number, offsetY: number): void =>
              this.updateMiniBarDrag(offsetX, offsetY),
            onChromeHeightChange: (height: number): void => {
              this.sessionToolbarChromeHeight = height;
            },
            onMinimizeWindow: () => this.minimizeSessionWindow(),
            onToggleWindowFullscreen: () => this.toggleSessionWindowFullscreen(),
            onSelectSession: (sessionId: string) => void this.switchRemoteSessionTab(sessionId),
            onCloseSession: (sessionId: string) => void this.closeRemoteSessionTab(sessionId),
            onAddSession: () => this.openNewRemoteSession(),
            content: () => {
              if (this.isOverlayPanelOpen('display')) {
                this.displayOverlayPanel();
              } else if (this.isOverlayPanelOpen('quality')) {
                this.qualityOverlayPanel();
              }
            },
          });
        }
        .width('100%')
        .padding(MINI_BAR_EXPANDED_PADDING)
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
        .shadow(ShadowStyle.OUTER_DEFAULT_MD);
      }
      .width(this.miniBarExpandedWidth())
      .position({ x: this.miniBarExpandedX(), y: this.miniBarExpandedY() })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.measureMiniBarExpandedHeight(Number(newArea.height));
      })
      // One transition, on the panel's root: the panel slides in from, and back
      // out to, the right edge it is anchored to. `move` is the framework's
      // edge-slide, so the travel is the panel's own distance to that edge and
      // it always clears it; a transform does not re-lay-out the page, and no
      // child repeats the direction (the children only fade).
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.END)))
      .zIndex(30);
    } else {
      Row() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Stack({ alignContent: Alignment.Center }) {
            Stack()
              .width(4)
              .height(36)
              .backgroundColor($r('app.color.neu_text_secondary'))
              .borderRadius(2)
              .opacity(0.72);

            if (this.rootFocusedControl === 'mini-toolbar') {
              Row()
                .width('100%')
                .height('100%')
                .border({ width: 2, color: $r('app.color.focus_ring') })
                .borderRadius({
                  topLeft: $r('app.float.radius_14'),
                  bottomLeft: $r('app.float.radius_14'),
                })
                .hitTestBehavior(HitTestMode.None);
            }
          }
          .width('100%')
          .height('100%');
        }
        .width(MINI_BAR_COLLAPSED_WIDTH)
        .height(MINI_BAR_COLLAPSED_HEIGHT)
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
          topLeft: $r('app.float.radius_14'),
          bottomLeft: $r('app.float.radius_14'),
        })
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .hoverEffect(HoverEffect.None)
        .focusOnTouch(true)
        .accessibilityText('展开远控工具栏')
        .onFocus(() => this.setRootControlFocused('mini-toolbar', true))
        .onBlur(() => this.setRootControlFocused('mini-toolbar', false))
        .onClick((): void => {
          // The panel is drawn from the anchor, so expanding never re-seats it.
          this.getUIContext()?.animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
            this.isMiniBarExpanded = true;
          });
        });
      }
      // The node is wider than the tab: the extra width is touch target, and the
      // tab itself stays flush with the anchor's right edge.
      .width(MINI_BAR_COLLAPSED_TOUCH_WIDTH)
      .height(MINI_BAR_COLLAPSED_HEIGHT)
      .justifyContent(FlexAlign.End)
      .position({ x: this.miniBarCollapsedX(), y: this.miniBarCollapsedY() })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 4 })
          .onActionStart((_event: GestureEvent): void => {
            this.startMiniBarDrag();
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.updateMiniBarDrag(event.offsetX, event.offsetY);
          }),
      )
      // The tab leaves and returns through the same right edge, so folding the
      // panel and unfolding it read as one motion.
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.END)))
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
          false,
          false,
          true,
          () => this.cyclePointerMode(),
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
        systemMaterialEffect: this.hdsMaterialAvailable ? {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        } : undefined,
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
        displays: this.peerDisplays,
        currentDisplay: this.pendingDisplayIndex >= 0
          ? this.pendingDisplayIndex
          : this.currentDisplayIndex,
        resolutions: this.supportedResolutions,
        selectedResolution: this.pendingResolutionWidth > 0 && this.pendingResolutionHeight > 0 ? {
          width: this.pendingResolutionWidth,
          height: this.pendingResolutionHeight,
        } : undefined,
        resolutionEnabled: this.sessionDisplayController.canChangeResolution(this.peerPlatform)
          && this.activeSessionKind !== 'vnc',
        resolutionUnavailableText: this.activeSessionKind === 'vnc'
          ? '桌面尺寸由 VNC 服务端决定，本机无法调整'
          : '远端 OHOS 暂不支持修改显示器分辨率',
        displayMode: this.previewDisplayMode,
        onSelectDisplayMode: (mode: RustDeskDisplayMode) => this.selectPreviewDisplayMode(mode),
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
        refreshRate: this.selectedRefreshRate,
        refreshRateChoices: this.refreshRateChoices,
        panelRefreshRate: this.panelRefreshRate,
        telemetry: this.qualityTelemetry,
        protocol: this.activeSessionKind === 'vnc' ? 'vnc' : (this.activeSessionKind === 'rdp' ? 'rdp' : 'rustdesk'),
        directDefaults: this.directQualityDefaults,
        actionMessage: this.errorText || this.sessionMessage,
        onDirectDefaultsChange: (defaults: SessionDefaults): void => this.updateDirectQualityDefaults(defaults),
        onRefreshRateChange: (value: number) => this.applyRefreshRateSelection(value),
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

  private captureSessionReturnTab(): void {
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 3) {
      this.sessionReturnTabIndex = this.currentTabIndex;
      return;
    }
    this.sessionReturnTabIndex = 0;
  }

  private restoreSessionReturnTab(): void {
    const targetIndex = this.sessionReturnTabIndex;
    this.currentTabIndex = targetIndex;
    setTimeout((): void => {
      if (!this.showPreviewModal && !this.showTransferWorkspace && !this.isWideMainLayout()) {
        this.hdsTabsController.changeIndex(targetIndex);
      }
    }, 0);
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
    if (this.currentTabIndex === 2) {
      return '设置';
    }
    return '服务端';
  }

  private mainNavigationSubtitle(): ResourceStr {
    if (this.currentTabIndex === 0) {
      return $r('app.string.navigation_home_subtitle');
    }
    if (this.currentTabIndex === 1) {
      return '最近、收藏、局域网与通讯簿';
    }
    if (this.currentTabIndex === 2) {
      return '连接、安全与体验';
    }
    return '仅分享本机屏幕和系统声音';
  }

  private activeMainScrollers(): Scroller[] {
    if (this.currentTabIndex === 0) {
      return [this.connectScroller];
    }
    if (this.currentTabIndex === 1) {
      return [
        this.deviceRecentScroller,
        this.deviceFavoriteScroller,
        this.deviceLanScroller,
        this.deviceAddressBookScroller,
      ];
    }
    if (this.currentTabIndex === 2) {
      return [this.settingsScroller];
    }
    return [this.viewedHostScroller];
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
      connectionMode: this.connectPageMode,
      rememberPassword: this.rememberPassword,
      canDisconnect: this.activeSessionId.length > 0,
      transferActive: this.transferSessionReady,
      easyTierAvailable: this.easyTierDataAvailable,
      easyTierEnabled: this.easyTierPreconnectEnabled,
      easyTierInstances: this.easyTierInstances,
      easyTierInstanceId: this.easyTierSelectedInstanceId,
      easyTierBusy: this.easyTierRequestPending,
      wideLayout: this.isWideMainLayout(),
      directorySnapshot: this.directorySnapshot,
      scroller: this.connectScroller,
      titleSpacerHeight: this.mainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      onConnectionModeChange: (index: number) => this.changeConnectPageMode(index),
      onTargetChange: (value: string) => this.updatePeerTarget(value),
      onConnectRemote: () => this.connectRemoteSession(),
      onConnectVnc: () => this.connectVncSession(),
      onConnectRdp: () => this.connectRdpSession(),
      onOpenTransfer: () => this.openTransferWorkspace(),
      onDisconnect: () => this.closeSession('已手动断开连接'),
      onEasyTierModeChange: (instanceId: string) => this.setEasyTierMode(instanceId),
    })
  }

  @Builder
  private DevicesPageContent() {
    DeviceDirectoryPanel({
      snapshot: this.directorySnapshot,
      wideLayout: this.isWideMainLayout(),
      recentScroller: this.deviceRecentScroller,
      favoriteScroller: this.deviceFavoriteScroller,
      lanScroller: this.deviceLanScroller,
      addressBookScroller: this.deviceAddressBookScroller,
      titleSpacerHeight: this.mainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      onRefresh: () => this.refreshDirectorySnapshot(true),
      onScanLan: (): void => {
        void this.scanLanPeers();
      },
      onStopLan: (): void => this.cancelLanScan(),
      onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean,
        idOnly: boolean) => this.setPeerFavorite(target, protocol, favorite, idOnly),
      onEditNote: (target: string, protocol: PeerProtocol, note: string,
        idOnly: boolean) => this.setPeerNote(target, protocol, note, idOnly),
      onRemoveRecent: (target: string, protocol: PeerProtocol, idOnly: boolean) =>
        this.removeRecentPeer(target, protocol, idOnly),
      onSaveDevice: (original: PeerRecord, peer: PeerRecord): ResourceStr => this.saveLocalDevice(original, peer),
      onRemoveLan: (target: string, _protocol: PeerProtocol) => void this.removeDiscoveredPeer(target),
      onConnectRemote: (peerId: string, rustdeskIdOnly: boolean) => this.launchPeer(peerId, 'remote_control', rustdeskIdOnly),
      onConnectVnc: (peerId: string) => this.launchPeer(peerId, 'vnc'),
      onConnectRdp: (peerId: string) => this.launchPeer(peerId, 'rdp'),
    })
  }

  @Builder
  private SettingsPageContent() {
    SettingsTab({
      decoderCapabilities: this.decoderCapabilities,
      serverConfig: this.serverConfig,
      serverProfile: this.serverProfile,
      serverValidating: this.serverValidating,
      serverSaving: this.serverSaving,
      sessionDefaults: this.sessionDefaults,
      // The same device-derived list the session panel offers, so a default set
      // here is always one the panel can show.
      refreshRateChoices: this.refreshRateChoices,
      controlledHostState: controlledHostCoordinator.state,
      controlledTwoFactorState: controlledHostCoordinator.twoFactorState,
      errorText: this.errorText,
      wideLayout: this.isWideMainLayout(),
      scroller: this.settingsScroller,
      titleSpacerHeight: this.boundMainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      tutorialLaunchToken: this.firstLaunchTutorialRequest,
      onServerConfigChange: (config: ServerConfig) => this.updateServerConfigDraft(config),
      onValidateServerConfig: (config: ServerConfig) => this.testServerConfiguration(config),
      onSaveServerConfig: (config: ServerConfig) => this.saveServerConfiguration(config),
      onSessionDefaultsChange: (defaults: SessionDefaults) => this.saveSessionDefaults(defaults),
      onControlledRefresh: () => {
        controlledHostCoordinator.refreshPasswordState();
        controlledHostCoordinator.refreshTwoFactorState();
      },
      onControlledPasswordModeChange: (mode: ControlledPasswordMode) =>
        controlledHostCoordinator.setVerificationMethod(mode),
      onControlledSetPermanentPassword: (password: string, confirmation: string) =>
        controlledHostCoordinator.setPermanentPassword(password, confirmation),
      onControlledRemovePermanentPassword: () => controlledHostCoordinator.clearPermanentPassword(),
      onControlledBeginTwoFactor: () => controlledHostCoordinator.beginTwoFactorSetup(),
      onControlledVerifyTwoFactor: (code: string) => controlledHostCoordinator.verifyTwoFactorSetup(code),
      onControlledCancelTwoFactor: () => controlledHostCoordinator.cancelTwoFactorSetup(),
      onControlledDisableTwoFactor: () => controlledHostCoordinator.disableTwoFactor(),
      onControlledTrustedDevicesEnabledChange: (enabled: boolean) =>
        controlledHostCoordinator.setTrustedDevicesEnabled(enabled),
      onControlledRemoveTrustedDevice: (device: ControlledTrustedDevice) =>
        controlledHostCoordinator.removeTrustedDevice(device),
      onControlledClearTrustedDevices: () => controlledHostCoordinator.clearTrustedDevices(),
      onRefresh: () => void this.refreshNativeState(),
      onTutorialAutoOpened: () => this.markFirstLaunchTutorialShown(),
    })
  }

  @Builder
  private ViewedHostPageContent() {
    ViewedHostPage({
      state: controlledHostCoordinator.state,
      scroller: this.viewedHostScroller,
      titleSpacerHeight: this.mainTitleSpacerHeight(),
      bottomAvoidInset: this.windowBottomAvoidInset,
      wideLayout: this.isWideMainLayout(),
      onStart: () => void controlledHostCoordinator.start(),
      onStop: () => void controlledHostCoordinator.stop('已由用户停止被看服务'),
      onAccept: (requestId: string, peerId: string) => controlledHostCoordinator.acceptIncoming(requestId, peerId),
      onReject: (requestId: string, peerId: string) => controlledHostCoordinator.rejectIncoming(requestId, peerId),
      onRefreshPassword: () => controlledHostCoordinator.refreshTemporaryPassword(),
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
          this.WideNavigationItem(3, '服务端', $r('sys.symbol.display'))
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
            this.foldHoverControlPane();
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
      } else if (this.currentTabIndex === 2) {
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
      } else {
        Stack() {
          this.ViewedHostPageContent();
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

      TabContent() {
        this.ViewedHostPageContent();
      }
      .tabBar(this.TabBuilder(3, '服务端', $r('sys.symbol.display')))
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
      barWidth: { smallWidth: 320, mediumWidth: 344, largeWidth: 376 },
      barBottomMargin: this.mainTabBottomMargin(),
      gradientMask: {
        maskColor: $r('app.color.tabs_gradient_mask'),
      },
      systemMaterialEffect: this.hdsMaterialAvailable ? {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      } : undefined,
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
          systemMaterialEffect: this.hdsMaterialAvailable ? {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
          } : undefined,
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
      }
      .width('100%')
      .height('100%')
      .opacity(this.rotationTransitionOpacity)
      .scale({ x: this.rotationTransitionScale, y: this.rotationTransitionScale })
      .zIndex(1)

      this.remoteSessionResumeOverlay();

      ConnectionAttemptOverlay({
        visible: this.connectionUiPhase !== 'idle' && !this.showPreviewModal && !this.passwordDialogVisible
          && !this.insecureConnectionDialogVisible && !this.directCredentialsVisible && !this.rdpCertificateDialogVisible,
        phase: this.connectionUiPhase,
        target: this.connectionUiTarget,
        message: this.connectionUiMessage,
        bottomAvoidInset: this.windowBottomAvoidInset,
        onCancel: () => this.cancelConnectionAttempt(),
        onRetry: () => this.retryConnectionAttempt(),
        onDismiss: () => this.dismissConnectionAttempt(),
      })
      .zIndex(1500)

      DirectCredentialsDialog({
        visible: this.directCredentialsVisible,
        protocol: this.directCredentialsProtocol,
        target: this.directCredentialsTarget,
        username: this.directCredentialsUsername,
        password: this.directCredentialPassword,
        errorMessage: this.directCredentialsError,
        onUsernameChange: (value: string) => this.directCredentialsUsername = value,
        onPasswordChange: (value: string) => this.directCredentialPassword = value,
        onCancel: () => this.cancelDirectCredentials(),
        onSubmit: () => this.submitDirectCredentials(),
      })
      .zIndex(2000)

      PasswordDialog({
        visible: this.passwordDialogVisible,
        mode: this.authDialogMode,
        canTrustDevice: this.canTrustDevice,
        canRememberPassword: this.canPersistSessionPassword(),
        errorMessage: this.authErrorMessage,
        password: this.passwordDraft,
        rememberPassword: this.rememberPassword,
        code2fa: this.code2faDraft,
        trustThisDevice: this.trustThisDevice,
        onPasswordChange: (value: string) => this.passwordDraft = value,
        onRememberChange: (value: boolean) => this.rememberPassword = value,
        onCode2faChange: (value: string) => this.code2faDraft = value,
        onTrustThisDeviceChange: (value: boolean) => this.trustThisDevice = value,
        onCancel: () => this.cancelPasswordDialog(),
        onSubmit: () => this.submitPassword(),
      })
      .zIndex(2000)

      InsecureConnectionDialog({
        visible: this.insecureConnectionDialogVisible,
        message: this.insecureConnectionMessage,
        onContinue: () => this.continueInsecureConnection(),
        onDisconnect: () => this.disconnectInsecureConnection(),
      })
      .zIndex(2100)

      InsecureConnectionDialog({
        visible: this.rdpCertificateDialogVisible,
        title: $r('app.string.rdp_certificate_title'),
        subtitle: this.rdpCertificateChallenge?.reason === 'pin_mismatch'
          ? $r('app.string.rdp_certificate_changed') : $r('app.string.rdp_certificate_waiting'),
        certificate: this.rdpCertificateChallenge,
        replaceConfirmation: this.rdpCertificateReplaceConfirmation,
        busy: this.rdpCertificateBusy,
        certificateError: this.rdpCertificateError,
        onContinue: (): void => { void this.acceptRdpCertificate(false); },
        onRemember: (): void => { void this.acceptRdpCertificate(true); },
        onDisconnect: (): void => this.cancelRdpCertificateDialog(),
      })
      .zIndex(2200)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.updateMainViewport(newArea);
    })
  }
}
