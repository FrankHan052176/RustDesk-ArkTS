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

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Text('密码记忆')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(this.rememberPassword ? '当前已记住密码' : '当前未记住密码')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Button('清除已记住密码')
            .height(40)
            .backgroundColor($r('sys.color.ohos_id_color_alert'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.onForgetPassword());
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .borderRadius(28)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_list_separator') });

        Column({ space: 10 }) {
          Text('Bridge Status')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(`Version: ${this.nativeVersion}`)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(`Health: ${this.health}`)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_connected'));

          Text(`Stage: ${this.integrationStage}`)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text(`Upstream: ${this.upstreamRepo}`)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(`API Server: ${this.apiServer || 'unknown'}`)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(`Build: ${this.buildMarker || 'unknown'}`)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(`Decoders: ${this.decoderSummary || 'unknown'}`)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Text(this.notes)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Button('刷新桥状态')
            .height(40)
            .backgroundColor($r('sys.color.ohos_id_color_component_activated'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.onRefresh());
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .borderRadius(28)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_list_separator') });

        if (this.errorText.length > 0) {
          Column({ space: 8 }) {
            Text('错误')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_alert'));

            Text(this.errorText)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_alert'));
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .borderRadius(28);
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 156, bottom: 120 });
    }
    .width('100%')
    .height('100%');
  }
}
