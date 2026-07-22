import {
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  hdsMaterial,
} from '@kit.UIDesignKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousSurface,
  LuminousSurfaceState,
  LuminousTone,
} from 'luminous_neo';
import { AccountLoginProvider, AccountState, ServerConfig, SessionDefaults } from '../RustDeskDirectoryTypes';
import { DecoderCapability } from '../RustDeskTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { AccountSettingsCard } from './AccountSettingsCard';
import { ServerSettingsCard } from './ServerSettingsCard';
import { SessionDefaultsCard } from './SessionDefaultsCard';

type SettingsSection = 'server' | 'account' | 'session' | 'diagnostics';

export interface SettingsTabProps {
  nativeVersion: string;
  health: string;
  integrationStage: string;
  upstreamRepo: string;
  buildMarker: string;
  decoderCapabilities: DecoderCapability[];
  serverConfig: ServerConfig;
  serverValidating: boolean;
  serverSaving: boolean;
  sessionDefaults: SessionDefaults;
  accountState: AccountState;
  accountLoginProviders: AccountLoginProvider[];
  notes: string;
  errorText: string;
  scroller: Scroller;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  onServerConfigChange: (config: ServerConfig) => void;
  onValidateServerConfig: (config: ServerConfig) => void;
  onSaveServerConfig: (config: ServerConfig) => void;
  onSessionDefaultsChange: (defaults: SessionDefaults) => void;
  onAccountLogin: (username: string, password: string) => void;
  onAccountVerify: (code: string) => void;
  onAccountCancelChallenge: () => void;
  onAccountOidcLogin: (provider: string) => void;
  onAccountOidcCancel: () => void;
  onAddressBookSync: () => void;
  onAccountLogout: () => void;
  onRefresh: () => void;
}

@ComponentV2
export struct SettingsTab {
  @Param nativeVersion: string = 'loading...';
  @Param health: string = 'waiting...';
  @Param integrationStage: string = 'unknown';
  @Param upstreamRepo: string = '';
  @Param buildMarker: string = '';
  @Param decoderCapabilities: DecoderCapability[] = [];
  @Param serverConfig: ServerConfig = new ServerConfig();
  @Param serverValidating: boolean = false;
  @Param serverSaving: boolean = false;
  @Param sessionDefaults: SessionDefaults = new SessionDefaults();
  @Param accountState: AccountState = new AccountState();
  @Param accountLoginProviders: AccountLoginProvider[] = [];
  @Param notes: string = '';
  @Param errorText: string = '';
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Local viewportWidth: number = 390;
  @Local sheetViewportWidth: number = 390;
  @Local hubViewportHeight: number = 0;
  @Local sheetViewportHeight: number = 0;
  @Local selectedSection: SettingsSection = 'server';
  @Local settingsSheetVisible: boolean = false;
  @Local pressedSection: string = '';
  @Local sessionDefaultsDraft: SessionDefaults = new SessionDefaults();
  @Param scroller: Scroller = new Scroller();
  private sheetScroller: Scroller = new Scroller();
  @Event onServerConfigChange: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onValidateServerConfig: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onSaveServerConfig: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onSessionDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults) => {};
  @Event onAccountLogin: (username: string, password: string) => void = (_username: string, _password: string) => {};
  @Event onAccountVerify: (code: string) => void = (_code: string) => {};
  @Event onAccountCancelChallenge: () => void = () => {};
  @Event onAccountOidcLogin: (provider: string) => void = (_provider: string) => {};
  @Event onAccountOidcCancel: () => void = () => {};
  @Event onAddressBookSync: () => void = () => {};
  @Event onAccountLogout: () => void = () => {};
  @Event onRefresh: () => void = () => {};

  private hasError(): boolean {
    return this.errorText.trim().length > 0;
  }

  private useWideContentAnchor(): boolean {
    return RustDeskLayoutTokens.useWideContentAnchor(this.viewportWidth, this.wideLayout);
  }

  private wideHubLeftInset(): number {
    return RustDeskLayoutTokens.WIDE_CONTENT_EDGE - 12;
  }

  private bridgeReady(): boolean {
    const health = this.health.toLowerCase();
    return health.includes('ready') || health.includes('ok') || this.integrationStage.includes('bind');
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
    const defaults = new SessionDefaults();
    defaults.relativeMouseMode = source.relativeMouseMode;
    defaults.audioEnabled = source.audioEnabled;
    defaults.clipboardEnabled = source.clipboardEnabled;
    defaults.qualityPreset = source.qualityPreset;
    defaults.preferredCodec = source.preferredCodec;
    defaults.gesturesEnabled = source.gesturesEnabled;
    defaults.toolbarExpanded = source.toolbarExpanded;
    return defaults;
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
    if (this.selectedSection === 'server') {
      return $r('app.string.settings_server_title');
    }
    if (this.selectedSection === 'account') {
      return $r('app.string.settings_account_title');
    }
    if (this.selectedSection === 'session') {
      return '新会话默认行为';
    }
    return '诊断与关于';
  }

  private sheetSubtitle(): ResourceStr {
    if (this.selectedSection === 'server') {
      return $r('app.string.settings_server_subtitle');
    }
    if (this.selectedSection === 'account') {
      return $r('app.string.settings_account_subtitle');
    }
    if (this.selectedSection === 'session') {
      return $r('app.string.settings_defaults_subtitle');
    }
    return this.diagnosticSummary();
  }

  private serverSummary(): ResourceStr {
    if (this.serverConfig.mode === 'official') {
      return $r('app.string.settings_server_official');
    }
    if (this.serverConfig.idServer.trim().length > 0) {
      return this.serverConfig.idServer.trim();
    }
    return $r('app.string.settings_server_custom');
  }

  private accountSummary(): ResourceStr {
    if (this.accountState.loggedIn) {
      if (this.accountState.displayName.trim().length > 0) {
        return this.accountState.displayName.trim();
      }
      if (this.accountState.name.trim().length > 0) {
        return this.accountState.name.trim();
      }
      return $r('app.string.settings_account_signed_in');
    }
    if (this.accountState.apiServer.trim().length === 0) {
      return $r('app.string.settings_account_api_unavailable');
    }
    return $r('app.string.settings_account_signed_out');
  }

  private sessionSummary(): ResourceStr {
    return this.sessionDefaults.relativeMouseMode
      ? $r('app.string.settings_pointer_touchpad')
      : $r('app.string.settings_pointer_mouse');
  }

  private diagnosticSummary(): string {
    if (this.hasError()) {
      return '检测到需要处理的运行日志';
    }
    if (this.bridgeReady()) {
      return `核心已就绪 · ${this.decoderCapabilities.length} 项视频能力`;
    }
    return '正在检查核心服务与设备能力';
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
        state: this.pressedSection === section
          ? LuminousSurfaceState.Inset
          : LuminousSurfaceState.Raised,
        surfaceWidth: this.tileSurfaceWidth(),
        surfaceHeight: 72,
        cornerRadius: 22,
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
      .onTouch((event: TouchEvent) => {
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
            '账户',
            this.accountSummary(),
            $r('app.color.neu_accent'),
          )
        }
        .width(this.hubFrameWidth());

        Row({ space: 14 }) {
          this.SettingsTile(
            'session',
            $r('sys.symbol.slider_horizontal_2'),
            '远控默认',
            this.sessionSummary(),
            $r('app.color.success'),
          )
          this.SettingsTile(
            'diagnostics',
            $r('sys.symbol.info_circle'),
            '诊断',
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
          '账户',
          this.accountSummary(),
          $r('app.color.neu_accent'),
        )
        this.SettingsTile(
          'session',
          $r('sys.symbol.slider_horizontal_2'),
          '远控默认',
          this.sessionSummary(),
          $r('app.color.success'),
        )
        this.SettingsTile(
          'diagnostics',
          $r('sys.symbol.info_circle'),
          '诊断',
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
  private InfoRow(label: string, value: string, showDivider: boolean = true) {
    Row({ space: 10 }) {
      Text(label)
        .width(72)
        .fontSize(12)
        .fontColor($r('app.color.neu_text_secondary'));
      Text(value || '--')
        .layoutWeight(1)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_primary'))
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .border({
      width: { bottom: showDivider ? 0.5 : 0 },
      color: $r('app.color.divider'),
    });
  }

  @Builder
  private StatusTag(text: string, color: ResourceColor, _background: ResourceColor) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        state: LuminousSurfaceState.Inset,
        surfaceWidth: 62,
        surfaceHeight: 28,
        cornerRadius: 10,
        raisedShadowDistance: 2,
        raisedShadowBlur: 4,
        insetShadowDistance: 2,
        insetShadowBlur: 4,
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
        state: LuminousSurfaceState.Raised,
        surfaceWidth: this.diagnosticPanelWidth(),
        surfaceHeight: 78,
        cornerRadius: 22,
      }) {
        Row({ space: 12 }) {
          Image($r('app.media.startIcon'))
            .width(44)
            .height(44)
            .borderRadius(12);

          Column({ space: 3 }) {
            Text('RustDesk HMOS')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Text(this.nativeVersion)
              .width('100%')
              .fontSize(11)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          this.StatusTag(
            this.bridgeReady() ? '已就绪' : '检查中',
            this.bridgeReady() ? $r('app.color.success') : $r('app.color.warning'),
            this.bridgeReady() ? $r('app.color.success_soft') : $r('app.color.warning_soft'),
          )
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
  private RuntimeUnit() {
    Column({ space: 6 }) {
      Text('核心状态')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));

      Stack({ alignContent: Alignment.Center }) {
        LuminousSurface({
          state: LuminousSurfaceState.Raised,
          surfaceWidth: this.diagnosticPanelWidth(),
          surfaceHeight: 104,
          cornerRadius: 20,
        }) {
          Column({ space: 0 }) {
            this.InfoRow('健康状态', this.health || 'waiting...', true)
            this.InfoRow('集成阶段', this.integrationStage, false)
          }
          .width(this.diagnosticPanelWidth())
          .height(104)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 });
        }
      }
      .width(this.diagnosticPanelWidth() + 16)
      .height(120)
      .clip(false);
    }
    .width(this.diagnosticPanelWidth() + 16)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private BuildUnit() {
    Column({ space: 6 }) {
      Text('构建与关于')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));

      Stack({ alignContent: Alignment.Center }) {
        LuminousSurface({
          state: LuminousSurfaceState.Raised,
          surfaceWidth: this.diagnosticPanelWidth(),
          surfaceHeight: 160,
          cornerRadius: 20,
        }) {
          Column({ space: 0 }) {
            this.InfoRow('构建标识', this.buildMarker, true)
            this.InfoRow('上游仓库', this.upstreamRepo, this.notes.trim().length > 0)
            if (this.notes.trim().length > 0) {
              this.InfoRow('运行说明', this.notes, false)
            }
          }
          .width(this.diagnosticPanelWidth())
          .height(160)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 });
        }
      }
      .width(this.diagnosticPanelWidth() + 16)
      .height(176)
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
          state: LuminousSurfaceState.Raised,
          surfaceWidth: this.diagnosticPanelWidth(),
          surfaceHeight: this.diagnosticDecoderHeight(),
          cornerRadius: 20,
        }) {
          Column({ space: 0 }) {
            if (this.decoderCapabilities.length === 0) {
              Row({ space: 10 }) {
                Text('解码器')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.neu_text_primary'));
                Text('正在查询设备能力')
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
      label: '刷新底层状态',
      controlWidth: this.diagnosticPanelWidth(),
      controlSizeMode: LuminousControlSize.Compact,
      tone: LuminousTone.Accent,
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
            this.RuntimeUnit()
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
          this.RuntimeUnit()
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

  @Builder
  private SelectedSettingsContent() {
    if (this.selectedSection === 'server') {
      ServerSettingsCard({
        showHeader: false,
        config: this.serverConfig,
        validating: this.serverValidating,
        saving: this.serverSaving,
        onConfigChange: (config: ServerConfig) => this.onServerConfigChange(config),
        onValidate: (config: ServerConfig) => this.onValidateServerConfig(config),
        onSave: (config: ServerConfig) => this.onSaveServerConfig(config),
      })
    } else if (this.selectedSection === 'account') {
      AccountSettingsCard({
        showHeader: false,
        officialServer: this.serverConfig.mode === 'official',
        accountState: this.accountState,
        loginProviders: this.accountLoginProviders,
        onLogin: (username: string, password: string) => this.onAccountLogin(username, password),
        onVerify: (code: string) => this.onAccountVerify(code),
        onCancelChallenge: () => this.onAccountCancelChallenge(),
        onOidcLogin: (provider: string) => this.onAccountOidcLogin(provider),
        onOidcCancel: () => this.onAccountOidcCancel(),
        onSync: () => this.onAddressBookSync(),
        onLogout: () => this.onAccountLogout(),
      })
    } else if (this.selectedSection === 'session') {
      SessionDefaultsCard({
        showHeader: false,
        defaults: this.sessionDefaultsDraft,
        onDefaultsChange: (defaults: SessionDefaults) => this.updateSessionDefaultsDraft(defaults),
      })
    } else {
      this.DiagnosticsPage()
    }
  }

  @Builder
  private SettingsHubPage() {
    Scroll(this.scroller) {
      Column() {
        Blank()
          .width('100%')
          .height(this.titleSpacerHeight)
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
          top: RustDeskLayoutTokens.PAGE_CONTENT_TOP_PADDING,
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
            .constraintSize({ maxWidth: 960 })
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
            top: $r('app.float.space_8'),
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
        title: {
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
