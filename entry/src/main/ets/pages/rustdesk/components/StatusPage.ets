export interface StatusPageProps {
  sessionPhase: string;
  connectionSummary: string;
  sessionMessage: string;
  qualitySummary: string;
  renderFpsText: string;
  frameStatus: string;
  buildMarker: string;
  onBack: () => void;
}

@Component
export struct StatusPage {
  @Prop sessionPhase: string = 'idle';
  @Prop connectionSummary: string = '未连接';
  @Prop sessionMessage: string = '未连接';
  @Prop qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @Prop renderFpsText: string = 'FPS --';
  @Prop frameStatus: string = 'Surface not ready';
  @Prop buildMarker: string = '';
  onBack: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('会话状态')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text('连接状态与渲染信息集中展示在这里。')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 4, right: 4, top: 14, bottom: 10 });

        Column({ space: 10 }) {
          Text(`状态: ${this.sessionPhase}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(this.connectionSummary)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(this.sessionMessage)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(this.qualitySummary)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(this.renderFpsText)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(this.frameStatus)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(`Build: ${this.buildMarker || 'unknown'}`)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Button('返回连接页')
            .height(42)
            .backgroundColor($r('sys.color.ohos_id_color_component_activated'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .borderRadius(21)
            .onClick(() => this.onBack());
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .borderRadius(28)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_list_separator') });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 18, bottom: 120 });
    }
    .width('100%')
    .height('100%');
  }
}
