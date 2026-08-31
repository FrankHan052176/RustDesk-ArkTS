import {
  LuminousButton,
  LuminousControlSize,
  LuminousTone,
} from 'luminous_neo';
import { FloatingGlassSurface } from './FloatingSurface';

export interface PreviewModalProps {
  visible: boolean;
  qualitySummary: string;
  frameStatus: string;
  frameWidth: number;
  frameHeight: number;
  controller: XComponentController;
  onDisconnect: () => void;
}

@ComponentV2
export struct PreviewModal {
  @Param visible: boolean = false;
  @Param qualitySummary: string = 'Remote fps --';
  @Param frameStatus: string = 'Surface not ready';
  @Param frameWidth: number = 0;
  @Param frameHeight: number = 0;
  @Param controller: XComponentController = new XComponentController();
  @Event onDisconnect: () => void = () => {};

  build(): void {
    if (this.visible) {
      Stack({ alignContent: Alignment.Top }) {
        XComponent({
          id: 'rustdesk-preview-surface',
          type: XComponentType.SURFACE,
          controller: this.controller,
        })
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Black);

        Row({ space: $r('app.float.space_12') }) {
          Stack() {
            FloatingGlassSurface({
              radius: $r('app.float.radius_18'),
            }) {
              Column({ space: $r('app.float.space_4') }) {
                Text(this.qualitySummary)
                  .fontSize($r('app.float.font_label'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.neu_text_primary'));

                Text(this.frameStatus)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.neu_text_secondary'));

                Text(`Surface size: ${this.frameWidth} x ${this.frameHeight}`)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.neu_text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .width('100%')
              .height('100%')
              .padding({
                left: $r('app.float.space_12'),
                right: $r('app.float.space_12'),
                top: $r('app.float.space_8'),
                bottom: $r('app.float.space_8'),
              })
              .alignItems(HorizontalAlign.Start);
            }
          }
          .layoutWeight(1)
          .height(78)
          .borderRadius($r('app.float.radius_18'))
          .clip(false);

          LuminousButton({
            label: '断开连接',
            controlWidth: 112,
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Danger,
            motionEnabled: true,
            onAction: (): void => this.onDisconnect(),
          })
            .margin({ top: -12 })
        }
        .width('100%')
        .padding({
          left: $r('app.float.space_16'),
          right: $r('app.float.space_16'),
          top: $r('app.float.space_20'),
        })
        .alignItems(VerticalAlign.Top);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black);
    }
  }
}
