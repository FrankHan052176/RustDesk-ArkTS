@ComponentV2
export struct SessionPanelFrame {
  @Param title: string = '';
  @Param transitionId: string = '';
  @Event onBack: () => void = () => {};

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  build() {
    Column({ space: $r('app.float.space_8') }) {
      Row({ space: $r('app.float.space_8') }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize($r('app.float.icon_small'))
            .fontColor([$r('app.color.neu_text_primary')]);
        }
        .width($r('app.float.control_compact'))
        .height($r('app.float.control_compact'))
        .padding(0)
        .backgroundColor($r('app.color.mica_control'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.56,
        })
        .border({ width: 1, color: $r('app.color.mica_border') })
        .borderRadius($r('app.float.radius_10'))
        .hoverEffect(HoverEffect.None)
        .accessibilityText('返回')
        .onClick((): void => {
          this.onBack();
        });

        Text(this.title)
          .layoutWeight(1)
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .height(44)
      .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_8') })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.mica_control'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.56,
      })
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .flexShrink(0)
      .zIndex(2);

      Stack({ alignContent: Alignment.TopStart }) {
        this.content();
      }
      .width('100%')
      .layoutWeight(1)
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .zIndex(1);
    }
    .width('100%')
    .height('100%')
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .geometryTransition(this.transitionId)
    .transition(TransitionEffect.OPACITY);
  }
}
