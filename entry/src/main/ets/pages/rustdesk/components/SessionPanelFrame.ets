import { FloatingActionSurface } from './FloatingSurface';

@ComponentV2
export struct SessionPanelFrame {
  @Param title: string = '';
  @Param transitionId: string = '';
  @Event onBack: () => void = () => {};

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  build() {
    Column({ space: $r('app.float.space_12') }) {
      Row({ space: $r('app.float.space_12') }) {
        Stack() {
          FloatingActionSurface({
            compact: true,
            onActivate: () => this.onBack(),
          }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize($r('app.float.icon_small'))
              .fontColor([$r('app.color.text_primary')]);
          }
        }
        .width($r('app.float.control_compact'))
        .height($r('app.float.control_compact'))
        .borderRadius($r('app.float.radius_14'))
        .clip(false)
        .accessibilityText('返回');

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
