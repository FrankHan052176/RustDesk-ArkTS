import {
  LuminousNeoTokens,
  LuminousSurface,
} from 'luminous_neo';

/**
 * 兼容原有业务页面的自适应容器。首次布局只测量内容尺寸；获得实体尺寸后，
 * 真实内容由 LuminousSurface 自己承载，避免在拟态实体上再叠一层顶层容器。
 */
@ComponentV2
export struct FloatingGlassSurface {
  @Param compact: boolean = false;
  @Param showDepth: boolean = true;
  @Param inset: boolean = false;
  @Param subtleDepth: boolean = false;
  @Param radius: Resource = $r('app.float.radius_14');
  /** 已知实体尺寸时直接渲染，避免首帧依赖 onAreaChange 的透明测量分支。 */
  @Param surfaceWidth: number = 0;
  @Param surfaceHeight: number = 0;
  @Local measuredSurfaceWidth: number = 0;
  @Local measuredSurfaceHeight: number = 0;

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  private cornerRadius(): number {
    return this.compact ? 14 : 20;
  }

  private shortEdge(): number {
    return Math.max(1, Math.min(this.resolvedSurfaceHeight(), LuminousNeoTokens.BASE_SURFACE_SIZE));
  }

  private resolvedSurfaceWidth(): number {
    return this.surfaceWidth > 0 ? this.surfaceWidth : this.measuredSurfaceWidth;
  }

  private resolvedSurfaceHeight(): number {
    return this.surfaceHeight > 0 ? this.surfaceHeight : this.measuredSurfaceHeight;
  }

  private shadowPadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(this.shortEdge());
  }

  private surfaceDepth(): number {
    if (!this.showDepth) {
      return 0;
    }
    let depth: number = this.subtleDepth ? LuminousNeoTokens.SUBTLE_RAISED_DEPTH : 1;
    return this.inset ? -depth : depth;
  }

  private hasSurfaceSize(): boolean {
    return this.resolvedSurfaceWidth() > 0 && this.resolvedSurfaceHeight() > 0;
  }

  private updateSurfaceSize(newArea: Area): void {
    let nextWidth: number = Number(newArea.width);
    let nextHeight: number = Number(newArea.height);
    if (this.surfaceWidth <= 0 && this.measuredSurfaceWidth > 0 && nextWidth > 0 &&
      Math.abs(nextWidth - this.measuredSurfaceWidth) > 0.5) {
      this.measuredSurfaceWidth = nextWidth;
      if (this.surfaceHeight <= 0) {
        this.measuredSurfaceHeight = 0;
      }
      return;
    }
    if (this.surfaceWidth <= 0 && nextWidth > 0) {
      this.measuredSurfaceWidth = nextWidth;
    }
    if (this.surfaceHeight <= 0 && nextHeight > 0) {
      this.measuredSurfaceHeight = nextHeight;
    }
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.hasSurfaceSize()) {
        Stack({ alignContent: Alignment.TopStart }) {
          Stack({ alignContent: Alignment.TopStart }) {
            LuminousSurface({
              depth: this.surfaceDepth(),
              surfaceWidth: this.resolvedSurfaceWidth(),
              surfaceHeight: this.resolvedSurfaceHeight(),
              cornerRadius: this.cornerRadius(),
              motionEnabled: true,
              contentAlignment: Alignment.TopStart,
            }) {
              this.content();
            }
          }
          .width(this.resolvedSurfaceWidth() + this.shadowPadding() * 2)
          .height(this.resolvedSurfaceHeight() + this.shadowPadding() * 2)
          .clip(false)
          .position({ x: -this.shadowPadding(), y: -this.shadowPadding() });
        }
        .width('100%')
        .height(this.resolvedSurfaceHeight())
        .clip(false);
      } else {
        Stack() {
          this.content();
        }
        .width('100%')
        .borderRadius(this.radius)
        .clip(true)
        .opacity(0)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no');
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.transparent'))
    .clip(false)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.updateSurfaceSize(newArea);
    });
  }
}

/**
 * Raised 动作面在按下时经真实 Flat 进入 Inset。保留旧参数仅用于兼容调用方，
 * 不再创建触点光源、受光边框或 Hover 阴影。
 */
@ComponentV2
export struct FloatingActionSurface {
  @Param actionEnabled: boolean = true;
  @Param selected: boolean = false;
  @Param compact: boolean = false;
  @Param subtleDepth: boolean = false;
  @Param accessibilityLabel: ResourceStr = '';
  @Param stopTouchPropagation: boolean = false;
  @Param radius: Resource = $r('app.float.radius_14');
  @Local pressed: boolean = false;
  @Local surfaceWidth: number = 0;
  @Local surfaceHeight: number = 0;

  @Event onActivate: () => void = () => {};
  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  private cornerRadius(): number {
    return this.compact ? 14 : 18;
  }

  private shortEdge(): number {
    return Math.max(1, Math.min(this.surfaceHeight, LuminousNeoTokens.BASE_SURFACE_SIZE));
  }

  private shadowPadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(this.shortEdge());
  }

  private surfaceDepth(): number {
    let depth: number = this.subtleDepth ? LuminousNeoTokens.SUBTLE_RAISED_DEPTH : 1;
    return (this.selected || this.pressed) && this.actionEnabled ? -depth : depth;
  }

  private handleTouch(event: TouchEvent): void {
    if (this.stopTouchPropagation) {
      event.stopPropagation();
    }
    if (!this.actionEnabled) {
      this.pressed = false;
      return;
    }
    if (event.type === TouchType.Down) {
      this.pressed = true;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressed = false;
    }
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
        Stack({ alignContent: Alignment.TopStart }) {
          LuminousSurface({
            depth: this.surfaceDepth(),
            surfaceWidth: this.surfaceWidth,
            surfaceHeight: this.surfaceHeight,
            cornerRadius: this.cornerRadius(),
            motionEnabled: true,
          }) {
            Stack() {
              this.content();
            }
            .width('100%')
            .height('100%')
            .accessibilityLevel('no');
          }
        }
        .width(this.surfaceWidth + this.shadowPadding() * 2)
        .height(this.surfaceHeight + this.shadowPadding() * 2)
        .clip(false)
        .position({ x: -this.shadowPadding(), y: -this.shadowPadding() })
        .accessibilityLevel('no');
      }

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
      .width('100%')
      .height('100%')
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.None)
      .borderRadius(this.radius)
      .enabled(this.actionEnabled)
      .accessibilityText(this.accessibilityLabel as Resource)
      .onTouch((event: TouchEvent): void => {
        this.handleTouch(event);
      })
      .onClick((): void => {
        if (this.actionEnabled) {
          this.onActivate();
        }
      })
      .onBlur((): void => {
        this.pressed = false;
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .clip(false)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.updateSurfaceSize(newArea);
    });
  }
}

@ComponentV2
export struct FloatingSectionHeading {
  @Param title: ResourceStr = '';
  @Param description: ResourceStr = '';
  @Param descriptionMaxLines: number = 2;

  build(): void {
    Column({ space: $r('app.float.space_4') }) {
      Text(this.title)
        .width('100%')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));

      if (this.description !== '') {
        Text(this.description)
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .lineHeight(22)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(this.descriptionMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}
