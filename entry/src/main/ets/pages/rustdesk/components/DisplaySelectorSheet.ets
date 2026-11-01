import { PeerDisplayInfo, ResolutionInfo } from '../RustDeskTypes';
import {
  findPeerResolutionIndex,
  getPeerDisplayModeSize,
  RustDeskDisplayMode,
} from '../RustDeskViewportModel';

export interface DisplaySelectorSheetProps {
  displays: PeerDisplayInfo[];
  currentDisplay: number;
  resolutions: ResolutionInfo[];
  selectedResolution?: ResolutionInfo;
  resolutionEnabled: boolean;
  resolutionUnavailableText: string;
  displayMode: RustDeskDisplayMode;
  onSelectDisplayMode: (mode: RustDeskDisplayMode) => void;
  onSelectDisplay: (index: number) => void;
  onSelectResolution: (resolution: ResolutionInfo) => void;
  onClose: () => void;
}

interface DisplayChoiceOptions {
  label: string;
  badge: ResourceStr;
  selected: boolean;
  onClick: () => void;
}

@ComponentV2
export struct DisplaySelectorSheet {
  @Param displays: PeerDisplayInfo[] = [];
  @Param currentDisplay: number = 0;
  @Param resolutions: ResolutionInfo[] = [];
  @Param selectedResolution: ResolutionInfo | undefined = undefined;
  @Param resolutionEnabled: boolean = false;
  /** Why sizes cannot be chosen when `resolutionEnabled` is off; each wire states its own reason. */
  @Param resolutionUnavailableText: string = '远端 OHOS 暂不支持修改显示器分辨率';
  @Param displayMode: RustDeskDisplayMode = 'fit';
  @Event onSelectDisplayMode: (mode: RustDeskDisplayMode) => void = (_mode: RustDeskDisplayMode) => {};
  @Event onSelectDisplay: (index: number) => void = (_index: number) => {};
  @Event onSelectResolution: (resolution: ResolutionInfo) => void = (_resolution: ResolutionInfo) => {};
  @Event onClose: () => void = () => {};

  private displayLabels(): string[] {
    const labels: string[] = [];
    for (let index = 0; index < this.displays.length; index += 1) {
      labels.push(`显示器 ${index + 1}`);
    }
    return labels;
  }

  private displayBadges(): ResourceStr[] {
    const badges: ResourceStr[] = [];
    for (let index = 0; index < this.displays.length; index += 1) {
      const display = this.displays[index];
      const mode = getPeerDisplayModeSize(display);
      badges.push(mode === undefined
        ? $r('app.string.display_badge_pixels', display.width, display.height)
        : $r('app.string.display_badge_mode_pixels', mode.width, mode.height, display.width, display.height));
    }
    return badges;
  }

  private resolutionLabels(): string[] {
    const labels: string[] = [];
    for (let index = 0; index < this.resolutions.length; index += 1) {
      const resolution = this.resolutions[index];
      labels.push(`${resolution.width}×${resolution.height}`);
    }
    return labels;
  }

  private selectedResolutionIndex(): number {
    const display = this.currentDisplay >= 0 && this.currentDisplay < this.displays.length
      ? this.displays[this.currentDisplay] : undefined;
    return findPeerResolutionIndex(display, this.resolutions, this.selectedResolution);
  }

  private selectResolutionIndex(index: number): void {
    if (index < 0 || index >= this.resolutions.length) {
      return;
    }
    this.onSelectResolution(this.resolutions[index]);
  }

  private hasBadge(badge: ResourceStr): boolean {
    return typeof badge !== 'string' || badge.length > 0;
  }

  @Builder
  private ChoiceButton(options: DisplayChoiceOptions) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        Text(options.label)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor(options.selected ? $r('app.color.white') : $r('app.color.neu_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.hasBadge(options.badge)) {
          Text(options.badge)
            .fontSize($r('app.float.font_caption'))
            .fontColor(options.selected ? $r('app.color.white') : $r('app.color.neu_text_secondary'))
            .maxLines(2);
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width(132)
    .height(this.hasBadge(options.badge) ? 68 : 44)
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor(options.selected ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: options.selected ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(options.label)
    .accessibilitySelected(options.selected)
    .onClick((): void => {
      options.onClick();
    });
  }

  @Builder
  private DisplayChoices() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.displayLabels(), (label: string, index: number) => {
        Stack() {
          this.ChoiceButton({
            label: label,
            badge: this.displayBadges()[index] ?? '',
            selected: this.currentDisplay === index,
            onClick: (): void => this.onSelectDisplay(index),
          })
        }
        .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
      }, (label: string, index: number) =>
        `display-${index}-${label}-${this.currentDisplay === index ? 'selected' : 'idle'}`)
    }
    .width('100%');
  }

  private displayModeBadge(mode: RustDeskDisplayMode): string {
    return mode === 'stretch'
      ? '铺满窗口，比例可能失真'
      : mode === 'original'
        ? '按远端像素显示，可拖动查看'
        : '保持比例并留黑边';
  }

  @Builder
  private DisplayModeChoices() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(['stretch', 'fit', 'original'] as RustDeskDisplayMode[],
        (mode: RustDeskDisplayMode, index: number) => {
          Stack() {
            this.ChoiceButton({
              label: mode === 'stretch' ? '拉伸画面' : mode === 'original' ? '原始画面' : '自适应画面',
              badge: this.displayModeBadge(mode),
              selected: this.displayMode === mode,
              onClick: (): void => this.onSelectDisplayMode(mode),
            })
          }
          .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
        },
        (mode: RustDeskDisplayMode) => `display-mode-${mode}-${this.displayMode === mode ? 'selected' : 'idle'}`)
    }
    .width('100%');
  }

  @Builder
  private ResolutionChoices() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.resolutionLabels(), (label: string, index: number) => {
        Stack() {
          this.ChoiceButton({
            label: label,
            badge: '',
            selected: this.selectedResolutionIndex() === index,
            onClick: (): void => this.selectResolutionIndex(index),
          })
        }
        .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
      }, (label: string, index: number) =>
        `resolution-${index}-${label}-${this.selectedResolutionIndex() === index ? 'selected' : 'idle'}`)
    }
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
            this.DisplayChoices();
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: $r('app.float.space_8') }) {
          Text('画面模式')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          Text('只影响本机显示，不改变远端采集设置。')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'));

          this.DisplayModeChoices();
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: $r('app.float.space_8') }) {
          Text('分辨率')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          if (!this.resolutionEnabled) {
            Text(this.resolutionUnavailableText)
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
              this.ResolutionChoices();
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
        top: $r('app.float.space_4'),
        bottom: $r('app.float.space_8'),
      })
      .alignItems(HorizontalAlign.Start)
      .clip(true);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }
}
