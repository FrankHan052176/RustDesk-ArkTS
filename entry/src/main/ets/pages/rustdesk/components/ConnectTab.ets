import { LengthMetrics } from '@kit.ArkUI';

export interface ConnectTabProps {
  target: string;
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
  @Prop rememberPassword: boolean = false;
  @Prop canDisconnect: boolean = false;
  scroller: Scroller = new Scroller();
  onTargetChange: (value: string) => void = (_value: string) => {};
  onConnect: () => void = () => {};
  onDisconnect: () => void = () => {};

  private connectButtonText(): string {
    return this.canDisconnect ? '重新连接' : '连接远端';
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 24 }) {
        // Hero Section: Remote ID Input
        Column({ space: 16 }) {
          TextInput({ text: this.target, placeholder: '输入远端设备 ID' })
            .height(64)
            .width('100%')
            .backgroundColor($r('sys.color.ohos_id_color_list_card_bg'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .placeholderColor($r('sys.color.ohos_id_color_text_tertiary'))
            .borderRadius(16)
            .padding({ left: 20, right: 20 })
            .caretColor($r('sys.color.ohos_id_color_component_activated'))
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .onChange((value: string) => this.onTargetChange(value));

          Row({ space: 12 }) {
            Button(this.connectButtonText())
              .height(52)
              .layoutWeight(1)
              .backgroundColor($r('sys.color.ohos_id_color_component_activated'))
              .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .borderRadius(16)
              .shadow(ShadowStyle.OUTER_DEFAULT_SM)
              .onClick(() => this.onConnect());

            if (this.canDisconnect) {
              Button('断开')
                .height(52)
                .width(100)
                .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                .fontColor($r('sys.color.ohos_id_color_warning'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .borderRadius(16)
                .shadow(ShadowStyle.OUTER_DEFAULT_SM)
                .onClick(() => this.onDisconnect());
            }
          }
          .width('100%');
        }
        .width('100%');
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 160, bottom: 120 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
  }
}
