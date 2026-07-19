import {
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AccountLoginProvider, AccountState, ServerConfig, SessionDefaults } from '../RustDeskDirectoryTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { DecoderCapability } from '../RustDeskTypes';
import { AccountSettingsCard } from './AccountSettingsCard';
import { FloatingActionSurface } from './FloatingSurface';
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

  @Builder
  private SettingsToolRow(
    section: SettingsSection,
    icon: Resource,
    title: ResourceStr,
    summary: ResourceStr,
    accentColor: ResourceColor,
    accentBackground: ResourceColor,
  ) {
    Stack() {
      FloatingActionSurface({
        touchLight: true,
        lightColor: accentColor,
        lightPeakIntensity: 0.66,
        onActivate: () => this.selectSection(section),
      }) {
        Row({ space: $r('app.float.space_12') }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph(icon)
              .fontSize($r('app.float.icon_regular'))
              .fontColor([accentColor]);
          }
          .width($r('app.float.control_small'))
          .height($r('app.float.control_small'))
          .backgroundColor(accentBackground)
          .borderRadius($r('app.float.radius_14'))
          .clip(true);

          Column({ space: $r('app.float.space_2') }) {
            Text(title)
              .width('100%')
              .fontSize($r('app.float.font_body_large'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(summary)
              .width('100%')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize($r('app.float.icon_small'))
            .fontColor([$r('app.color.text_tertiary')]);
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
        .alignItems(VerticalAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height(72)
    .borderRadius($r('app.float.radius_14'));
  }

  @Builder
  private SettingsHub() {
    Column({ space: $r('app.float.space_12') }) {
      this.SettingsToolRow(
        'server',
        $r('sys.symbol.wifi_router'),
        $r('app.string.settings_server_title'),
        this.serverSummary(),
        $r('app.color.brand_primary'),
        $r('app.color.brand_primary_soft'),
      )
      this.SettingsToolRow(
        'account',
        $r('sys.symbol.person_crop_circle_fill'),
        $r('app.string.settings_account_title'),
        this.accountSummary(),
        $r('app.color.brand_primary'),
        $r('app.color.brand_primary_soft'),
      )
      this.SettingsToolRow(
        'session',
        $r('sys.symbol.slider_horizontal_2'),
        '远控默认值',
        this.sessionSummary(),
        $r('app.color.success'),
        $r('app.color.success_soft'),
      )
      this.SettingsToolRow(
        'diagnostics',
        $r('sys.symbol.info_circle'),
        '诊断与关于',
        this.diagnosticSummary(),
        this.hasError() ? $r('app.color.error') : $r('app.color.warning'),
        this.hasError() ? $r('app.color.error_soft') : $r('app.color.warning_soft'),
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private InfoRow(label: string, value: string, showDivider: boolean = true) {
    Row({ space: $r('app.float.space_12') }) {
      Text(label)
        .width(88)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      Text(value || '--')
        .layoutWeight(1)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .constraintSize({ minHeight: 42 })
    .border({
      width: { bottom: showDivider ? 0.5 : 0 },
      color: $r('app.color.divider'),
    });
  }

  @Builder
  private StatusTag(text: string, color: ResourceColor, background: ResourceColor) {
    Text(text)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .padding({
        left: $r('app.float.space_8'),
        right: $r('app.float.space_8'),
        top: $r('app.float.space_4'),
        bottom: $r('app.float.space_4'),
      })
      .backgroundColor(background)
      .borderRadius($r('app.float.radius_10'));
  }

  @Builder
  private DiagnosticIdentityUnit() {
    Stack() {
      Row({ space: $r('app.float.space_12') }) {
        Image($r('app.media.startIcon'))
          .width($r('app.float.control_regular'))
          .height($r('app.float.control_regular'))
          .borderRadius($r('app.float.radius_14'));

        Column({ space: $r('app.float.space_4') }) {
          Text('RustDesk HMOS')
            .width('100%')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
          Text(this.nativeVersion)
            .width('100%')
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'))
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
      .width('100%')
      .padding($r('app.float.space_16'))
      .alignItems(VerticalAlign.Center)
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.48,
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius($r('app.float.radius_18'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private RuntimeUnit() {
    Column({ space: $r('app.float.space_8') }) {
      Text('核心状态')
        .width('100%')
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));

      Stack() {
        Column({ space: 0 }) {
          this.InfoRow('健康状态', this.health || 'waiting...', true)
          this.InfoRow('集成阶段', this.integrationStage, false)
        }
        .width('100%')
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
        .borderRadius($r('app.float.radius_18'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.contentReceiver());
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_surface'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.48,
      })
      .linearGradient({
        angle: 142,
        colors: [
          [$r('app.color.glass_gradient_high'), 0],
          [$r('app.color.glass_gradient_mid'), 0.48],
          [$r('app.color.glass_gradient_accent'), 1],
        ],
      })
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.featherReceiver());
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private BuildUnit() {
    Column({ space: $r('app.float.space_8') }) {
      Text('构建与关于')
        .width('100%')
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));

      Stack() {
        Column({ space: 0 }) {
          this.InfoRow('构建标识', this.buildMarker, true)
          this.InfoRow('上游仓库', this.upstreamRepo, this.notes.trim().length > 0)
          if (this.notes.trim().length > 0) {
            this.InfoRow('运行说明', this.notes, false)
          }
        }
        .width('100%')
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
        .borderRadius($r('app.float.radius_18'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.contentReceiver());
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_surface'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.48,
      })
      .linearGradient({
        angle: 142,
        colors: [
          [$r('app.color.glass_gradient_high'), 0],
          [$r('app.color.glass_gradient_mid'), 0.48],
          [$r('app.color.glass_gradient_accent'), 1],
        ],
      })
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.featherReceiver());
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private DecoderUnit(item: DecoderCapability, showDivider: boolean) {
    Stack() {
      Row({ space: $r('app.float.space_12') }) {
        Column({ space: $r('app.float.space_4') }) {
          Text(item.codec)
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));
          Text(this.decoderDisplayName(item))
            .width('100%')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
          if (item.hardwareAvailable) {
            this.StatusTag('硬解', $r('app.color.success'), $r('app.color.success_soft'))
          }
          if (item.softwareAvailable) {
            Text('软解')
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_primary'))
              .padding({
                left: $r('app.float.space_8'),
                right: $r('app.float.space_8'),
                top: $r('app.float.space_4'),
                bottom: $r('app.float.space_4'),
              })
              .margin({ left: $r('app.float.space_4') })
              .backgroundColor($r('app.color.brand_primary_soft'))
              .borderRadius($r('app.float.radius_10'));
          }
          if (item.mimeAvailable && !item.hardwareAvailable && !item.softwareAvailable) {
            this.StatusTag('MIME', $r('app.color.warning'), $r('app.color.warning_soft'))
          }
          if (!this.decoderAvailable(item)) {
            this.StatusTag('不支持', $r('app.color.error'), $r('app.color.error_soft'))
          }
        }
      }
      .width('100%')
      .padding($r('app.float.space_16'))
      .alignItems(VerticalAlign.Center)
      .border({
        width: { bottom: showDivider ? 0.5 : 0 },
        color: $r('app.color.divider'),
      })
      .visualEffect(RustDeskGlassEffect.contentReceiver());
    }
    .width('100%');
  }

  @Builder
  private DecoderUnits() {
    Column({ space: $r('app.float.space_8') }) {
      Text('视频解码')
        .width('100%')
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));

      Stack() {
        Column({ space: 0 }) {
          if (this.decoderCapabilities.length === 0) {
            Row({ space: $r('app.float.space_12') }) {
              Text('解码器')
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'));
              Text('正在查询设备能力')
                .layoutWeight(1)
                .fontSize($r('app.float.font_label'))
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.End);
            }
            .width('100%')
            .padding($r('app.float.space_16'))
            .visualEffect(RustDeskGlassEffect.contentReceiver());
          } else {
            ForEach(this.decoderCapabilities, (item: DecoderCapability, index: number) => {
              this.DecoderUnit(item, index < this.decoderCapabilities.length - 1)
            }, (item: DecoderCapability) => item.codec)
          }
        }
        .width('100%')
        .borderRadius($r('app.float.radius_18'))
        .clip(true);
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_surface'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.48,
      })
      .linearGradient({
        angle: 142,
        colors: [
          [$r('app.color.glass_gradient_high'), 0],
          [$r('app.color.glass_gradient_mid'), 0.48],
          [$r('app.color.glass_gradient_accent'), 1],
        ],
      })
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.featherReceiver());
    }
    .width('100%')
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
    Stack() {
      FloatingActionSurface({
        touchLight: true,
        onActivate: () => this.onRefresh(),
      }) {
        Row() {
          Text('刷新底层状态')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_inverse'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.brand_primary'))
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private DiagnosticsPage() {
    Column({ space: $r('app.float.space_20') }) {
      if (this.useDiagnosticColumns()) {
        Row({ space: $r('app.float.space_24') }) {
          Column({ space: $r('app.float.space_20') }) {
            this.DiagnosticIdentityUnit()
            this.RuntimeUnit()
            this.DiagnosticRefreshButton()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Column({ space: $r('app.float.space_20') }) {
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
        Column({ space: $r('app.float.space_20') }) {
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
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .constraintSize({ minHeight: this.hubViewportHeight })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Top)
        .padding({
          left: this.horizontalPadding(),
          right: this.horizontalPadding(),
          top: this.viewportWidth < 600 ? $r('app.float.space_16') : $r('app.float.space_20'),
          bottom: this.hubBottomPadding(),
        });
      }
      .width('100%')
      .backgroundColor($r('app.color.transparent'));
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.transparent'))
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
            top: $r('app.float.space_16'),
            bottom: $r('app.float.space_40'),
          });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.background'));
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .scrollBar(BarState.Off)
      .backgroundColor($r('app.color.background'))
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
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
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
    .backgroundColor($r('app.color.background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  build() {
    Stack() {
      this.SettingsHubPage()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .bindSheet(this.settingsSheetVisible!!, this.SettingsSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      showClose: false,
      dragBar: false,
      enableFloatingDragBar: false,
      backgroundColor: $r('app.color.background'),
    })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
