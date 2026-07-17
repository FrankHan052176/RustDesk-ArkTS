import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

export interface FloatingSegmentedControlProps {
  labels: ResourceStr[];
  badges: string[];
  selectedIndex: number;
  progress: number;
  controlId: string;
  compact: boolean;
  onPreviewIndex: (index: number) => void;
  onProgressChange: (progress: number) => void;
  onDragStateChange: (dragging: boolean) => void;
  onChange: (index: number) => void;
}

@ComponentV2
export struct FloatingSegmentedControl {
  @Param labels: ResourceStr[] = [];
  @Param badges: string[] = [];
  @Param selectedIndex: number = 0;
  @Param progress: number = -1;
  @Param controlId: string = 'floating-segmented-control';
  @Param compact: boolean = false;
  @Local viewportWidth: number = 0;
  @Local visualProgress: number = 0;
  @Local dragStartProgress: number = 0;
  @Local dragging: boolean = false;
  @Local touchActive: boolean = false;
  @Local previewIndex: number = 0;
  @Local lightRevision: number = 0;
  @Local lightAnchorStep: number = -1;
  @Local sliderLightIntensity: number = 0.12;
  @Event onPreviewIndex: (index: number) => void = (_index: number) => {};
  @Event onProgressChange: (progress: number) => void = (_progress: number) => {};
  @Event onDragStateChange: (dragging: boolean) => void = (_dragging: boolean) => {};
  @Event onChange: (index: number) => void = (_index: number) => {};

  aboutToAppear(): void {
    this.syncExternalProgress();
  }

  @Monitor('selectedIndex')
  private onSelectedIndexChanged(_monitor: IMonitor): void {
    this.syncExternalProgress();
  }

  @Monitor('progress')
  private onProgressChanged(_monitor: IMonitor): void {
    this.syncExternalProgress();
  }

  private itemCount(): number {
    return Math.max(1, this.labels.length);
  }

  private clampIndex(index: number): number {
    return Math.max(0, Math.min(this.itemCount() - 1, index));
  }

  private clampProgress(progress: number): number {
    return Math.max(0, Math.min(this.itemCount() - 1, progress));
  }

  private externalProgress(): number {
    return this.progress >= 0 ? this.progress : this.selectedIndex;
  }

  private syncExternalProgress(): void {
    if (this.dragging) {
      return;
    }
    const next = this.clampProgress(this.externalProgress());
    this.visualProgress = next;
    this.previewIndex = this.clampIndex(Math.round(next));
    this.updateLightAnchor(next);
  }

  private trackWidth(): number {
    return Math.max(0, this.viewportWidth - 8);
  }

  private itemWidth(): number {
    return this.trackWidth() / this.itemCount();
  }

  private sliderX(): number {
    return 4 + this.visualProgress * this.itemWidth();
  }

  private itemPercent(): string {
    return `${100 / this.itemCount()}%`;
  }

  private badgeAt(index: number): string {
    if (index < 0 || index >= this.badges.length) {
      return '';
    }
    return this.badges[index];
  }

  private updateLightAnchor(progress: number): void {
    const step = Math.round(progress * 12);
    if (step !== this.lightAnchorStep) {
      this.lightAnchorStep = step;
      this.lightRevision += 1;
    }
  }

  private animateSliderLight(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 180 : 420,
      curve: Curve.Friction,
    }, () => {
      this.sliderLightIntensity = active ? 0.32 : 0.12;
    });
  }

  private animateToIndex(index: number): void {
    const target = this.clampIndex(index);
    this.previewIndex = target;
    this.updateLightAnchor(target);
    this.getUIContext().animateTo({
      duration: 260,
      curve: Curve.Friction,
    }, () => {
      this.visualProgress = target;
    });
    this.onProgressChange(target);
    this.onChange(target);
  }

  private handleItemTouch(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.previewIndex = this.clampIndex(index);
      this.touchActive = true;
      this.updateLightAnchor(this.visualProgress);
      this.animateSliderLight(true);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.touchActive = false;
      this.animateSliderLight(false);
    }
  }

  private startDrag(): void {
    this.dragging = true;
    this.touchActive = false;
    this.dragStartProgress = this.visualProgress;
    this.previewIndex = this.clampIndex(Math.round(this.visualProgress));
    this.updateLightAnchor(this.visualProgress);
    this.animateSliderLight(true);
    this.onDragStateChange(true);
  }

  private updateDrag(offsetX: number): void {
    const itemWidth = this.itemWidth();
    if (itemWidth <= 0) {
      return;
    }
    const next = this.clampProgress(this.dragStartProgress + offsetX / itemWidth);
    this.visualProgress = next;
    this.onProgressChange(next);
    this.updateLightAnchor(next);
    const nextIndex = this.clampIndex(Math.round(next));
    if (nextIndex !== this.previewIndex) {
      this.previewIndex = nextIndex;
      this.onPreviewIndex(nextIndex);
    }
  }

  private finishDrag(): void {
    const target = this.previewIndex;
    this.dragging = false;
    this.touchActive = false;
    this.getUIContext().animateTo({
      duration: 260,
      curve: Curve.Friction,
    }, () => {
      this.visualProgress = target;
    });
    this.onProgressChange(target);
    this.onChange(target);
    this.onDragStateChange(false);
    this.lightRevision += 1;
    this.animateSliderLight(false);
  }

  @Builder
  private SegmentLabel(index: number, foreground: ResourceColor, fixedWidth: boolean) {
    Row({ space: $r('app.float.space_6') }) {
      Text(this.labels[index])
        .fontSize(this.compact ? $r('app.float.font_label') : $r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor(foreground)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      if (this.badgeAt(index).length > 0) {
        Text(this.badgeAt(index))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor(foreground)
          .maxLines(1);
      }
    }
    .width(fixedWidth ? this.itemWidth() : this.itemPercent())
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private LabelRow(foreground: ResourceColor, fixedWidth: boolean) {
    Row() {
      ForEach(this.labels, (_label: ResourceStr, index: number) => {
        this.SegmentLabel(index, foreground, fixedWidth);
      });
    }
    .width(fixedWidth ? this.trackWidth() : '100%')
    .height('100%');
  }

  @Builder
  private HitTargets() {
    Row() {
      ForEach(this.labels, (label: ResourceStr, index: number) => {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Text(label)
            .width('100%')
            .height('100%')
            .fontSize(1)
            .fontColor($r('app.color.transparent'));
        }
        .layoutWeight(1)
        .height('100%')
        .padding(0)
        .backgroundColor($r('app.color.transparent'))
        .borderRadius($r('app.float.radius_10'))
        .accessibilitySelected(this.selectedIndex === index)
        .onTouch((event: TouchEvent) => this.handleItemTouch(index, event))
        .onClick(() => this.animateToIndex(index));
      });
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.space_4'));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.LabelRow($r('app.color.text_secondary'), false);
      }
      .width(this.trackWidth())
      .height('100%')
      .position({ x: 4, y: 0 });

      if (this.itemWidth() > 0) {
        Stack()
        .width(this.itemWidth())
        .height($r('app.float.control_small'))
        .position({ x: this.sliderX(), y: 4 })
        .id(`${this.controlId}-slider-${this.lightRevision}`)
        .backgroundColor($r('app.color.brand_primary'))
        .borderRadius($r('app.float.radius_10'))
        .clip(true)
        .shadow({
          radius: 7 + this.sliderLightIntensity * 10,
          color: $r('app.color.point_light'),
          offsetX: 0,
          offsetY: 0,
        })
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.sliderLightIntensity > 0,
          $r('app.color.point_light'),
          this.sliderLightIntensity,
        ))
        .renderGroup(true);

        Stack({ alignContent: Alignment.TopStart }) {
          Row()
            .width(this.itemWidth())
            .height($r('app.float.control_small'))
            .position({ x: this.visualProgress * this.itemWidth(), y: 4 })
            .backgroundColor($r('app.color.white'));

          Stack({ alignContent: Alignment.TopStart }) {
            this.LabelRow($r('app.color.white'), false);
          }
          .width('100%')
          .height('100%')
          .blendMode(BlendMode.SRC_IN, BlendApplyType.OFFSCREEN);
        }
        .width(this.trackWidth())
        .height('100%')
        .position({ x: 4, y: 0 })
        .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)
        .renderGroup(true);
      }

      this.HitTargets();
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.dragging || this.touchActive ? 0.90 : 0.48,
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 2 })
        .onActionStart((_event: GestureEvent) => this.startDrag())
        .onActionUpdate((event: GestureEvent) => this.updateDrag(event.offsetX))
        .onActionEnd((_event: GestureEvent) => this.finishDrag())
        .onActionCancel(() => this.finishDrag()),
      GestureMask.Normal,
    );
  }
}
