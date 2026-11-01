import {
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSlider,
  LuminousSwitch,
} from 'luminous_neo';
import { FALLBACK_REFRESH_RATE } from '../RustDeskRefreshRate';
import { RustDeskRightClickGesture, SessionDefaults } from '../RustDeskDirectoryTypes';
import { copySessionDefaults } from '../DirectSessionSettings';

export type SessionDefaultsSection = 'all' | 'input' | 'quality' | 'other';

export interface SessionDefaultsCardProps {
  showHeader: boolean;
  section: SessionDefaultsSection;
  defaults: SessionDefaults;
  /** Rates this device can show, ascending. Owned by the page, not the card. */
  refreshRateChoices: number[];
  onDefaultsChange: (defaults: SessionDefaults) => void;
}

@ComponentV2
export struct SessionDefaultsCard {
  @Param showHeader: boolean = true;
  @Param section: SessionDefaultsSection = 'all';
  @Param defaults: SessionDefaults = new SessionDefaults();
  @Param refreshRateChoices: number[] = [FALLBACK_REFRESH_RATE];
  @Local viewportWidth: number = 390;
  @Local displayedAudioEnabled: boolean = true;
  @Local displayedClipboardEnabled: boolean = true;
  @Local displayedGesturesEnabled: boolean = true;
  @Local displayedToolbarExpanded: boolean = false;
  @Local displayedSessionSharingEnabled: boolean = false;
  @Event onDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults) => {};

  aboutToAppear(): void {
    this.syncDisplayedToggleStates();
  }

  @Monitor('defaults')
  private onDefaultsChanged(_monitor: IMonitor): void {
    this.syncDisplayedToggleStates();
  }

  private syncDisplayedToggleStates(): void {
    this.displayedAudioEnabled = this.defaults.audioEnabled;
    this.displayedClipboardEnabled = this.defaults.clipboardEnabled;
    this.displayedGesturesEnabled = this.defaults.gesturesEnabled;
    this.displayedToolbarExpanded = this.defaults.toolbarExpanded;
    this.displayedSessionSharingEnabled = this.defaults.sessionSharingEnabled;
  }

  private isWide(): boolean {
    return this.viewportWidth >= 720;
  }

  private copyDefaults(): SessionDefaults {
    return copySessionDefaults(this.defaults);
  }

  private emit(next: SessionDefaults): void {
    this.onDefaultsChange(next);
  }

  private updatePointerMode(index: number): void {
    const next = this.copyDefaults();
    next.touchMode = index === 0;
    next.relativeMouseMode = index === 2;
    this.emit(next);
  }

  private pointerModeIndex(): number {
    if (this.defaults.touchMode) {
      return 0;
    }
    return this.defaults.relativeMouseMode ? 2 : 1;
  }

  private updateRightClickGesture(index: number): void {
    const next = this.copyDefaults();
    const gesture: RustDeskRightClickGesture = index === 0
      ? 'double_tap'
      : (index === 1 ? 'two_finger_tap' : 'long_press');
    next.rightClickGesture = gesture;
    this.emit(next);
  }

  private rightClickGestureIndex(): number {
    if (this.defaults.rightClickGesture === 'double_tap') {
      return 0;
    }
    return this.defaults.rightClickGesture === 'two_finger_tap' ? 1 : 2;
  }

  private updateAudio(enabled: boolean): void {
    this.displayedAudioEnabled = enabled;
    const next = this.copyDefaults();
    next.audioEnabled = enabled;
    this.emit(next);
  }

  private updateClipboard(enabled: boolean): void {
    this.displayedClipboardEnabled = enabled;
    const next = this.copyDefaults();
    next.clipboardEnabled = enabled;
    this.emit(next);
  }

  private updateGestures(enabled: boolean): void {
    this.displayedGesturesEnabled = enabled;
    const next = this.copyDefaults();
    next.gesturesEnabled = enabled;
    this.emit(next);
  }

  private updateToolbar(enabled: boolean): void {
    this.displayedToolbarExpanded = enabled;
    const next = this.copyDefaults();
    next.toolbarExpanded = enabled;
    this.emit(next);
  }

  private updateSessionSharing(enabled: boolean): void {
    this.displayedSessionSharingEnabled = enabled;
    const next = this.copyDefaults();
    next.sessionSharingEnabled = enabled;
    this.emit(next);
  }

  private updateRefreshRate(value: number): void {
    const next = this.copyDefaults();
    next.refreshRate = this.clampRefreshRate(value);
    this.emit(next);
  }

  private updateCodec(codec: string): void {
    const next = this.copyDefaults();
    next.preferredCodec = codec;
    this.emit(next);
  }

  private rateChoices(): number[] {
    return this.refreshRateChoices.length > 0 ? this.refreshRateChoices : [FALLBACK_REFRESH_RATE];
  }

  private clampRefreshRate(value: number): number {
    const choices = this.rateChoices();
    if (!Number.isFinite(value)) {
      return choices[choices.length - 1];
    }
    return Math.min(choices[choices.length - 1], Math.max(choices[0], Math.round(value)));
  }

  private refreshRateIndex(): number {
    return Math.max(0, this.rateChoices().indexOf(this.clampRefreshRate(this.defaults.refreshRate)));
  }

  private updateRefreshRateIndex(index: number): void {
    const choice = this.rateChoices()[index];
    if (choice !== undefined) {
      this.updateRefreshRate(choice);
    }
  }

  private codecIndex(): number {
    if (this.defaults.preferredCodec === 'h265') {
      return 1;
    }
    if (this.defaults.preferredCodec === 'h264') {
      return 2;
    }
    if (this.defaults.preferredCodec === 'av1') {
      return 3;
    }
    if (this.defaults.preferredCodec === 'vp9') {
      return 4;
    }
    if (this.defaults.preferredCodec === 'vp8') {
      return 5;
    }
    return 0;
  }

  private updateCodecIndex(index: number): void {
    if (index === 1) {
      this.updateCodec('h265');
    } else if (index === 2) {
      this.updateCodec('h264');
    } else if (index === 3) {
      this.updateCodec('av1');
    } else if (index === 4) {
      this.updateCodec('vp9');
    } else if (index === 5) {
      this.updateCodec('vp8');
    } else {
      this.updateCodec('auto');
    }
  }

  private toggleRowWidth(): number {
    if (this.isWide()) {
      return Math.max(280, (this.viewportWidth - 72) / 2);
    }
    return Math.max(280, this.viewportWidth - 48);
  }

  private selectorWidth(maximum: number): number {
    const available = this.isWide()
      ? (this.viewportWidth - 84) / 2
      : this.viewportWidth - 48;
    return Math.max(260, Math.min(available, maximum));
  }

  private fullSelectorWidth(maximum: number): number {
    return Math.max(280, Math.min(this.viewportWidth - 48, maximum));
  }

  private customSliderWidth(): number {
    return Math.max(220, Math.min(this.viewportWidth - 72, 620));
  }

  private codecOptionWidth(): number {
    return (this.fullSelectorWidth(620) - 16) / 3;
  }

  private codecHintTopMargin(): number {
    return this.isWide() ? -10 : 4;
  }

  @Builder
  private AudioToggleRow() {
    LuminousSwitch({
      label: '播放远端音频',
      description: '',
      isOn: this.displayedAudioEnabled,
      rowWidth: this.toggleRowWidth(),
      motionEnabled: true,
      onChange: (enabled: boolean): void => this.updateAudio(enabled),
    })
    .width(this.toggleRowWidth())
    .height(52)
    .clip(false);
  }

  @Builder
  private ClipboardToggleRow() {
    LuminousSwitch({
      label: '同步剪贴板',
      description: '',
      isOn: this.displayedClipboardEnabled,
      rowWidth: this.toggleRowWidth(),
      motionEnabled: true,
      onChange: (enabled: boolean): void => this.updateClipboard(enabled),
    })
    .width(this.toggleRowWidth())
    .height(52)
    .clip(false);
  }

  @Builder
  private GesturesToggleRow() {
    LuminousSwitch({
      label: '多指画面手势',
      description: '双指移动与缩放画面，三指纵向滑动模拟滚轮',
      isOn: this.displayedGesturesEnabled,
      rowWidth: this.toggleRowWidth(),
      motionEnabled: true,
      onChange: (enabled: boolean): void => this.updateGestures(enabled),
    })
    .width(this.toggleRowWidth())
    .height(64)
    .clip(false);
  }

  @Builder
  private ToolbarToggleRow() {
    LuminousSwitch({
      label: '默认展开工具栏',
      description: '',
      isOn: this.displayedToolbarExpanded,
      rowWidth: this.toggleRowWidth(),
      motionEnabled: true,
      onChange: (enabled: boolean): void => this.updateToolbar(enabled),
    })
    .width(this.toggleRowWidth())
    .height(52)
    .clip(false);
  }

  @Builder
  private SessionSharingToggleRow() {
    LuminousSwitch({
      label: $r('app.string.settings_session_sharing'),
      description: $r('app.string.settings_session_sharing_description'),
      isOn: this.displayedSessionSharingEnabled,
      rowWidth: this.toggleRowWidth(),
      motionEnabled: true,
      onChange: (enabled: boolean): void => this.updateSessionSharing(enabled),
    })
    .width(this.toggleRowWidth())
    .height(64)
    .clip(false);
  }

  @Builder
  private PointerModeSelector() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_pointer_mode'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('touch', $r('app.string.settings_pointer_touchpad')),
          new LuminousSelectionItem('mouse', $r('app.string.settings_pointer_mouse')),
          new LuminousSelectionItem('relative', $r('app.string.settings_pointer_relative')),
        ],
        selectedIndex: this.pointerModeIndex(),
        controlWidth: this.selectorWidth(520),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number) => this.updatePointerMode(index),
      })
        .margin({ top: -10 })
    }
    .width('100%');
  }

  @Builder
  private RightClickGestureSelector() {
    Column({ space: 2 }) {
      Text('右键手势')
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('double_tap', '双击'),
          new LuminousSelectionItem('two_finger_tap', '双指点击'),
          new LuminousSelectionItem('long_press', '长按'),
        ],
        selectedIndex: this.rightClickGestureIndex(),
        controlWidth: this.selectorWidth(520),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number) => this.updateRightClickGesture(index),
      })
        .margin({ top: -10 })
    }
    .width('100%');
  }

  @Builder
  private InputModeHelpCard(
    modeIndex: number,
    title: string,
    description: string,
    gestures: string,
  ) {
    Column({ space: 5 }) {
      Row() {
        Text(title)
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pointerModeIndex() === modeIndex
            ? $r('app.color.white')
            : $r('app.color.neu_text_primary'));

        if (this.pointerModeIndex() === modeIndex) {
          Text('当前默认')
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.white'));
        }
      }
      .width('100%');

      Text(description)
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .fontColor(this.pointerModeIndex() === modeIndex
          ? $r('app.color.white')
          : $r('app.color.neu_text_secondary'));

      Text(`手势：${gestures}`)
        .width('100%')
        .fontSize(11)
        .lineHeight(16)
        .fontColor(this.pointerModeIndex() === modeIndex
          ? $r('app.color.white')
          : $r('app.color.neu_text_secondary'));
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.pointerModeIndex() === modeIndex
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: this.pointerModeIndex() === modeIndex
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'));
  }

  @Builder
  private InputModeHelp() {
    Column({ space: 10 }) {
      Text('模式与手势说明')
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      this.InputModeHelpCard(
        1,
        '鼠标模式',
        '把屏幕当作触控板，通过虚拟光标精确操作远端。',
        '单指移动光标 · 单击左键 · 双击时第二次按住约 300 ms 后移动可拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）',
      )
      this.InputModeHelpCard(
        0,
        '触控模式',
        '触点直接对应远端位置，适合窗口、列表和普通桌面操作。',
        '单击左键 · 单指拖动直接拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）',
      )
      this.InputModeHelpCard(
        2,
        '相对鼠标',
        '只发送位移增量，适合游戏、3D 软件和需要无限移动的场景。',
        '单指相对移动 · 单击左键 · 双击时第二次按住约 300 ms 后移动可拖拽 · 三指纵向滑动滚轮（Android 远端除外）',
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private QualitySelector() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_quality_default'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      LuminousSegmentedControl({
        items: this.rateChoices().map((rate: number) =>
          new LuminousSelectionItem(`${rate}`, `${rate} 帧`)),
        selectedIndex: this.refreshRateIndex(),
        controlWidth: this.selectorWidth(620),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number) => this.updateRefreshRateIndex(index),
      })
        .margin({ top: -10 })

      Text('刷新率取自本机屏幕支持档位，决定远端采集上限。')
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.neu_text_secondary'));
    }
    .width('100%');
  }

  @Builder
  private CodecOption(label: string, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.codecIndex() === index
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1);
    }
    .width(this.codecOptionWidth())
    .height(48)
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.codecIndex() === index
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: this.codecIndex() === index
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(label)
    .accessibilitySelected(this.codecIndex() === index)
    .onClick((): void => this.updateCodecIndex(index));
  }

  @Builder
  private CodecSelector() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_codec_preference'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      if (this.isWide()) {
        LuminousSegmentedControl({
          items: [
            new LuminousSelectionItem('auto', $r('app.string.settings_codec_auto')),
            new LuminousSelectionItem('h265', 'H.265'),
            new LuminousSelectionItem('h264', 'H.264'),
            new LuminousSelectionItem('av1', 'AV1'),
            new LuminousSelectionItem('vp9', 'VP9'),
            new LuminousSelectionItem('vp8', 'VP8'),
          ],
          selectedIndex: this.codecIndex(),
          controlWidth: this.fullSelectorWidth(720),
          controlHeight: 50,
          motionEnabled: true,
          onChange: (index: number) => this.updateCodecIndex(index),
        })
          .margin({ top: -10 })
      } else {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            this.CodecOption('自动', 0)
            this.CodecOption('H.265', 1)
            this.CodecOption('H.264', 2)
          }
          .width(this.fullSelectorWidth(620));

          Row({ space: 8 }) {
            this.CodecOption('AV1', 3)
            this.CodecOption('VP9', 4)
            this.CodecOption('VP8', 5)
          }
          .width(this.fullSelectorWidth(620));
        }
        .width(this.fullSelectorWidth(620))
        .margin({ top: 2 });
      }

      Text($r('app.string.settings_codec_hint'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.neu_text_secondary'))
        .margin({ top: this.codecHintTopMargin() });
    }
    .width('100%');
  }

  @Builder
  private ToggleGrid() {
    Column({ space: 2 }) {
          Text('会话能力')
            .width('100%')
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          if (this.isWide()) {
            Column({ space: 0 }) {
              Row({ space: $r('app.float.space_8') }) {
                Column() {
                  this.AudioToggleRow()
                }
                .layoutWeight(1);

                Column() {
                  this.ClipboardToggleRow()
                }
                .layoutWeight(1);
              }
              .width('100%');

              Row() {
                this.SessionSharingToggleRow()
              }
              .width('100%');

              Row({ space: $r('app.float.space_8') }) {
                Column() {
                  this.GesturesToggleRow()
                }
                .layoutWeight(1);

                Column() {
                  this.ToolbarToggleRow()
                }
                .layoutWeight(1);
              }
              .width('100%');
            }
            .width('100%');
          } else {
            Column({ space: 0 }) {
              this.AudioToggleRow()
              this.ClipboardToggleRow()
              this.GesturesToggleRow()
              this.ToolbarToggleRow()
              this.SessionSharingToggleRow()
            }
            .width('100%');
          }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Column({ space: 8 }) {
      if (this.showHeader) {
        Column({ space: $r('app.float.space_4') }) {
          Text($r('app.string.settings_defaults_title'))
            .width('100%')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
          Text($r('app.string.settings_defaults_subtitle'))
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }

      if (this.section === 'input') {
        Column({ space: 2 }) {
          this.PointerModeSelector()
          this.RightClickGestureSelector()
          this.InputModeHelp()
        }
        .width('100%');
      } else if (this.section === 'quality') {
        Column({ space: 2 }) {
          this.QualitySelector()
          this.CodecSelector()
        }
        .width('100%');
      } else if (this.section === 'other') {
        this.ToggleGrid()
      } else {
        if (this.isWide()) {
          Row({ space: $r('app.float.space_20') }) {
            Column({ space: 2 }) {
              this.PointerModeSelector()
              this.RightClickGestureSelector()
            }
            .layoutWeight(1);

            Column() {
              this.QualitySelector()
            }
            .layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          Column({ space: 2 }) {
            this.PointerModeSelector()
            this.RightClickGestureSelector()
            this.QualitySelector()
          }
          .width('100%');
        }

        this.CodecSelector()
        this.ToggleGrid()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
