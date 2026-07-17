import { PeerDisplayInfo, ResolutionInfo } from '../RustDeskTypes';
import { FloatingSegmentedControl } from './FloatingSegmentedControl';

export interface DisplaySelectorSheetProps {
  displays: PeerDisplayInfo[];
  currentDisplay: number;
  resolutions: ResolutionInfo[];
  selectedResolution?: ResolutionInfo;
  resolutionEnabled: boolean;
  onSelectDisplay: (index: number) => void;
  onSelectResolution: (resolution: ResolutionInfo) => void;
  onClose: () => void;
}

@ComponentV2
export struct DisplaySelectorSheet {
  @Param displays: PeerDisplayInfo[] = [];
  @Param currentDisplay: number = 0;
  @Param resolutions: ResolutionInfo[] = [];
  @Param selectedResolution: ResolutionInfo | undefined = undefined;
  @Param resolutionEnabled: boolean = false;
  @Event onSelectDisplay: (index: number) => void = (_index: number) => {};
  @Event onSelectResolution: (resolution: ResolutionInfo) => void = (_resolution: ResolutionInfo) => {};
  @Event onClose: () => void = () => {};

  private displayLabels(): ResourceStr[] {
    const labels: ResourceStr[] = [];
    for (let index = 0; index < this.displays.length; index += 1) {
      labels.push(`显示器 ${index + 1}`);
    }
    return labels;
  }

  private displayBadges(): string[] {
    const badges: string[] = [];
    for (let index = 0; index < this.displays.length; index += 1) {
      const display = this.displays[index];
      badges.push(`${display.width}×${display.height}`);
    }
    return badges;
  }

  private resolutionLabels(): ResourceStr[] {
    const labels: ResourceStr[] = [];
    for (let index = 0; index < this.resolutions.length; index += 1) {
      const resolution = this.resolutions[index];
      labels.push(`${resolution.width}×${resolution.height}`);
    }
    return labels;
  }

  private selectedResolutionIndex(): number {
    for (let index = 0; index < this.resolutions.length; index += 1) {
      const resolution = this.resolutions[index];
      if (this.selectedResolution !== undefined
        && this.selectedResolution.width === resolution.width
        && this.selectedResolution.height === resolution.height) {
        return index;
      }
      if (this.selectedResolution === undefined
        && this.currentDisplay >= 0
        && this.currentDisplay < this.displays.length
        && this.displays[this.currentDisplay].width === resolution.width
        && this.displays[this.currentDisplay].height === resolution.height) {
        return index;
      }
    }
    return 0;
  }

  private selectResolutionIndex(index: number): void {
    if (index < 0 || index >= this.resolutions.length) {
      return;
    }
    this.onSelectResolution(this.resolutions[index]);
  }

  @Builder
  private DisplaySegmentedControl() {
    FloatingSegmentedControl({
      labels: this.displayLabels(),
      badges: this.displayBadges(),
      selectedIndex: this.currentDisplay,
      progress: -1,
      controlId: 'session-display-selector',
      compact: true,
      onPreviewIndex: (_index: number) => {},
      onProgressChange: (_progress: number) => {},
      onDragStateChange: (_dragging: boolean) => {},
      onChange: (index: number) => this.onSelectDisplay(index),
    })
    .width('100%');
  }

  @Builder
  private ResolutionSegmentedControl() {
    FloatingSegmentedControl({
      labels: this.resolutionLabels(),
      badges: [],
      selectedIndex: this.selectedResolutionIndex(),
      progress: -1,
      controlId: 'session-resolution-selector',
      compact: true,
      onPreviewIndex: (_index: number) => {},
      onProgressChange: (_progress: number) => {},
      onDragStateChange: (_dragging: boolean) => {},
      onChange: (index: number) => this.selectResolutionIndex(index),
    })
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: $r('app.float.space_24') }) {
        Column({ space: $r('app.float.space_8') }) {
          Text('显示器')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          if (this.displays.length === 0) {
            Text('暂未获取到远端显示器信息')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'))
              .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
          } else {
            this.DisplaySegmentedControl();
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: $r('app.float.space_8') }) {
          Text('分辨率')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          if (!this.resolutionEnabled) {
            Text('远端 OHOS 暂不支持修改显示器分辨率')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'))
              .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
          } else {
            if (this.resolutions.length === 0) {
              Text('远端未提供可选分辨率')
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_secondary'))
                .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
            } else {
              this.ResolutionSegmentedControl();
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({
        left: $r('app.float.space_8'),
        right: $r('app.float.space_8'),
        bottom: $r('app.float.space_8'),
      })
      .alignItems(HorizontalAlign.Start)
      .clip(false);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .clip(false);
  }
}
