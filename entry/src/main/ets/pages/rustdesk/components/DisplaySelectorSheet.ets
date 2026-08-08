import { PeerDisplayInfo, ResolutionInfo } from '../RustDeskTypes';

export interface DisplaySelectorSheetProps {
  displays: PeerDisplayInfo[];
  currentDisplay: number;
  resolutions: ResolutionInfo[];
  selectedResolution?: ResolutionInfo;
  resolutionEnabled: boolean;
  viewOnlySession: boolean;
  onSelectDisplay: (index: number) => void;
  onSelectResolution: (resolution: ResolutionInfo) => void;
  onClose: () => void;
}

interface DisplayChoiceOptions {
  label: string;
  badge: string;
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
  @Param viewOnlySession: boolean = false;
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

  private displayBadges(): string[] {
    const badges: string[] = [];
    for (let index = 0; index < this.displays.length; index += 1) {
      const display = this.displays[index];
      badges.push(`${display.width}×${display.height}`);
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
  private ChoiceButton(options: DisplayChoiceOptions) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        Text(options.label)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor(options.selected ? $r('app.color.white') : $r('app.color.neu_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (options.badge.length > 0) {
          Text(options.badge)
            .fontSize($r('app.float.font_caption'))
            .fontColor(options.selected ? $r('app.color.white') : $r('app.color.neu_text_secondary'))
            .maxLines(1);
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width(132)
    .height(options.badge.length > 0 ? 52 : 44)
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
          Text('分辨率')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          if (!this.resolutionEnabled) {
            Text(this.viewOnlySession
              ? '只观看模式不修改远端分辨率'
              : '远端 OHOS 暂不支持修改显示器分辨率')
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
