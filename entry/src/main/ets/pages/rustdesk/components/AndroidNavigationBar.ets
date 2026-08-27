import { FloatingGlassSurface } from './FloatingSurface';

export const ANDROID_NAVIGATION_BAR_WIDTH = 140;
export const ANDROID_NAVIGATION_BAR_HEIGHT = 32;
export const ANDROID_NAVIGATION_COLLAPSED_WIDTH = 36;
export const ANDROID_NAVIGATION_COLLAPSED_HEIGHT = 32;

@ComponentV2
export struct AndroidNavigationBar {
  @Param collapsed: boolean = false;
  @Event onBack: () => void = () => {};
  @Event onHome: () => void = () => {};
  @Event onRecent: () => void = () => {};
  @Event onHide: () => void = () => {};

  @Builder
  private NavigationAction(icon: Resource, label: ResourceStr, onActivate: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([$r('app.color.neu_text_primary')]);
    }
    .width(30)
    .height(30)
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_6'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label as Resource)
    .onClick((): void => {
      onActivate();
    });
  }

  build(): void {
    FloatingGlassSurface({
      compact: true,
      surfaceWidth: this.collapsed ? ANDROID_NAVIGATION_COLLAPSED_WIDTH : ANDROID_NAVIGATION_BAR_WIDTH,
      surfaceHeight: this.collapsed ? ANDROID_NAVIGATION_COLLAPSED_HEIGHT : ANDROID_NAVIGATION_BAR_HEIGHT,
      subtleDepth: true,
    }) {
      if (this.collapsed) {
        Row() {
          this.NavigationAction(
            $r('sys.symbol.chevron_left'),
            '展开安卓导航键',
            () => this.onHide(),
          )
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center);
      } else {
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
          this.NavigationAction(
            $r('sys.symbol.square'),
            $r('app.string.remote_android_navigation_recent'),
            () => this.onRecent(),
          )

          Column()
            .width($r('app.float.stroke_hairline'))
            .height(18)
            .backgroundColor($r('app.color.neu_text_secondary'))
            .opacity(0.4);

          this.NavigationAction(
            $r('sys.symbol.chevron_down'),
            '收起安卓导航键',
            () => this.onHide(),
          )
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_2'), right: $r('app.float.space_2') })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.SpaceBetween);
      }
    }
  }
}
