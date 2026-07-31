import { FloatingGlassSurface } from './FloatingSurface';

export const ANDROID_NAVIGATION_BAR_WIDTH = 200;
export const ANDROID_NAVIGATION_BAR_HEIGHT = 45;

@ComponentV2
export struct AndroidNavigationBar {
  @Event onBack: () => void = () => {};
  @Event onHome: () => void = () => {};
  @Event onRecent: () => void = () => {};
  @Event onHide: () => void = () => {};

  @Builder
  private NavigationAction(icon: Resource, label: ResourceStr, onActivate: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize($r('app.float.icon_large'))
        .fontColor([$r('app.color.neu_text_primary')]);
    }
    .width(44)
    .height(44)
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label as Resource)
    .onClick((): void => {
      onActivate();
    });
  }

  @Builder
  private RecentAction(label: ResourceStr, onActivate: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.remote_android_navigation_recent_symbol'))
        .fontSize($r('app.float.icon_large'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));
    }
    .width(44)
    .height(44)
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label as Resource)
    .onClick((): void => {
      onActivate();
    });
  }

  build(): void {
    FloatingGlassSurface({
      compact: true,
      surfaceWidth: ANDROID_NAVIGATION_BAR_WIDTH,
      surfaceHeight: ANDROID_NAVIGATION_BAR_HEIGHT,
      subtleDepth: true,
    }) {
      Row({ space: $r('app.float.space_2') }) {
        this.NavigationAction(
          $r('sys.symbol.chevron_left'),
          $r('app.string.remote_android_navigation_back'),
          () => this.onBack(),
        )
        this.NavigationAction(
          $r('sys.symbol.house'),
          $r('app.string.remote_android_navigation_home'),
          () => this.onHome(),
        )
        this.RecentAction(
          $r('app.string.remote_android_navigation_recent'),
          () => this.onRecent(),
        )

        Column()
          .width($r('app.float.stroke_hairline'))
          .height(25)
          .backgroundColor($r('app.color.neu_text_secondary'))
          .opacity(0.4);

        this.NavigationAction(
          $r('sys.symbol.chevron_down'),
          $r('app.string.remote_android_navigation_hide'),
          () => this.onHide(),
        )
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4') })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween);
    }
  }
}
