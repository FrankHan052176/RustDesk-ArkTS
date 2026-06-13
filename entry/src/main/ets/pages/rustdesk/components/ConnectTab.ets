import { Chip, ChipSize, LengthMetrics } from '@kit.ArkUI';

interface StatusChipOptions {
  text: string;
  color: string;
  backgroundColor: string;
  activated?: boolean;
}

export interface ConnectTabProps {
  target: string;
  connectionSummary: string;
  sessionMessage: string;
  sessionPhase: string;
  qualitySummary: string;
  frameStatus: string;
  renderFpsText: string;
  rememberPassword: boolean;
  scroller: Scroller;
  onTargetChange: (value: string) => void;
  onConnect: () => void;
  onDisconnect: () => void;
  canDisconnect: boolean;
}

@Component
export struct ConnectTab {
  @Prop target: string = '';
  @Prop connectionSummary: string = 'Not connected';
  @Prop sessionMessage: string = 'No session yet.';
  @Prop sessionPhase: string = 'idle';
  @Prop qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @Prop frameStatus: string = 'Surface not ready';
  @Prop renderFpsText: string = 'FPS --';
  @Prop rememberPassword: boolean = false;
  @Prop canDisconnect: boolean = false;
  scroller: Scroller = new Scroller();
  onTargetChange: (value: string) => void = (_value: string) => {};
  onConnect: () => void = () => {};
  onDisconnect: () => void = () => {};

  private isLive(): boolean {
    return this.canDisconnect && this.sessionPhase !== 'idle' && this.sessionPhase !== 'closed';
  }

  private phaseLabel(): string {
    switch (this.sessionPhase) {
      case 'idle':
        return '待连接';
      case 'starting':
      case 'connecting':
        return '连接中';
      case 'awaiting_password':
        return '待验证';
      case 'ready':
      case 'connected':
        return '在线';
      case 'closed':
        return '已关闭';
      default:
        return this.sessionPhase || '未知';
    }
  }

  private phaseTone(): string {
    if (this.sessionPhase === 'ready' || this.sessionPhase === 'connected') {
      return '#16875A';
    }
    if (this.sessionPhase === 'awaiting_password') {
      return '#A06000';
    }
    if (this.isLive()) {
      return '#2F6BFF';
    }
    return '#5C6676';
  }

  private phaseBg(): string {
    if (this.sessionPhase === 'ready' || this.sessionPhase === 'connected') {
      return '#E9F7F0';
    }
    if (this.sessionPhase === 'awaiting_password') {
      return '#FFF2CF';
    }
    if (this.isLive()) {
      return '#EAF1FF';
    }
    return '#ECEFF4';
  }

  private connectButtonText(): string {
    return this.isLive() ? '重新连接' : '连接远端';
  }

  private shortQuality(): string {
    const text = this.qualitySummary.replace('Remote fps ', 'fps ');
    return text.length > 0 ? text : '--';
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
  private FieldLabel(text: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor('#697386')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis });
  }

  @Builder
  private SignalCell(label: string, value: string, tone: string) {
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

  @Builder
  private InfoLine(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(76)
        .fontSize(12)
        .fontColor('#737D8F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(value || '--')
        .layoutWeight(1)
        .fontSize(13)
        .lineHeight(18)
        .fontColor('#1F2937')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .height(38)
    .alignItems(VerticalAlign.Center);
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Row() {
          Row({ space: 10 }) {
            Stack() {
              Text('R')
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
              Text('RustDesk HMOS')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#121826')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });

              Text(this.connectionSummary)
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
            text: this.phaseLabel(),
            color: this.phaseTone(),
            backgroundColor: this.phaseBg(),
            activated: this.isLive()
          });
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Column({ space: 12 }) {
          Row({ space: 8 }) {
            this.StatusChip({ text: this.rememberPassword ? '密码已保存' : '手动验证', color: '#5C6676', backgroundColor: '#ECEFF4' });
            this.StatusChip({ text: this.canDisconnect ? '会话已创建' : '无活动会话', color: this.canDisconnect ? '#16875A' : '#5C6676', backgroundColor: this.canDisconnect ? '#E9F7F0' : '#ECEFF4' });
            this.StatusChip({ text: 'API 23 Chip', color: '#2F6BFF', backgroundColor: '#EAF1FF' });
          }
          .width('100%');

          Column({ space: 8 }) {
            this.FieldLabel('远端 ID / IP');

            TextInput({ text: this.target, placeholder: '输入远端 ID、IP 或 id@server' })
              .height(52)
              .width('100%')
              .backgroundColor('#F7F9FC')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .placeholderColor('#98A2B3')
              .borderRadius(8)
              .border({ width: 1, color: '#D9E0EA' })
              .padding({ left: 14, right: 14 })
              .caretColor('#2F6BFF')
              .onChange((value: string) => this.onTargetChange(value));
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Row({ space: 10 }) {
            Button(this.connectButtonText())
              .height(46)
              .layoutWeight(1)
              .backgroundColor('#2F6BFF')
              .fontColor('#FFFFFF')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .borderRadius(8)
              .stateEffect(true)
              .onClick(() => this.onConnect());

            if (this.canDisconnect) {
              Button('断开')
                .height(46)
                .width(92)
                .backgroundColor('#FFF0EE')
                .fontColor('#C7372F')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .borderRadius(8)
                .stateEffect(true)
                .onClick(() => this.onDisconnect());
            }
          }
          .width('100%');
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E2E7EF' });

        Row({ space: 8 }) {
          this.SignalCell('Session', this.phaseLabel(), this.phaseTone());
          this.SignalCell('Render', this.renderFpsText, '#2F6BFF');
        }
        .width('100%');

        Column({ space: 8 }) {
          this.InfoLine('Quality', this.shortQuality());
          Divider().color('#EEF1F5').strokeWidth(1);
          this.InfoLine('Surface', this.frameStatus);
          Divider().color('#EEF1F5').strokeWidth(1);
          this.InfoLine('Message', this.sessionMessage);
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E2E7EF' });
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
