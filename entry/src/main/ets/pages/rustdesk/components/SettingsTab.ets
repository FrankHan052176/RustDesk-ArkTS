import { Chip, ChipSize, LengthMetrics } from '@kit.ArkUI';

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
  apiServer: string;
  buildMarker: string;
  decoderSummary: string;
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
  @Prop apiServer: string = '';
  @Prop buildMarker: string = '';
  @Prop decoderSummary: string = '';
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

  private bridgeTone(): string {
    if (this.hasError()) {
      return '#C7372F';
    }
    return this.bridgeReady() ? '#16875A' : '#A06000';
  }

  private bridgeBg(): string {
    if (this.hasError()) {
      return '#FFF0EE';
    }
    return this.bridgeReady() ? '#E9F7F0' : '#FFF2CF';
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
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor('#111827')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%');
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(96)
        .fontSize(12)
        .fontColor('#737D8F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(value || '--')
        .layoutWeight(1)
        .fontSize(13)
        .fontColor('#1F2937')
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .height(38)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private CompactMetric(label: string, value: string, tone: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor('#737D8F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(value || '--')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(tone)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
    .height(56)
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#F7F9FC')
    .borderRadius(8)
    .border({ width: 1, color: '#E6EAF0' });
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Row() {
          Row({ space: 10 }) {
            Stack() {
              Text('N')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF');
            }
            .width(38)
            .height(38)
            .backgroundColor('#182033')
            .borderRadius(8)
            .alignContent(Alignment.Center);

            Column({ space: 2 }) {
              Text('Native Bridge')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#121826')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });

              Text(this.health || 'waiting...')
                .fontSize(12)
                .fontColor('#697386')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .layoutWeight(1);

          this.StatusChip({
            text: this.hasError() ? '异常' : (this.bridgeReady() ? '可用' : '检查中'),
            color: this.bridgeTone(),
            backgroundColor: this.bridgeBg(),
            activated: this.bridgeReady() && !this.hasError()
          });
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Row({ space: 8 }) {
          this.CompactMetric('Stage', this.integrationStage || '--', '#2F6BFF');
          this.CompactMetric('Password', this.rememberPassword ? 'Saved' : 'None', this.rememberPassword ? '#16875A' : '#5C6676');
        }
        .width('100%');

        Column({ space: 10 }) {
          Row() {
            this.SectionHeader('运行信息');

            Button('刷新')
              .height(34)
              .width(72)
              .backgroundColor('#EAF1FF')
              .fontColor('#2F6BFF')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .borderRadius(8)
              .stateEffect(true)
              .onClick(() => this.onRefresh());
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Divider().color('#EEF1F5').strokeWidth(1);
          this.InfoRow('Version', this.nativeVersion);
          this.InfoRow('API Server', this.apiServer || 'unknown');
          this.InfoRow('Build', this.buildMarker || 'unknown');
          this.InfoRow('Upstream', this.upstreamRepo || 'unknown');
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E2E7EF' });

        Column({ space: 10 }) {
          this.SectionHeader('解码链路');
          Divider().color('#EEF1F5').strokeWidth(1);

          Text(this.decoderSummary || 'unknown')
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#475569')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');

          if (this.notes.trim().length > 0) {
            Divider().color('#EEF1F5').strokeWidth(1);

            Text(this.notes)
              .fontSize(13)
              .lineHeight(19)
              .fontColor('#1F2937')
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E2E7EF' });

        Column({ space: 10 }) {
          this.SectionHeader('凭据');
          Divider().color('#EEF1F5').strokeWidth(1);
          this.InfoRow('Password', this.rememberPassword ? '已保存' : '未保存');

          Button('清除保存密码')
            .height(42)
            .width('100%')
            .borderRadius(8)
            .backgroundColor(this.rememberPassword ? '#FFF0EE' : '#ECEFF4')
            .fontColor(this.rememberPassword ? '#C7372F' : '#737D8F')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .enabled(this.rememberPassword)
            .stateEffect(true)
            .onClick(() => this.onForgetPassword());
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E2E7EF' });

        if (this.hasError()) {
          Column({ space: 10 }) {
            this.SectionHeader('最近错误');
            Divider().color('#FFD8D3').strokeWidth(1);

            Text(this.errorText)
              .fontSize(13)
              .lineHeight(19)
              .fontColor('#B42318')
              .width('100%');
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor('#FFF8F7')
          .borderRadius(8)
          .border({ width: 1, color: '#FFD8D3' });
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 104, bottom: 104 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA');
  }
}
