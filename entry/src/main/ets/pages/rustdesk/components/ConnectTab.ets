export interface ConnectTabProps {
  target: string;
  connectionSummary: string;
  sessionMessage: string;
  sessionPhase: string;
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
  @Prop rememberPassword: boolean = false;
  @Prop canDisconnect: boolean = false;
  scroller: Scroller = new Scroller();
  onTargetChange: (value: string) => void = (_value: string) => {};
  onConnect: () => void = () => {};
  onDisconnect: () => void = () => {};

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Text('Resk')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));

          Text('输入目标地址后开始连接，密码将在后续弹框中输入。')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));

          Row({ space: 10 }) {
            Text(`状态 ${this.sessionPhase}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor($r('sys.color.ohos_id_color_text_field_sub_bg'))
              .borderRadius(999);

            if (this.rememberPassword) {
              Text('已记住密码')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor($r('sys.color.ohos_id_color_text_field_sub_bg'))
                .borderRadius(999);
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 4, right: 4, top: 6, bottom: 10 });

        Column({ space: 12 }) {
          Text('目标设备')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%');

          TextInput({ text: this.target, placeholder: 'Peer target or IP' })
            .height(54)
            .backgroundColor($r('sys.color.ohos_id_color_text_field_sub_bg'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
            .borderRadius(22)
            .padding({ left: 18, right: 18 })
            .onChange((value: string) => this.onTargetChange(value));

          if (this.rememberPassword) {
            Text('已记住上次密码，连接后仍会弹框确认。')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%');
          }

          Button('连接')
            .height(48)
            .backgroundColor($r('sys.color.ohos_id_color_component_activated'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .borderRadius(24)
            .onClick(() => this.onConnect());

          if (this.canDisconnect) {
            Button('断开连接')
              .height(40)
              .backgroundColor($r('sys.color.ohos_id_color_alert'))
              .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
              .borderRadius(20)
              .onClick(() => this.onDisconnect());
          }

          Divider()
            .color($r('sys.color.ohos_id_color_list_separator'))
            .strokeWidth(1);

          Column({ space: 8 }) {
            Text('连接摘要')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .width('100%');

            Text(this.connectionSummary)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .width('100%');

            Text(this.sessionMessage)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%');
          }
          .width('100%');
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
