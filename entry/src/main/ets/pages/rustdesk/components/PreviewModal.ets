import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

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

@ComponentV2
export struct PreviewModal {
  @Param visible: boolean = false;
  @Param qualitySummary: string = 'Remote fps --';
  @Param frameStatus: string = 'Surface not ready';
  @Param renderFpsText: string = 'FPS --';
  @Param frameWidth: number = 0;
  @Param frameHeight: number = 0;
  @Local disconnectPressed: boolean = false;
  @Param controller: XComponentController = new XComponentController();
  @Event onDisconnect: () => void = () => {};

  private animateDisconnectBlur(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.disconnectPressed = active;
    });
  }

  build() {
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
            FloatingDepthOverlay({
              radius: $r('app.float.radius_18'),
            });

            Column({ space: $r('app.float.space_4') }) {
              Text(this.qualitySummary)
                .fontSize($r('app.float.font_label'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'));

              Text(this.frameStatus)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'));

              Text(`Surface size: ${this.frameWidth} x ${this.frameHeight} | ${this.renderFpsText}`)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding({
              left: $r('app.float.space_12'),
              right: $r('app.float.space_12'),
              top: $r('app.float.space_8'),
              bottom: $r('app.float.space_8'),
            })
            .alignItems(HorizontalAlign.Start)
            .borderRadius($r('app.float.radius_18'))
            .clip(true)
            .visualEffect(RustDeskGlassEffect.contentReceiver());
          }
          .layoutWeight(1)
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
          .borderRadius($r('app.float.radius_18'))
          .clip(true)
          .shadow(ShadowStyle.OUTER_DEFAULT_MD)
          .visualEffect(RustDeskGlassEffect.featherReceiver());

          Stack() {
            FloatingPressDepthShell({
              pressed: this.disconnectPressed,
              radius: $r('app.float.radius_14'),
              shadowColor: $r('app.color.depth_shadow_level2'),
            }) {
              Button({ type: ButtonType.Normal, stateEffect: false }) {
                Stack() {
                  Row()
                    .width('100%')
                    .height('100%')
                    .backgroundColor($r('app.color.error'));

                  FloatingDepthOverlay({
                    pressed: this.disconnectPressed,
                    radius: $r('app.float.radius_14'),
                  });

                  Row() {
                    Text('断开连接')
                      .fontSize($r('app.float.font_body'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.white'));
                  }
                  .width('100%')
                  .height('100%')
                  .justifyContent(FlexAlign.Center)
                  .borderRadius($r('app.float.radius_14'))
                  .clip(true)
                  .visualEffect(RustDeskGlassEffect.interactiveContent(
                    this.disconnectPressed,
                    $r('app.color.error'),
                    0.66,
                  ));
                }
                .width('100%')
                .height('100%')
                .borderRadius($r('app.float.radius_14'))
                .clip(true);
              }
              .width('100%')
              .height('100%')
              .padding(0)
              .backgroundColor($r('app.color.glass_surface'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
                adaptiveColor: AdaptiveColor.DEFAULT,
                scale: this.disconnectPressed ? 0.18 : 0.48,
              })
              .linearGradient({
                angle: 142,
                colors: [
                  [$r('app.color.glass_gradient_high'), 0],
                  [$r('app.color.glass_gradient_mid'), 0.48],
                  [$r('app.color.glass_gradient_accent'), 1],
                ],
              })
              .borderRadius($r('app.float.radius_14'))
              .clip(true)
              .visualEffect(RustDeskGlassEffect.featherReceiver())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.animateDisconnectBlur(true);
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.animateDisconnectBlur(false);
                }
              })
              .onClick(() => this.onDisconnect());
            }
          }
          .width(112)
          .height($r('app.float.control_regular'))
          .borderRadius($r('app.float.radius_14'))
          .clip(false);
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
