import { PeerDisplayInfo, ResolutionInfo } from '../RustDeskTypes';
import { CollaborationDevicePicker, devicePicker } from '@kit.ServiceCollaborationKit';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import {
  findPeerResolutionIndex,
  getPeerDisplayModeSize,
  RustDeskDisplayMode,
} from '../RustDeskViewportModel';
import {
  DisplaySharePickerEntry,
  displaySharePickerStore,
} from '../../../services/share/DisplaySharePickerStore';

export interface DisplaySelectorSheetProps {
  displays: PeerDisplayInfo[];
  currentDisplay: number;
  resolutions: ResolutionInfo[];
  selectedResolution?: ResolutionInfo;
  resolutionEnabled: boolean;
  resolutionUnavailableText: string;
  displayMode: RustDeskDisplayMode;
  /** Source session owning each card's persistent system picker entry. */
  sessionId: string;
  /** Card-level share action; the page decides whether a press starts or stops it. */
  shareEnabled: boolean;
  shareActive: boolean;
  sharedDisplay: number;
  sharedNetworkId?: string;
  onSelectDisplayMode: (mode: RustDeskDisplayMode) => void;
  onSelectDisplay: (index: number) => void;
  onSelectResolution: (resolution: ResolutionInfo) => void;
  onStopShare: (index: number, networkId: string) => Promise<boolean>;
  /**
   * Device selected from a card's resident picker.
   * Carries both display index and chosen device's networkId.
   */
  onShareDevice: (index: number, networkId: string) => Promise<boolean>;
  onClose: () => void;
}

interface DisplayChoiceOptions {
  label: string;
  badge: ResourceStr;
  selected: boolean;
  onClick: () => void;
}

@ComponentV2
struct DisplayCardItem {
  /** Source session owning this card's persistent picker entry. */
  @Param sessionId: string = '';
  @Param index: number = 0;
  @Param label: string = '';
  @Param badge: ResourceStr = '';
  @Param selected: boolean = false;
  @Param shareOffered: boolean = false;
  @Param isSharingThis: boolean = false;
  @Param isShareLocked: boolean = false;
  @Param sharedNetworkId: string = '';
  @Event onSelect: (index: number) => void = (_index: number) => {};
  @Event onStopShare: (index: number, networkId: string) => Promise<boolean> =
    async (_index: number, _networkId: string): Promise<boolean> => false;
  @Event onShareDevice: (index: number, networkId: string) => Promise<boolean> =
    async (_index: number, _networkId: string): Promise<boolean> => false;

  /** 会话级系统选择器，跨本视图存活；由页面在源关闭/替换时释放。 */
  private entry: DisplaySharePickerEntry | undefined = undefined;
  private pickerMounted: boolean = false;
  /** 本视图已卸载；此后不得再操作它的控件。 */
  private viewDisposed: boolean = false;

  private pickerEntry(): DisplaySharePickerEntry {
    let entry = this.entry;
    if (entry === undefined) {
      entry = displaySharePickerStore.get(this.sessionId, this.index);
      this.entry = entry;
    }
    return entry;
  }

  private syncPickerState(): void {
    const entry = this.pickerEntry();
    if (entry.released || !this.pickerMounted) {
      return;
    }
    if (this.isSharingThis && this.sharedNetworkId.length > 0) {
      if (entry.networkId.length > 0 && entry.networkId !== this.sharedNetworkId) {
        entry.controller.updateState(entry.networkId, devicePicker.BusinessState.IDLE);
      }
      entry.controller.updateState(this.sharedNetworkId, devicePicker.BusinessState.SUCCESSFUL);
      entry.networkId = this.sharedNetworkId;
    } else if (entry.networkId.length > 0) {
      entry.controller.updateState(entry.networkId, devicePicker.BusinessState.IDLE);
      entry.networkId = '';
    }
  }

  @Monitor('isSharingThis', 'sharedNetworkId')
  private onSharingStateChanged(_monitor: IMonitor): void {
    this.syncPickerState();
  }

  private async shareToDevice(networkId: string): Promise<boolean> {
    if (this.isSharingThis) {
      const previousNetworkId = this.sharedNetworkId;
      if (previousNetworkId.length === 0) {
        return false;
      }
      if (previousNetworkId === networkId) {
        return true;
      }
      if (!await this.onStopShare(this.index, previousNetworkId)) {
        return false;
      }
      const entry = this.pickerEntry();
      if (!entry.released && !this.viewDisposed) {
        entry.controller.updateState(previousNetworkId, devicePicker.BusinessState.IDLE);
        entry.networkId = '';
      }
    }
    return this.onShareDevice(this.index, networkId);
  }

  /** 落地真实分享结果；已卸载或已释放的视图只清 busy，不再操作控件。 */
  private settleSelection(entry: DisplaySharePickerEntry, networkId: string, ok: boolean): void {
    if (entry.released || this.viewDisposed) {
      return;
    }
    if (ok) {
      entry.networkId = networkId;
      entry.controller.updateState(networkId, devicePicker.BusinessState.SUCCESSFUL);
    } else {
      entry.controller.updateState(
        networkId,
        devicePicker.BusinessState.FAILED,
        '连接失败，请重试',
      );
    }
  }

  private selectedDevice = (device: distributedDeviceManager.DeviceBasicInfo): void => {
    const networkId = device.networkId;
    const entry = this.pickerEntry();
    if (networkId === undefined || networkId.length === 0 || entry.busy || entry.released
      || this.isShareLocked) {
      return;
    }
    entry.busy = true;
    void this.shareToDevice(networkId)
      .then((ok: boolean): void => {
        this.settleSelection(entry, networkId, ok);
      })
      .catch((_err: Error): void => {
        this.settleSelection(entry, networkId, false);
      }).finally((): void => { entry.busy = false; });
  };

  private unselectedDevice = (device: distributedDeviceManager.DeviceBasicInfo): void => {
    const networkId = device.networkId;
    const entry = this.pickerEntry();
    if (networkId === undefined || networkId.length === 0 || entry.busy || entry.released) {
      return;
    }
    this.handleStopDevice(networkId);
  };

  private deviceOffline = (device: distributedDeviceManager.DeviceBasicInfo): void => {
    const networkId = device.networkId;
    const entry = this.pickerEntry();
    if (networkId === undefined || networkId.length === 0 || entry.busy || entry.released) {
      return;
    }
    this.handleStopDevice(networkId);
  };

  private handleStopDevice(networkId: string): void {
    const entry = this.pickerEntry();
    if (networkId.length === 0 || entry.busy || this.isShareLocked) {
      return;
    }
    entry.busy = true;
    void this.onStopShare(this.index, networkId)
      .then((ok: boolean): void => {
        if (entry.released || this.viewDisposed) { return; }
        if (ok) {
          entry.networkId = '';
          entry.controller.updateState(networkId, devicePicker.BusinessState.IDLE);
        }
      })
      .catch((_err: Error): void => {
        // 停止失败不能标IDLE
      })
      .finally((): void => { entry.busy = false; });
  }

  aboutToAppear(): void {
    const entry = this.pickerEntry();
    if (entry.released) {
      return;
    }
    entry.controller.on('deviceSelected', this.selectedDevice);
    entry.controller.on('deviceUnselected', this.unselectedDevice);
    entry.controller.on('selectedDeviceOffline', this.deviceOffline);
  }

  aboutToDisappear(): void {
    this.viewDisposed = true;
    this.pickerMounted = false;
    const entry = this.entry;
    if (entry === undefined || entry.released) {
      return;
    }
    entry.controller.off('deviceSelected', this.selectedDevice);
    entry.controller.off('deviceUnselected', this.unselectedDevice);
    entry.controller.off('selectedDeviceOffline', this.deviceOffline);
  }

  private hasBadge(): boolean {
    return typeof this.badge !== 'string' || this.badge.length > 0;
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 2 }) {
          Text(this.label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selected ? $r('app.color.white') : $r('app.color.neu_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          if (this.hasBadge()) {
            Text(this.badge)
              .fontSize($r('app.float.font_caption'))
              .fontColor(this.selected ? $r('app.color.white') : $r('app.color.neu_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('app.float.space_12'),
          right: this.shareOffered ? 44 : $r('app.float.space_12'),
          top: $r('app.float.space_8'),
          bottom: $r('app.float.space_8'),
        });
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.selected ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.56,
      })
      .border({
        width: 1,
        color: this.selected ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
      })
      .borderRadius($r('app.float.radius_10'))
      .hoverEffect(HoverEffect.None)
      .accessibilityText(this.label)
      .accessibilitySelected(this.selected)
      .onClick((): void => {
        this.onSelect(this.index);
      });

      if (this.shareOffered) {
        CollaborationDevicePicker({
          controller: this.pickerEntry().controller,
          attribute: { abilityName: '分享显示器', businessDesc: '分享到' },
        })
          .width(32)
          .height(32)
          .margin({ top: 6, right: 6 })
          .enabled(!this.isShareLocked && !this.pickerEntry().busy)
          .opacity(this.isShareLocked ? 0.38 : 1)
          .accessibilityText(`显示器 ${this.index + 1} 选择分享设备`)
          .onAppear((): void => {
            this.pickerMounted = true;
            // updateState reflects business state, not a persisted device selection.
            this.syncPickerState();
          })
          .onDisAppear((): void => {
            this.pickerMounted = false;
          });
      }

    }
    .width(160)
    .height(this.hasBadge() ? 72 : 48)
    .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
  }
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
  /** Source session owning each card's persistent system picker entry. */
  @Param sessionId: string = '';
  /** Every display may be shared while the page allows it, not only the second one. */
  @Param shareEnabled: boolean = false;
  /** The live share owner is active; only the card named by `sharedDisplay` stays actionable. */
  @Param shareActive: boolean = false;
  /** Zero-based display tracked by the live share owner; -1 means none. */
  @Param sharedDisplay: number = -1;
  @Param sharedNetworkId: string = '';
  @Event onSelectDisplayMode: (mode: RustDeskDisplayMode) => void = (_mode: RustDeskDisplayMode) => {};
  @Event onSelectDisplay: (index: number) => void = (_index: number) => {};
  @Event onSelectResolution: (resolution: ResolutionInfo) => void = (_resolution: ResolutionInfo) => {};
  @Event onStopShare: (index: number, networkId: string) => Promise<boolean> =
    async (_index: number, _networkId: string): Promise<boolean> => false;
  @Event onShareDevice: (index: number, networkId: string) => Promise<boolean> =
    async (_index: number, _networkId: string): Promise<boolean> => false;
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
        DisplayCardItem({
          sessionId: this.sessionId,
          index: index,
          label: label,
          badge: this.displayBadges()[index] ?? '',
          selected: this.currentDisplay === index,
          shareOffered: this.isShareOffered(index),
          isSharingThis: this.shareActive && this.sharedDisplay === index,
          isShareLocked: this.isShareLocked(index),
          sharedNetworkId: (this.shareActive && this.sharedDisplay === index) ? this.sharedNetworkId : '',
          onSelect: (displayIndex: number): void => {
            this.onSelectDisplay(displayIndex);
          },
          onStopShare: async (displayIndex: number, networkId: string): Promise<boolean> => {
            return await this.onStopShare(displayIndex, networkId);
          },
          onShareDevice: async (displayIndex: number, networkId: string): Promise<boolean> => {
            return await this.onShareDevice(displayIndex, networkId);
          },
        });
      }, (_label: string, index: number) => `display-card-${this.sessionId}-${index}`)
    }
    .width('100%');
  }

  private isShareOffered(index: number): boolean {
    return this.shareEnabled || this.sharedDisplay === index;
  }

  /**
   * A running share locks the other cards. `shareActive` alone locks all cards
   * if no card is tracked yet, or all other cards when `sharedDisplay` is identified.
   */
  private isShareLocked(index: number): boolean {
    if (!this.shareActive) {
      return false;
    }
    return this.sharedDisplay < 0 || this.sharedDisplay !== index;
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
        (mode: RustDeskDisplayMode) => {
          Stack() {
            this.ChoiceButton({
              label: mode === 'stretch' ? '拉伸画面' : mode === 'original' ? '原始画面' : '自适应画面',
              badge: this.displayModeBadge(mode),
              selected: this.displayMode === mode,
              onClick: (): void => this.onSelectDisplayMode(mode),
            });
          }
          .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
        },
        (mode: RustDeskDisplayMode) => `display-mode-${mode}`)
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
          });
        }
        .margin({ right: $r('app.float.space_8'), bottom: $r('app.float.space_8') });
      }, (_label: string, index: number) => `resolution-${index}`)
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
