import { Chip, ChipSize, LengthMetrics } from '@kit.ArkUI';
import { DecoderCapability } from '../RustDeskTypes';

interface StatusChipOptions {
  text: string;
  color: string;
  backgroundColor: string;
  activated?: boolean;
}

export interface SettingsTabProps {
  rememberPassword: boolean;
  nativeVersion: string;
  health: string;
  integrationStage: string;
  upstreamRepo: string;
  buildMarker: string;
  decoderCapabilities: DecoderCapability[];
  notes: string;
  errorText: string;
  scroller: Scroller;
  onRefresh: () => void;
  onForgetPassword: () => void;
}

@Component
export struct SettingsTab {
  @Prop rememberPassword: boolean = false;
  @Prop nativeVersion: string = 'loading...';
  @Prop health: string = 'waiting...';
  @Prop integrationStage: string = 'unknown';
  @Prop upstreamRepo: string = '';
  @Prop buildMarker: string = '';
  @Prop decoderCapabilities: DecoderCapability[] = [];
  @Prop notes: string = '';
  @Prop errorText: string = '';
  scroller: Scroller = new Scroller();
  onRefresh: () => void = () => {};
  onForgetPassword: () => void = () => {};

  private hasError(): boolean {
    return this.errorText.trim().length > 0;
  }

  private bridgeReady(): boolean {
    const health = this.health.toLowerCase();
    return health.includes('ready') || health.includes('ok') || this.integrationStage.includes('bind');
  }

  @Builder
  private StatusChip(options: StatusChipOptions) {
    Chip({
      label: {
        text: options.text,
        fontSize: 12,
        fontColor: options.color,
        fontFamily: 'HarmonyOS Sans'
      },
      size: ChipSize.SMALL,
      allowClose: false,
      enabled: true,
      activated: options.activated ?? false,
      backgroundColor: options.backgroundColor,
      activatedBackgroundColor: options.backgroundColor,
      borderRadius: 6,
      fontSize: 12,
      minFontScale: 0.85,
      maxFontScale: 1.12,
      padding: {
        start: LengthMetrics.vp(10),
        end: LengthMetrics.vp(10),
        top: LengthMetrics.vp(4),
        bottom: LengthMetrics.vp(4)
      }
    })
  }

  @Builder
  private SectionHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .padding({ left: 8, bottom: 4 });
  }

  @Builder
  private InfoRow(label: string, value: string, showBorder: boolean = true) {
    Row() {
      Text(label)
        .width(80)
        .fontSize(15)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(value || '--')
        .layoutWeight(1)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(48)
    .border({ width: { bottom: showBorder ? 0.5 : 0 }, color: $r('sys.color.ohos_id_color_list_separator') })
  }

  @Builder
  private DecoderRow(item: DecoderCapability, isLast: boolean) {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text(item.codec)
            .fontSize(15)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Text(item.recommendedName || '默认实现')
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 8 }) {
          if (item.hardwareAvailable) {
            this.StatusChip({
              text: '硬解',
              color: '#16875A',
              backgroundColor: '#E9F7F0',
              activated: false
            })
          }
          if (item.softwareAvailable) {
            this.StatusChip({
              text: '软解',
              color: '#2F6BFF',
              backgroundColor: '#EAF1FF',
              activated: false
            })
          }
          if (!item.hardwareAvailable && !item.softwareAvailable) {
            this.StatusChip({
              text: '不支持',
              color: '#C7372F',
              backgroundColor: '#FFF0EE',
              activated: false
            })
          }
        }
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .border({ width: { bottom: isLast ? 0 : 0.5 }, color: $r('sys.color.ohos_id_color_list_separator') })
    }
    .width('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        // App Info header
        Column({ space: 8 }) {
          Image($r('app.media.startIcon'))
            .width(64)
            .height(64)
            .borderRadius(16)
          Text('RustDesk HMOS')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Text(this.nativeVersion)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 32, bottom: 16 })

        // Bridge Status Card
        Column({ space: 8 }) {
          this.SectionHeader('核心状态');
          
          Column({ space: 0 }) {
            this.InfoRow('健康状态', this.health || 'waiting...', true)
            this.InfoRow('集成阶段', this.integrationStage, true)
            this.InfoRow('上游仓库', this.upstreamRepo, false)
          }
          .backgroundColor($r('sys.color.ohos_id_color_list_card_bg'))
          .borderRadius($r('sys.float.ohos_id_corner_radius_card'))
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .padding({ left: 16, right: 16 })
        }
        .width('100%');

        // Technical Details Card
        Column({ space: 8 }) {
          this.SectionHeader('技术详情');

          Column({ space: 0 }) {
            this.InfoRow('构建标识', this.buildMarker, this.decoderCapabilities.length > 0)
            
            ForEach(this.decoderCapabilities, (item: DecoderCapability, index: number) => {
              this.DecoderRow(item, index === this.decoderCapabilities.length - 1)
            }, (item: DecoderCapability) => item.codec)
            
            if (this.decoderCapabilities.length === 0) {
              this.InfoRow('解码器', '无配置', false)
            }
          }
          .backgroundColor($r('sys.color.ohos_id_color_list_card_bg'))
          .borderRadius($r('sys.float.ohos_id_corner_radius_card'))
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .padding({ left: 16, right: 16 })
        }
        .width('100%');

        if (this.hasError()) {
          Column({ space: 8 }) {
            this.SectionHeader('系统日志');
            
            Column() {
              Text(this.errorText)
                .fontSize(13)
                .fontColor($r('sys.color.ohos_id_color_warning'))
                .width('100%')
                .lineHeight(18)
            }
            .backgroundColor($r('sys.color.ohos_id_color_list_card_bg'))
            .borderRadius($r('sys.float.ohos_id_corner_radius_card'))
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .padding(16)
          }
          .width('100%');
        }

        // Actions
        Column({ space: 12 }) {
          Button('刷新底层状态')
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .onClick(() => this.onRefresh())

          if (this.rememberPassword) {
            Button('清除已保存的密码')
              .width('100%')
              .height(48)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .fontColor($r('sys.color.ohos_id_color_warning'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.onForgetPassword())
          }
        }
        .width('100%')
        .padding({ top: 16 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 160, bottom: 120 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
  }
}
