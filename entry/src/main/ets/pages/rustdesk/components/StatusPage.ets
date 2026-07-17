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

@ComponentV2
export struct StatusPage {
  @Param sessionPhase: string = 'idle';
  @Param connectionSummary: string = '未连接';
  @Param sessionMessage: string = '未连接';
  @Param qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @Param renderFpsText: string = 'FPS --';
  @Param frameStatus: string = 'Surface not ready';
  @Param buildMarker: string = '';
  @Local backPressed: boolean = false;
  @Event onBack: () => void = () => {};

  private animateBackPressed(pressed: boolean): void {
    this.getUIContext().animateTo({
      duration: pressed ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.backPressed = pressed;
    });
  }

  @Builder
  private StatusInfo() {
    Column({ space: $r('app.float.space_8') }) {
      Text(`状态: ${this.sessionPhase}`)
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));
      Text(this.connectionSummary)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'));
      Text(this.sessionMessage)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      Text(this.qualitySummary)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      Text(this.renderFpsText)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      Text(this.frameStatus)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      Text(`Build: ${this.buildMarker || 'unknown'}`)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_tertiary'));
    }
    .width('100%')
    .padding($r('app.float.card_padding'))
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.72,
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .borderRadius($r('app.float.radius_24'))
    .clip(true)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private BackButton() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.brand_primary'))
          .opacity(0.86);
        Text('返回连接页')
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_inverse'));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.interactiveContent(
        this.backPressed,
        $r('app.color.point_light'),
      ));
    }
    .width('100%')
    .height($r('app.float.control_regular'))
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
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateBackPressed(true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateBackPressed(false);
      }
    })
    .onClick(() => this.onBack());
  }

  build() {
    Scroll() {
      Column({ space: $r('app.float.space_16') }) {
        Column({ space: 6 }) {
          Text('会话状态')
            .fontSize($r('app.float.font_display'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));

          Text('连接状态与渲染信息集中展示在这里。')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'));
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%');

        this.StatusInfo()
        this.BackButton()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: $r('app.float.page_horizontal'),
        right: $r('app.float.page_horizontal'),
        top: $r('app.float.page_top'),
        bottom: $r('app.float.page_bottom'),
      });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.transparent'));
  }
}
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
