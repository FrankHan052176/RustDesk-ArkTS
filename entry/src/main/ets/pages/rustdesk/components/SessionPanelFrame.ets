import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

@ComponentV2
export struct SessionPanelFrame {
  @Param title: string = '';
  @Param transitionId: string = '';
  @Local backPressed: boolean = false;
  @Event onBack: () => void = () => {};

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  private animateBackBlur(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.backPressed = active;
    });
  }

  build() {
    Column({ space: $r('app.float.space_12') }) {
      Row({ space: $r('app.float.space_12') }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize($r('app.float.icon_small'))
              .fontColor([$r('app.color.text_primary')]);
          }
          .width('100%')
          .height('100%')
          .borderRadius($r('app.float.radius_14'))
          .clip(true)
          .visualEffect(RustDeskGlassEffect.interactiveContent(
            this.backPressed,
            $r('app.color.point_light'),
            0.54,
          ));
        }
        .width($r('app.float.control_compact'))
        .height($r('app.float.control_compact'))
        .padding(0)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.backPressed ? 0.18 : 0.72,
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
        .shadow(ShadowStyle.OUTER_DEFAULT_SM)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .accessibilityText('返回')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.animateBackBlur(true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.animateBackBlur(false);
          }
        })
        .onClick(() => this.onBack());

        Text(this.title)
          .layoutWeight(1)
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .flexShrink(0);

      Stack({ alignContent: Alignment.TopStart }) {
        this.content();
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: $r('app.float.space_4'),
        right: $r('app.float.space_4'),
        bottom: $r('app.float.space_4'),
      })
      .clip(false);
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .geometryTransition(this.transitionId)
    .transition(TransitionEffect.OPACITY);
  }
}
