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
  @Param controlWidth: number = 0;
  @Param controlHeight: number = 44;
  @Param accessibilityLabel: string = '';
  @Event onChange: (index: number) => void = (_index: number) => {};

  private itemEnabled(index: number): boolean {
    return index >= this.enabledItems.length || this.enabledItems[index];
  }

  build(): void {
    Row({ space: 2 }) {
      ForEach(this.labels, (label: string, index: number) => {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text(label)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(!this.itemEnabled(index)
              ? $r('app.color.neu_text_disabled')
              : (this.selectedIndex === index
                ? $r('app.color.white')
                : $r('app.color.neu_text_primary')))
            .maxLines(1);
        }
        .layoutWeight(1)
        .height('100%')
        .padding(0)
        .enabled(this.itemEnabled(index))
        .backgroundColor(this.selectedIndex === index
          ? $r('app.color.brand_primary')
          : $r('app.color.transparent'))
        .borderRadius($r('app.float.radius_6'))
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
    .width(this.controlWidth > 0 ? this.controlWidth : '100%')
    .height(this.controlHeight >= 44 ? this.controlHeight : 44)
    .padding({ left: 2, right: 2, top: 0, bottom: 0 })
    .backgroundColor($r('app.color.mica_control'))
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_10'))
    .clip(true);
  }
}
