import native from 'rustdesk-ohrs';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ConnectTab } from './rustdesk/components/ConnectTab';
import { PasswordPromptDialog } from './rustdesk/components/PasswordPromptDialog';
import { SettingsTab } from './rustdesk/components/SettingsTab';
import { RustDeskPreferences } from './rustdesk/RustDeskPreferences';
import { RustDeskSurfaceController } from './rustdesk/RustDeskSurfaceController';
import {
  ActionResponse,
  BridgeSummary,
  DecoderCapability,
  DecoderCapabilityResponse,
  DOMAIN,
  EVENT_POLL_INTERVAL_MS,
  MAX_PREVIEW_LONG_EDGE,
  NativeEvent,
  PASSWORD_TIMEOUT_MS,
  PeerDisplayInfo,
  RENDER_STATS_POLL_INTERVAL_MS,
  ResolutionInfo,
  SavedConnectionSettings,
  TAG,
} from './rustdesk/RustDeskTypes';

@Entry
@Component
struct RustDeskIndex {
  private previewController: RustDeskSurfaceController = new RustDeskSurfaceController();
  private preferences?: RustDeskPreferences;
  private passwordDialogController?: CustomDialogController;
  private connectScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();

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
    this.renderFpsText = 'FPS --';
    this.remoteFpsText = '--';
    this.remoteDelayText = '--';
    this.remoteCodecText = '--';
    this.refreshQualitySummary();
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

  private getPreviewDisplaySize(display: PeerDisplayInfo): PeerDisplayInfo {
    if (this.frameWidth > 0 && this.frameHeight > 0) {
      const scale = Math.min(this.frameWidth / display.width, this.frameHeight / display.height, 1);
      return {
        width: this.evenSize(display.width * scale),
        height: this.evenSize(display.height * scale),
        x: display.x,
        y: display.y
      };
    }
    const longEdge = Math.max(display.width, display.height);
    if (longEdge <= MAX_PREVIEW_LONG_EDGE) {
      return display;
    }
    const scale = MAX_PREVIEW_LONG_EDGE / longEdge;
    return {
      width: this.evenSize(display.width * scale),
      height: this.evenSize(display.height * scale),
      x: display.x,
      y: display.y
    };
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
    const requestedDisplay = this.getPreviewDisplaySize(primaryDisplay);
    this.updateSessionState(this.parseResponse(native.sessionSwitchDisplay(this.activeSessionId, JSON.stringify([currentDisplay]))));
    this.updateSessionState(this.parseResponse(native.sessionUpdateSupportedDecodings(this.activeSessionId)));
    this.updateSessionState(this.parseResponse(native.sessionSetSize(
      this.activeSessionId,
      currentDisplay,
      requestedDisplay.width,
      requestedDisplay.height
    )));
    const remoteResolution = this.chooseRemoteResolution(requestedDisplay.width, requestedDisplay.height);
    if (remoteResolution) {
      this.updateSessionState(this.parseResponse(native.sessionChangeResolution(
        this.activeSessionId,
        currentDisplay,
        remoteResolution.width,
        remoteResolution.height
      )));
    }
    this.requestVideoRefresh();
  }

  private handlePreviewSurfaceCreated(surfaceId: string): void {
    this.previewSurfaceId = surfaceId;
    this.frameStatus = `Surface created ${surfaceId}`;
    this.syncSurfaceBinding();
  }

  private handlePreviewSurfaceChanged(rect: SurfaceRect): void {
    this.frameWidth = rect.surfaceWidth;
    this.frameHeight = rect.surfaceHeight;
    this.frameStatus = `Surface ready ${rect.surfaceWidth}x${rect.surfaceHeight}`;
    this.applyDisplayConfiguration();
  }

  private handlePreviewSurfaceDestroyed(): void {
    this.clearSurfaceBinding();
    this.previewSurfaceId = '';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.frameStatus = 'Surface destroyed';
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
      this.updateSessionState(this.parseResponse(native.sessionSetCustomFps(this.activeSessionId, 30)));
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
          this.showPreviewModal = true;
          this.configureDisplayFromPeerInfo(event);
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
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 10 }) {
        Text(this.qualitySummary)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_foreground_contrary'));

        Text(this.frameStatus)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_foreground_contrary'));

        Text(`Surface size: ${this.frameWidth} x ${this.frameHeight} | ${this.renderFpsText}`)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_foreground_contrary'));

        XComponent({
          id: 'rustdesk-preview-surface',
          type: XComponentType.SURFACE,
          controller: this.previewController
        })
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#000000');
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })
      .backgroundColor('#000000');

      Button('断开连接')
        .margin({ top: 20, right: 20 })
        .height(38)
        .backgroundColor($r('sys.color.ohos_id_color_alert'))
        .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
        .onClick(() => this.closeSession('已手动断开连接'));
    }
    .width('100%')
    .height('100%');
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 6 }) {
        Text('Resk')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'));

        Text('输入 IP 连接远端设备')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 })
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);

      Scroll() {
        Column({ space: 18 }) {
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
          });

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
          });
        }
        .width('100%')
        .padding({ left: 0, right: 0, top: 8, bottom: 36 });
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM]);
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .bindContentCover(this.showPreviewModal, this.previewModalBuilder(), {
      modalTransition: ModalTransition.NONE,
      onDisappear: () => {
        if (this.showPreviewModal) {
          this.showPreviewModal = false;
        }
      }
    });
  }
}
