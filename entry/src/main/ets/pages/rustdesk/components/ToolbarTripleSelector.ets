export interface ToolbarTripleSelectorProps {
  labels: Array<string>;
  enabledItems?: Array<boolean>;
  selectedIndex: number;
  controlWidth: number;
  controlHeight: number;
  accessibilityLabel: string;
  onChange: (index: number) => void;
}

@ComponentV2
export struct ToolbarTripleSelector {
  @Param labels: Array<string> = [];
  @Param enabledItems: Array<boolean> = [];
  @Param selectedIndex: number = 0;
  @Param controlWidth: number = 180;
  @Param controlHeight: number = 38;
  @Param accessibilityLabel: string = '';
  @Event onChange: (index: number) => void = (_index: number) => {};

  private segmentWidth(): number {
    return this.controlWidth / Math.max(this.labels.length, 1);
  }

  private itemEnabled(index: number): boolean {
    return index >= this.enabledItems.length || this.enabledItems[index];
  }

  build(): void {
    Row() {
      ForEach(this.labels, (label: string, index: number) => {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text(label)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor(!this.itemEnabled(index)
              ? $r('app.color.neu_text_disabled')
              : (this.selectedIndex === index
                ? $r('app.color.white')
                : $r('app.color.neu_text_primary')))
            .maxLines(1);
        }
        .width(this.segmentWidth())
        .height(this.controlHeight)
        .padding(0)
        .enabled(this.itemEnabled(index))
        .backgroundColor(this.selectedIndex === index
          ? $r('app.color.brand_primary')
          : $r('app.color.transparent'))
        .borderRadius($r('app.float.radius_10'))
        .hoverEffect(HoverEffect.Auto)
        .accessibilityText(`${this.accessibilityLabel}，${label}`)
        .accessibilitySelected(this.selectedIndex === index)
        .onClick((): void => {
          if (this.itemEnabled(index) && this.selectedIndex !== index) {
            this.onChange(index);
          }
        });
      }, (label: string, index: number): string => `${label}-${index}`);
    }
    .width(this.controlWidth)
    .height(this.controlHeight)
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .clip(true);
  }
}
