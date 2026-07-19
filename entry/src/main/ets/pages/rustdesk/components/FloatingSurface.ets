import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

@ComponentV2
export struct FloatingGlassSurface {
  @Param compact: boolean = false;
  @Param showDepth: boolean = true;
  @Param blurScale: number = 0.48;
  @Param radius: Resource = $r('app.float.radius_14');
  @Param surfaceColor: ResourceColor = $r('app.color.glass_surface');

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  build() {
    Stack() {
      if (this.showDepth) {
        FloatingDepthOverlay({
          compact: this.compact,
          radius: this.radius,
        });
      }

      Stack() {
        this.content();
      }
      .width('100%')
      .height('100%')
      .borderRadius(this.radius)
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());
    }
    .width('100%')
    .backgroundColor(this.surfaceColor)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.blurScale,
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .shadow(this.compact ? ShadowStyle.OUTER_DEFAULT_SM : ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius(this.radius)
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }
}

@ComponentV2
export struct FloatingActionSurface {
  @Param actionEnabled: boolean = true;
  @Param compact: boolean = false;
  @Param touchLight: boolean = false;
  @Param stopTouchPropagation: boolean = false;
  @Param lightPeakIntensity: number = 0.62;
  @Param lightColor: ResourceColor = $r('app.color.point_light');
  @Param radius: Resource = $r('app.float.radius_14');
  @Local pressed: boolean = false;
  @Local touchLightX: number = 24;
  @Local touchLightY: number = 24;
  @Local touchLightIntensity: number = 0;

  @Event onActivate: () => void = () => {};
  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  private updateTouchLightPosition(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    this.touchLightX = event.touches[0].x;
    this.touchLightY = event.touches[0].y;
  }

  private animatePressed(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.pressed = active;
    });
  }

  private animateTouchLight(active: boolean): void {
    if (!this.touchLight) {
      this.touchLightIntensity = 0;
      return;
    }
    this.getUIContext().animateTo({
      duration: active ? 160 : 380,
      curve: Curve.Friction,
    }, () => {
      this.touchLightIntensity = active ? this.lightPeakIntensity : 0;
    });
  }

  private handleTouch(event: TouchEvent): void {
    if (this.stopTouchPropagation) {
      event.stopPropagation();
    }
    if (!this.actionEnabled) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.updateTouchLightPosition(event);
      this.animatePressed(true);
      this.animateTouchLight(true);
    } else if (event.type === TouchType.Move) {
      this.updateTouchLightPosition(event);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.animatePressed(false);
      this.animateTouchLight(false);
    }
  }

  build() {
    Stack() {
      FloatingPressDepthShell({
        pressed: this.actionEnabled && this.pressed,
        compact: this.compact,
        radius: this.radius,
      }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            FloatingDepthOverlay({
              pressed: this.actionEnabled && this.pressed,
              compact: this.compact,
              radius: this.radius,
            });

            Stack() {
              this.content();
            }
            .width('100%')
            .height('100%')
            .borderRadius(this.radius)
            .clip(true)
            .visualEffect(RustDeskGlassEffect.contentReceiver());

            if (this.touchLight) {
              Stack()
                .width(1)
                .height(1)
                .position({ x: this.touchLightX - 0.5, y: this.touchLightY - 0.5 })
                .backgroundColor($r('app.color.transparent'))
                .visualEffect(RustDeskGlassEffect.movableContentSource(
                  this.lightColor,
                  this.touchLightIntensity,
                ))
                .hitTestBehavior(HitTestMode.None);
            }
          }
          .width('100%')
          .height('100%')
          .borderRadius(this.radius)
          .clip(true);
        }
        .width('100%')
        .height('100%')
        .padding(0)
        .enabled(this.actionEnabled)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.actionEnabled && this.pressed ? 0.18 : 0.48,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .borderRadius(this.radius)
        .clip(true)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .onTouch((event: TouchEvent) => this.handleTouch(event))
        .onClick(() => {
          if (this.actionEnabled) {
            this.onActivate();
          }
        });
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.radius)
    .clip(false);
  }
}

@ComponentV2
export struct FloatingSectionHeading {
  @Param title: ResourceStr = '';
  @Param description: ResourceStr = '';
  @Param descriptionMaxLines: number = 2;

  build() {
    Column({ space: $r('app.float.space_4') }) {
      Text(this.title)
        .width('100%')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'));

      if (this.description !== '') {
        Text(this.description)
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(this.descriptionMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}
