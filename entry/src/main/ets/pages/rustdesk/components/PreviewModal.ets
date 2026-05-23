export interface PreviewModalProps {
  visible: boolean;
  qualitySummary: string;
  frameStatus: string;
  renderFpsText: string;
  frameWidth: number;
  frameHeight: number;
  controller: XComponentController;
  onDisconnect: () => void;
}

@Component
export struct PreviewModal {
  @Prop visible: boolean = false;
  @Prop qualitySummary: string = 'Remote fps --';
  @Prop frameStatus: string = 'Surface not ready';
  @Prop renderFpsText: string = 'FPS --';
  @Prop frameWidth: number = 0;
  @Prop frameHeight: number = 0;
  controller: XComponentController = new XComponentController();
  onDisconnect: () => void = () => {};

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 10 }) {
          Text(this.qualitySummary)
            .fontSize(12)
            .fontColor('#D6E2F0');

          Text(this.frameStatus)
            .fontSize(12)
            .fontColor('#9FB2C8');

          Text(`Surface size: ${this.frameWidth} x ${this.frameHeight} | ${this.renderFpsText}`)
            .fontSize(12)
            .fontColor('#9FB2C8');

          XComponent({
            id: 'rustdesk-preview-surface',
            type: XComponentType.SURFACE,
            controller: this.controller
          })
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#000000');
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 20, bottom: 20 })
        .backgroundColor('#000000');

        Button('断开连接')
          .margin({ top: 20, right: 20 })
          .height(38)
          .backgroundColor('#C93C4A')
          .fontColor('#FFFFFF')
          .onClick(() => this.onDisconnect());
      }
      .width('100%')
      .height('100%');
    }
  }
}
