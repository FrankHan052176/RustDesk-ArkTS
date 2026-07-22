import {
  LuminousNeoTokens,
  LuminousSegmentedControl,
  LuminousSelectionItem,
} from 'luminous_neo';

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

/**
 * 原业务接口的兼容层。多选项统一交给 LuminousSegmentedControl：Inset 槽底、
 * Raised 滑块、点击与拖动共用同一套几何与无障碍语义。
 */
@ComponentV2
export struct FloatingSegmentedControl {
  @Param labels: ResourceStr[] = [];
  @Param badges: string[] = [];
  @Param selectedIndex: number = 0;
  @Param progress: number = -1;
  @Param controlId: string = 'floating-segmented-control';
  @Param compact: boolean = false;
  @Local viewportWidth: number = 0;
  @Event onPreviewIndex: (index: number) => void = (_index: number) => {};
  @Event onProgressChange: (progress: number) => void = (_progress: number) => {};
  @Event onDragStateChange: (dragging: boolean) => void = (_dragging: boolean) => {};
  @Event onChange: (index: number) => void = (_index: number) => {};

  private controlHeight(): number {
    return this.compact ? 52 : 56;
  }

  private fallbackWidth(): number {
    return this.compact ? 300 : 420;
  }

  private framePadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(this.controlHeight());
  }

  private controlWidth(): number {
    let available: number = this.viewportWidth > 0 ? this.viewportWidth : this.fallbackWidth();
    return Math.max(180, available - this.framePadding() * 2);
  }

  private frameHeight(): number {
    return this.controlHeight() + this.framePadding() * 2;
  }

  private badgeAt(index: number): string {
    if (index < 0 || index >= this.badges.length) {
      return '';
    }
    return this.badges[index];
  }

  private selectionItems(): LuminousSelectionItem[] {
    let items: LuminousSelectionItem[] = [];
    for (let index: number = 0; index < this.labels.length; index++) {
      let badge: string = this.badgeAt(index);
      let description: string = badge.length > 0 ? `数量 ${badge}` : '';
      items.push(new LuminousSelectionItem(
        `${this.controlId}-${index}`,
        this.labels[index],
        description,
        true,
      ));
    }
    return items;
  }

  private commitIndex(index: number): void {
    this.onPreviewIndex(index);
    this.onProgressChange(index);
    this.onDragStateChange(false);
    this.onChange(index);
  }

  build(): void {
    Row() {
      LuminousSegmentedControl({
        items: this.selectionItems(),
        selectedIndex: this.selectedIndex,
        controlWidth: this.controlWidth(),
        controlHeight: this.controlHeight(),
        onChange: (index: number): void => {
          this.commitIndex(index);
        },
      })
    }
    .width('100%')
    .height(this.frameHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .clip(false)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      let width: number = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
