import {
  LuminousNeoTokens,
  LuminousSurface,
  LuminousSurfaceState,
} from 'luminous_neo';

/**
 * 旧浮层深度装饰的兼容入口。实际深度统一由 LuminousSurface 绘制，
 * 不再叠加玻璃高光、方向性渐变或独立的触点光源。
 */
@ComponentV2
export struct FloatingDepthOverlay {
  @Param pressed: boolean = false;
  @Param inset: boolean = false;
  @Param compact: boolean = false;
  @Param radius: Resource = $r('app.float.radius_14');
  @Local surfaceWidth: number = 0;
  @Local surfaceHeight: number = 0;

  private cornerRadius(): number {
    return this.compact ? 14 : 20;
  }

  private shortEdge(): number {
    return Math.max(1, Math.min(this.surfaceHeight, LuminousNeoTokens.BASE_SURFACE_SIZE));
  }

  private shadowPadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(this.shortEdge());
  }

  private surfaceState(): LuminousSurfaceState {
    return this.inset || this.pressed ? LuminousSurfaceState.Inset : LuminousSurfaceState.Raised;
  }

  private updateSurfaceSize(newArea: Area): void {
    let nextWidth: number = Number(newArea.width);
    let nextHeight: number = Number(newArea.height);
    if (nextWidth > 0) {
      this.surfaceWidth = nextWidth;
    }
    if (nextHeight > 0) {
      this.surfaceHeight = nextHeight;
    }
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.surfaceWidth > 0 && this.surfaceHeight > 0) {
        Stack() {
          LuminousSurface({
            state: this.surfaceState(),
            surfaceWidth: this.surfaceWidth,
            surfaceHeight: this.surfaceHeight,
            cornerRadius: this.cornerRadius(),
            raisedShadowDistance: LuminousNeoTokens.raisedDistanceFor(this.shortEdge()),
            raisedShadowBlur: LuminousNeoTokens.raisedBlurFor(this.shortEdge()),
            insetShadowDistance: LuminousNeoTokens.insetDistanceFor(this.shortEdge()),
            insetShadowBlur: LuminousNeoTokens.insetBlurFor(this.shortEdge()),
          }) {
            Stack()
          }
        }
        .position({ x: -this.shadowPadding(), y: -this.shadowPadding() });
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no')
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.updateSurfaceSize(newArea);
    });
  }
}
