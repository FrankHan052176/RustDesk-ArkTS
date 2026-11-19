import { bundleManager, common, OpenLinkOptions } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  hdsMaterial,
} from '@kit.UIDesignKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';
import { ServerConfig, ServerProfileState, SessionDefaults } from '../RustDeskDirectoryTypes';
import { DecoderCapability } from '../RustDeskTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { AccountSettingsCard } from './AccountSettingsCard';
import { BeginnerGuidePage } from './BeginnerGuidePage';
import { ServerSettingsCard } from './ServerSettingsCard';
import { SessionDefaultsCard } from './SessionDefaultsCard';
import { DirectSessionSettingsCard } from './DirectSessionSettingsCard';
import { copySessionDefaults } from '../DirectSessionSettings';
import { RustDeskAccountController, rustDeskAccountController } from '../NativeAccountBridge';

const RUSTDESK_WEBSITE_URL: string = 'https://rustdesk.com';
const RUSTDESK_PRIVACY_URL: string = 'https://rustdesk.com/privacy.html';

/**
 * One entry per thing a person looks for. The defaults of a new session are one
 * entry with its own parts, not four tiles, and this device's own access
 * security lives on the page that shares this device.
 */
type SettingsSection = 'tutorial' | 'server' | 'account' | 'session' | 'diagnostics';

/** Sections another page may ask this one to open (see `sectionRequest`). */
export type SettingsSectionRequest = '' | 'server' | 'account' | 'session';

export interface SettingsTabProps {
  decoderCapabilities: DecoderCapability[];
  /** Rates this device can show, ascending. Owned by the page. */
  refreshRateChoices: number[];
  serverConfig: ServerConfig;
  /** The approval this page holds; editing `serverConfig` never changes it. */
  serverProfile: ServerProfileState;
  serverValidating: boolean;
  serverSaving: boolean;
  sessionDefaults: SessionDefaults;
  errorText: string;
  scroller: Scroller;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  tutorialLaunchToken: number;
  /** A section to open now, e.g. the account page from "前往登录". */
  sectionRequest: SettingsSectionRequest;
  accountController?: RustDeskAccountController;
  onServerConfigChange: (config: ServerConfig) => void;
  onValidateServerConfig: (config: ServerConfig) => void;
  serverProbeMessage: string;
  onFlushServerConfig: (retry?: boolean) => void;
  onSessionDefaultsChange: (defaults: SessionDefaults) => void;
  onRefresh: () => void;
  onTutorialAutoOpened: () => void;
  /** The guide this page opened by itself on first launch was closed. */
  onTutorialDismissed: () => void;
  onSectionRequestHandled: () => void;
}

@ComponentV2
export struct SettingsTab {
  @Param decoderCapabilities: DecoderCapability[] = [];
  @Param serverConfig: ServerConfig = new ServerConfig();
  @Param serverProfile: ServerProfileState = new ServerProfileState();
  @Param accountController: RustDeskAccountController = rustDeskAccountController;
  @Param serverValidating: boolean = false;
  @Param serverSaving: boolean = false;
  @Param sessionDefaults: SessionDefaults = new SessionDefaults();
  @Param errorText: string = '';
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param tutorialLaunchToken: number = 0;
  @Param sectionRequest: SettingsSectionRequest = '';
  @Local viewportWidth: number = 390;
  @Local sheetViewportWidth: number = 390;
  @Local hubViewportHeight: number = 0;
  @Local sheetViewportHeight: number = 0;
  @Local selectedSection: SettingsSection = 'server';
  /** Which part of the session defaults is shown: input, quality, other, VNC/RDP. */
  @Local sessionSegment: number = 0;
  @Local settingsSheetVisible: boolean = false;
  @Local pressedSection: string = '';
  @Local appVersionName: string = '--';
  @Param refreshRateChoices: number[] = [30];
  @Local sessionDefaultsDraft: SessionDefaults = new SessionDefaults();
  @Param scroller: Scroller = new Scroller();
  private sheetScroller: Scroller = new Scroller();
  private handledTutorialLaunchToken: number = 0;
  /** The guide on screen was opened by first launch, not by a tap on its tile. */
  private tutorialAutoOpened: boolean = false;
  @Event onServerConfigChange: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onValidateServerConfig: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Param serverProbeMessage: string = '';
  @Event onFlushServerConfig: (retry?: boolean) => void = (_retry?: boolean) => {};
  @Event onSessionDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults) => {};
  @Event onRefresh: () => void = () => {};
  @Event onTutorialAutoOpened: () => void = () => {};
  @Event onTutorialDismissed: () => void = () => {};
  @Event onSectionRequestHandled: () => void = () => {};

  aboutToAppear(): void {
    void this.loadAppVersion();
    setTimeout((): void => {
      this.openRequestedTutorialIfNeeded();
      this.openRequestedSectionIfNeeded();
    }, 0);
  }

  private async loadAppVersion(): Promise<void> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT,
      );
      this.appVersionName = bundleInfo.versionName.trim().length > 0 ? bundleInfo.versionName : '--';
    } catch (_) {
      this.appVersionName = '--';
    }
  }

  @Monitor('tutorialLaunchToken')
  private onTutorialLaunchTokenChanged(_monitor: IMonitor): void {
    this.openRequestedTutorialIfNeeded();
  }

  private openRequestedTutorialIfNeeded(): void {
    if (this.tutorialLaunchToken <= 0 || this.tutorialLaunchToken <= this.handledTutorialLaunchToken) {
      return;
    }
    this.handledTutorialLaunchToken = this.tutorialLaunchToken;
    this.selectSection('tutorial');
    this.tutorialAutoOpened = true;
    this.onTutorialAutoOpened();
  }

  @Monitor('sectionRequest')
  private onSectionRequestChanged(_monitor: IMonitor): void {
    this.openRequestedSectionIfNeeded();
  }

  /**
   * Opens the section another page asked for and reports it taken, so the
   * request is spent once and does not reopen the sheet when this page is
   * created again.
   */
  private openRequestedSectionIfNeeded(): void {
    const requested: SettingsSectionRequest = this.sectionRequest;
    if (requested === '') {
      return;
    }
    this.selectSection(requested);
    this.onSectionRequestHandled();
  }

  /**
   * First launch brought the person to this page only to show the guide. When
   * that guide goes away, however it is closed, they are taken back to where
   * the app starts instead of being left on the settings list.
   */
  @Monitor('settingsSheetVisible')
  private onSettingsSheetVisibilityChanged(_monitor: IMonitor): void {
    if (this.settingsSheetVisible || !this.tutorialAutoOpened) {
      return;
    }
    this.tutorialAutoOpened = false;
    this.onTutorialDismissed();
  }

  private openExternalLink(url: string): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options: OpenLinkOptions = {
        appLinkingOnly: false,
        hideFailureTipDialog: true,
      };
      void context.openLink(url, options).catch((): void => this.showOpenLinkFailure());
    } catch (_) {
      this.showOpenLinkFailure();
    }
  }

  private showOpenLinkFailure(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.settings_about_open_failed'),
        duration: 3500,
      });
    } catch (_) {
    }
  }

  private hasError(): boolean {
    return this.errorText.trim().length > 0;
  }

  private useWideContentAnchor(): boolean {
    return RustDeskLayoutTokens.useWideContentAnchor(this.viewportWidth, this.wideLayout);
  }

  private wideHubLeftInset(): number {
    return RustDeskLayoutTokens.WIDE_CONTENT_EDGE - 12;
  }

  private decoderAvailable(item: DecoderCapability): boolean {
    return item.mimeAvailable || item.hardwareAvailable || item.softwareAvailable || item.recommendedAvailable;
  }

  private decoderDisplayName(item: DecoderCapability): string {
    if (item.recommendedName.trim().length > 0) {
      return item.recommendedName.trim();
    }
    if (item.hardwareName.trim().length > 0) {
      return item.hardwareName.trim();
    }
    if (item.softwareName.trim().length > 0) {
      return item.softwareName.trim();
    }
    if (item.mime.trim().length > 0) {
      return item.mime.trim();
    }
    return '系统未返回解码器名称';
  }

  private useDiagnosticColumns(): boolean {
    return this.sheetViewportWidth >= 920;
  }

  private horizontalPadding(): Resource {
    if (this.viewportWidth >= 1440) {
      return $r('app.float.space_48');
    }
    if (this.viewportWidth >= 840) {
      return $r('app.float.space_32');
    }
    return this.viewportWidth < 600 ? $r('app.float.space_16') : $r('app.float.space_24');
  }

  private sheetHorizontalPadding(): Resource {
    if (this.sheetViewportWidth >= 920) {
      return $r('app.float.space_32');
    }
    return this.sheetViewportWidth < 600 ? $r('app.float.space_16') : $r('app.float.space_24');
  }

  private hubBottomPadding(): number {
    return (this.wideLayout ? 40 : 120) + this.bottomAvoidInset;
  }

  private hubFrameWidth(): number {
    const sideRoom = this.viewportWidth < 600 ? 32 : 64;
    return Math.max(320, Math.min(this.viewportWidth - sideRoom, 820));
  }

  private useTwoTileColumns(): boolean {
    return this.viewportWidth >= 720;
  }

  private tileFrameWidth(): number {
    if (!this.useTwoTileColumns()) {
      return this.hubFrameWidth();
    }
    return (this.hubFrameWidth() - 14) / 2;
  }

  private tileSurfaceWidth(): number {
    if (!this.useTwoTileColumns()) {
      return Math.max(220, this.tileFrameWidth() - 8);
    }
    return Math.max(220, this.tileFrameWidth() - 24);
  }

  private tileFrameHeight(): number {
    return 88;
  }

  private copySessionDefaults(source: SessionDefaults): SessionDefaults {
    return copySessionDefaults(source);
  }

  private updateSessionDefaultsDraft(defaults: SessionDefaults): void {
    const next = this.copySessionDefaults(defaults);
    this.sessionDefaultsDraft = next;
    this.onSessionDefaultsChange(this.copySessionDefaults(next));
  }

  private selectSection(section: SettingsSection): void {
    if (section === 'session') {
      this.sessionDefaultsDraft = this.copySessionDefaults(this.sessionDefaults);
    }
    if (section !== 'tutorial') {
      // Any other section is the person's own choice; closing it stays here.
      this.tutorialAutoOpened = false;
    }
    this.selectedSection = section;
    this.settingsSheetVisible = true;
    setTimeout(() => {
      this.sheetScroller.scrollEdge(Edge.Top);
    }, 0);
  }

  private closeSettingsSheet(): void {
    this.settingsSheetVisible = false;
  }

  private sheetTitle(): ResourceStr {
    if (this.selectedSection === 'tutorial') {
      return $r('app.string.settings_tutorial_title');
    }
    if (this.selectedSection === 'server') {
      return '服务器';
    }
    if (this.selectedSection === 'account') {
      return '账号';
    }
    if (this.selectedSection === 'session') {
      return '会话默认';
    }
    return '关于与诊断';
  }

  private sheetSubtitle(): ResourceStr {
    if (this.selectedSection === 'tutorial') {
      return $r('app.string.settings_tutorial_subtitle');
    }
    if (this.selectedSection === 'server' || this.selectedSection === 'account') {
      return '';
    }
    if (this.selectedSection === 'session') {
      return '新会话的操作方式、画质、常用开关，以及 VNC / RDP 选项';
    }
    return this.diagnosticSummary();
  }

  private accountSummary(): ResourceStr {
    if (this.accountController.state.loggedIn) {
      const name = this.accountController.state.displayName || this.accountController.state.name || '已登录';
      return `已登录 · ${name}`;
    }
    return '未登录 · 支持官方与自建服务登录';
  }

  private serverSummary(): ResourceStr {
    // The row names the route the engine actually holds, which is the approved
    // profile, never the editable draft: a refused or unanswered save leaves its
    // values in the card's inputs and must not look like the current server.
    const current = this.serverProfile.config;
    if (current.mode === 'official') {
      return $r('app.string.settings_server_official');
    }
    if (current.idServer.trim().length > 0) {
      return current.idServer.trim();
    }
    return $r('app.string.settings_server_status_unconfigured');
  }

  private sessionSummary(): string {
    const pointer: string = this.sessionDefaults.touchMode
      ? '触控模式'
      : (this.sessionDefaults.relativeMouseMode ? '相对鼠标' : '鼠标模式');
    return `${pointer} · ${Math.round(this.sessionDefaults.refreshRate)} 帧`;
  }

  /** Width of the part selector inside the session-defaults sheet. */
  private sessionSegmentWidth(): number {
    return Math.max(240, this.sheetViewportWidth - LuminousNeoTokens.shadowPaddingFor(48) * 2);
  }

  private diagnosticSummary(): string {
    if (this.hasError()) {
      return '检测到需要处理的运行日志';
    }
    return this.decoderCapabilities.length > 0
      ? `版本 · 硬件解码 ${this.decoderCapabilities.map((item: DecoderCapability): string => item.codec === 'H265' ? 'H.265' : 'H.264').join('、')}`
      : '版本与关于';
  }

  private diagnosticPanelWidth(): number {
    if (this.useDiagnosticColumns()) {
      return Math.max(300, (this.sheetViewportWidth - 24) / 2 - 16);
    }
    return Math.max(280, this.sheetViewportWidth - 16);
  }

  private diagnosticDecoderHeight(): number {
    if (this.decoderCapabilities.length === 0) {
      return 60;
    }
    return this.decoderCapabilities.length * 58;
  }

  @Builder
  private SettingsTile(
    section: SettingsSection,
    icon: Resource,
    title: ResourceStr,
    summary: ResourceStr,
    accentColor: ResourceColor,
  ) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: this.pressedSection === section ? -1 : 1,
        surfaceWidth: this.tileSurfaceWidth(),
        surfaceHeight: 72,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Row({ space: 12 }) {
          SymbolGlyph(icon)
            .width(34)
            .fontSize(27)
            .fontColor([accentColor]);

          Column({ space: 4 }) {
            Text(title)
              .width('100%')
              .fontSize(14)
              .lineHeight(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text(summary)
              .width('100%')
              .fontSize(11)
              .lineHeight(16)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([$r('app.color.neu_text_secondary')]);
        }
        .width(this.tileSurfaceWidth())
        .height(72)
        .padding({ left: 14, right: 12 })
        .alignItems(VerticalAlign.Center);
      }

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
      .width(this.tileSurfaceWidth())
      .height(72)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.None)
      .borderRadius(22)
      .accessibilityText(title as Resource)
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) {
          this.pressedSection = section;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedSection = '';
        }
      })
      .onClick(() => {
        this.pressedSection = '';
        this.selectSection(section);
      });
    }
    .width(this.tileFrameWidth())
    .height(this.tileFrameHeight())
    .scale({
      x: this.pressedSection === section ? 0.98 : 1,
      y: this.pressedSection === section ? 0.98 : 1,
    })
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .clip(false);
  }

  @Builder
  private TileGrid() {
    if (this.useTwoTileColumns()) {
      Column({ space: 16 }) {
        Row({ space: 14 }) {
          this.SettingsTile(
            'server',
            $r('sys.symbol.wifi_router'),
            '服务器',
            this.serverSummary(),
            $r('app.color.neu_accent'),
          )
          this.SettingsTile(
            'account',
            $r('sys.symbol.person_crop_circle_fill'),
            '账号',
            this.accountSummary(),
            $r('app.color.neu_accent'),
          )
        }
        .width(this.hubFrameWidth());

        Row({ space: 14 }) {
          this.SettingsTile(
            'session',
            $r('sys.symbol.slider_horizontal_2'),
            '会话默认',
            this.sessionSummary(),
            $r('app.color.success'),
          )
          this.SettingsTile(
            'tutorial',
            $r('sys.symbol.book'),
            $r('app.string.settings_tutorial_title'),
            $r('app.string.settings_tutorial_summary'),
            $r('app.color.neu_accent'),
          )
        }
        .width(this.hubFrameWidth());

        Row() {
          this.SettingsTile(
            'diagnostics',
            $r('sys.symbol.info_circle'),
            '关于与诊断',
            this.diagnosticSummary(),
            this.hasError() ? $r('app.color.error') : $r('app.color.warning'),
          )
        }
        .width(this.hubFrameWidth());
      }
      .width(this.hubFrameWidth());
    } else {
      Column({ space: 16 }) {
        this.SettingsTile(
          'server',
          $r('sys.symbol.wifi_router'),
          '服务器',
          this.serverSummary(),
          $r('app.color.neu_accent'),
        )
        this.SettingsTile(
          'account',
          $r('sys.symbol.person_crop_circle_fill'),
          '账号',
          this.accountSummary(),
          $r('app.color.neu_accent'),
        )
        this.SettingsTile(
          'session',
          $r('sys.symbol.slider_horizontal_2'),
          '会话默认',
          this.sessionSummary(),
          $r('app.color.success'),
        )
        this.SettingsTile(
          'tutorial',
          $r('sys.symbol.book'),
          $r('app.string.settings_tutorial_title'),
          $r('app.string.settings_tutorial_summary'),
          $r('app.color.neu_accent'),
        )
        this.SettingsTile(
          'diagnostics',
          $r('sys.symbol.info_circle'),
          '关于与诊断',
          this.diagnosticSummary(),
          this.hasError() ? $r('app.color.error') : $r('app.color.warning'),
        )
      }
      .width(this.hubFrameWidth())
      .alignItems(HorizontalAlign.Center);
    }
  }

  @Builder
  private SettingsHub() {
    Column() {
      this.TileGrid();
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private LinkRow(label: ResourceStr, showDivider: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        Text(label)
          .layoutWeight(1)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_primary'));
        Text($r('app.string.settings_about_open'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_accent'));
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('app.color.neu_text_secondary')]);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .padding({ left: 0, right: 0 })
    .backgroundColor(Color.Transparent)
    .border({
      width: { bottom: showDivider ? 0.5 : 0 },
      color: $r('app.color.divider'),
    })
    .hoverEffect(HoverEffect.Auto)
    .onClick(onClick);
  }

  @Builder
  private StatusTag(text: string, color: ResourceColor, _background: ResourceColor) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: 62,
        surfaceHeight: 28,
        cornerRadius: 10,
        motionEnabled: true,
      }) {
        Text(text)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(color)
          .maxLines(1);
      }
    }
    .width(68)
    .height(32)
    .clip(false);
  }

  @Builder
  private DiagnosticIdentityUnit() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.diagnosticPanelWidth(),
        surfaceHeight: 78,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Row({ space: 12 }) {
          Image($r('app.media.resk'))
            .width(52)
            .height(52)
            .borderRadius(12);

          Column({ space: 3 }) {
            Text('Resk')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Text(`版本 ${this.appVersionName}`)
              .width('100%')
              .fontSize(11)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.diagnosticPanelWidth())
        .height(78)
        .padding({ left: 14, right: 14 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.diagnosticPanelWidth() + 16)
    .height(94)
    .clip(false);
  }

  @Builder
  private BuildUnit() {
    Column({ space: 6 }) {
      Text('关于')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));

      Stack({ alignContent: Alignment.Center }) {
        LuminousSurface({
          depth: 1,
          surfaceWidth: this.diagnosticPanelWidth(),
          surfaceHeight: 108,
          cornerRadius: 20,
          motionEnabled: true,
        }) {
          Column({ space: 0 }) {
            this.LinkRow($r('app.string.settings_about_website'), true,
              () => this.openExternalLink(RUSTDESK_WEBSITE_URL))
            this.LinkRow($r('app.string.settings_about_privacy'), false,
              () => this.openExternalLink(RUSTDESK_PRIVACY_URL))
          }
          .width(this.diagnosticPanelWidth())
          .height(108)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 });
        }
      }
      .width(this.diagnosticPanelWidth() + 16)
      .height(124)
      .clip(false);
    }
    .width(this.diagnosticPanelWidth() + 16)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private DecoderUnit(item: DecoderCapability, showDivider: boolean) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(item.codec)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text(this.decoderDisplayName(item))
          .width('100%')
          .fontSize(10)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      if (item.hardwareAvailable) {
        this.StatusTag('硬解', $r('app.color.success'), $r('app.color.success_soft'))
      } else if (item.softwareAvailable) {
        this.StatusTag('软解', $r('app.color.neu_accent'), $r('app.color.brand_primary_soft'))
      } else if (item.mimeAvailable) {
        this.StatusTag('MIME', $r('app.color.warning'), $r('app.color.warning_soft'))
      } else {
        this.StatusTag('不支持', $r('app.color.error'), $r('app.color.error_soft'))
      }
    }
    .width(this.diagnosticPanelWidth())
    .constraintSize({ minHeight: 58 })
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: showDivider ? 0.5 : 0 },
      color: $r('app.color.divider'),
    });
  }

  @Builder
  private DecoderUnits() {
    Column({ space: 6 }) {
      Text('视频解码')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));

      Stack({ alignContent: Alignment.Center }) {
        LuminousSurface({
          depth: 1,
          surfaceWidth: this.diagnosticPanelWidth(),
          surfaceHeight: this.diagnosticDecoderHeight(),
          cornerRadius: 20,
          motionEnabled: true,
        }) {
          Column({ space: 0 }) {
            if (this.decoderCapabilities.length === 0) {
              Row({ space: 10 }) {
                Text('解码器')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.neu_text_primary'));
                Text('未获取到')
                  .layoutWeight(1)
                  .fontSize(11)
                  .fontColor($r('app.color.neu_text_secondary'))
                  .textAlign(TextAlign.End);
              }
              .width(this.diagnosticPanelWidth())
              .height(60)
              .padding({ left: 14, right: 14 });
            } else {
              ForEach(this.decoderCapabilities, (item: DecoderCapability, index: number) => {
                this.DecoderUnit(item, index < this.decoderCapabilities.length - 1)
              }, (item: DecoderCapability) => item.codec)
            }
          }
          .width(this.diagnosticPanelWidth())
          .height(this.diagnosticDecoderHeight())
          .borderRadius(20)
          .clip(true);
        }
      }
      .width(this.diagnosticPanelWidth() + 16)
      .height(this.diagnosticDecoderHeight() + 16)
      .clip(false);
    }
    .width(this.diagnosticPanelWidth() + 16)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private DiagnosticErrorUnit() {
    if (this.hasError()) {
      Row({ space: $r('app.float.space_12') }) {
        Text('!')
          .width($r('app.float.control_compact'))
          .height($r('app.float.control_compact'))
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.error'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.transparent'))
          .borderRadius($r('app.float.radius_10'));

        Column({ space: $r('app.float.space_4') }) {
          Text('运行日志')
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.error'));
          Text(this.errorText)
            .width('100%')
            .fontSize($r('app.float.font_label'))
            .lineHeight(18)
            .fontColor($r('app.color.text_primary'));
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding($r('app.float.space_16'))
      .backgroundColor($r('app.color.error_soft'))
      .borderRadius($r('app.float.radius_18'));
    }
  }

  @Builder
  private DiagnosticRefreshButton() {
    LuminousButton({
      label: '刷新诊断信息',
      controlWidth: this.diagnosticPanelWidth(),
      controlSizeMode: LuminousControlSize.Compact,
      tone: LuminousTone.Accent,
      motionEnabled: true,
      onAction: () => this.onRefresh(),
    })
  }

  @Builder
  private DiagnosticsPage() {
    Column({ space: 12 }) {
      if (this.useDiagnosticColumns()) {
        Row({ space: 24 }) {
          Column({ space: 12 }) {
            this.DiagnosticIdentityUnit()
            this.DiagnosticRefreshButton()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Column({ space: 12 }) {
            this.BuildUnit()
            this.DecoderUnits()
            this.DiagnosticErrorUnit()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Column({ space: 12 }) {
          this.DiagnosticIdentityUnit()
          this.BuildUnit()
          this.DecoderUnits()
          this.DiagnosticErrorUnit()
          this.DiagnosticRefreshButton()
        }
        .width('100%');
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  /**
   * The defaults of a new session, one sheet with four parts. Switching part
   * stays in the sheet; every part edits the same draft.
   */
  @Builder
  private SessionDefaultsContent() {
    Column({ space: 14 }) {
      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('input', '操作'),
          new LuminousSelectionItem('quality', '画质'),
          new LuminousSelectionItem('other', '常用'),
          new LuminousSelectionItem('direct', 'VNC/RDP'),
        ],
        selectedIndex: this.sessionSegment,
        controlWidth: this.sessionSegmentWidth(),
        controlHeight: 48,
        motionEnabled: true,
        onChange: (index: number): void => {
          this.sessionSegment = index;
        },
      })

      if (this.sessionSegment === 0) {
        SessionDefaultsCard({
          showHeader: false,
          section: 'input',
          defaults: this.sessionDefaultsDraft,
          refreshRateChoices: this.refreshRateChoices,
          onDefaultsChange: (defaults: SessionDefaults) => this.updateSessionDefaultsDraft(defaults),
        })
      } else if (this.sessionSegment === 1) {
        SessionDefaultsCard({
          showHeader: false,
          section: 'quality',
          defaults: this.sessionDefaultsDraft,
          refreshRateChoices: this.refreshRateChoices,
          onDefaultsChange: (defaults: SessionDefaults) => this.updateSessionDefaultsDraft(defaults),
        })
      } else if (this.sessionSegment === 2) {
        SessionDefaultsCard({
          showHeader: false,
          section: 'other',
          defaults: this.sessionDefaultsDraft,
          refreshRateChoices: this.refreshRateChoices,
          onDefaultsChange: (defaults: SessionDefaults) => this.updateSessionDefaultsDraft(defaults),
        })
      } else {
        DirectSessionSettingsCard({
          defaults: this.sessionDefaultsDraft,
          onDefaultsChange: (defaults: SessionDefaults): void => this.updateSessionDefaultsDraft(defaults),
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private SelectedSettingsContent() {
    if (this.selectedSection === 'tutorial') {
      BeginnerGuidePage()
    } else if (this.selectedSection === 'server') {
      ServerSettingsCard({
        showHeader: false,
        config: this.serverConfig,
        profile: this.serverProfile,
        validating: this.serverValidating,
        saving: this.serverSaving,
        onConfigChange: (config: ServerConfig) => this.onServerConfigChange(config),
        onValidate: (config: ServerConfig) => this.onValidateServerConfig(config),
        probeMessage: this.serverProbeMessage,
        onFlush: (retry?: boolean) => this.onFlushServerConfig(retry),
      })
    } else if (this.selectedSection === 'account') {
      AccountSettingsCard({
        showHeader: false,
        controller: this.accountController,
      })
    } else if (this.selectedSection === 'session') {
      this.SessionDefaultsContent()
    } else {
      this.DiagnosticsPage()
    }
  }

  private pageTopClearance(): number {
    return this.wideLayout ? Math.max(this.titleSpacerHeight + 36, 56) : Math.max(this.titleSpacerHeight, 40);
  }

  @Builder
  private SettingsHubPage() {
    Scroll(this.scroller) {
      Column() {
        Blank()
          .width('100%')
          .height(this.pageTopClearance())
          .flexShrink(0);

        Row() {
          Column() {
            this.SettingsHub()
          }
          .width(this.hubFrameWidth())
          .alignItems(HorizontalAlign.Center);
        }
        .width('100%')
        .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
        .alignItems(VerticalAlign.Top)
        .padding({
          left: this.useWideContentAnchor() ? this.wideHubLeftInset() : this.horizontalPadding(),
          right: this.useWideContentAnchor() ? 0 : this.horizontalPadding(),
          top: 0,
          bottom: this.hubBottomPadding(),
        });
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .backgroundColor($r('app.color.neu_base'));
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const height = Number(newArea.height);
      if (height > 0) {
        this.hubViewportHeight = height;
      }
    });
  }

  private sheetContentMaxWidth(): number {
    if (this.selectedSection === 'diagnostics') {
      return 960;
    }
    if (this.sheetViewportWidth >= 920) {
      return 600;
    }
    if (this.sheetViewportWidth >= 600) {
      return 560;
    }
    return 600;
  }

  @Builder
  private SettingsSheet() {
    HdsNavigation() {
      Scroll(this.sheetScroller) {
        Column() {
          Row() {
            Column() {
              this.SelectedSettingsContent()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.sheetContentMaxWidth() })
            .alignItems(HorizontalAlign.Start)
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              const width = Number(newArea.width);
              if (width > 0) {
                this.sheetViewportWidth = width;
              }
            });
          }
          .width('100%')
          .constraintSize({ minHeight: this.sheetViewportHeight })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Top)
          .padding({
            left: this.sheetHorizontalPadding(),
            right: this.sheetHorizontalPadding(),
            top: $r('app.float.space_24'),
            bottom: $r('app.float.space_24'),
          });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.neu_base'));
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .scrollBar(BarState.Off)
      .backgroundColor($r('app.color.neu_base'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const height = Number(newArea.height);
        if (height > 0) {
          this.sheetViewportHeight = height;
        }
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(true)
    .titleBar({
      enableComponentSafeArea: true,
      content: {
        title: (this.selectedSection === 'server' || this.selectedSection === 'account') ? {
          mainTitle: this.sheetTitle(),
        } : {
          mainTitle: this.sheetTitle(),
          subTitle: this.sheetSubtitle(),
        },
        menu: {
          value: [{
            content: {
              label: '关闭',
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.SMALL,
              action: () => this.closeSettingsSheet(),
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
    .bindToScrollable([this.sheetScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  build() {
    Stack() {
      this.SettingsHubPage()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .bindSheet(this.settingsSheetVisible!!, this.SettingsSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      showClose: false,
      dragBar: false,
      enableFloatingDragBar: false,
      backgroundColor: $r('app.color.neu_base'),
    })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
