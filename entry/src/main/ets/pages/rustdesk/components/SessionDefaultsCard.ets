import {
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSwitch,
} from 'luminous_neo';
import { SessionDefaults } from '../RustDeskDirectoryTypes';

export interface SessionDefaultsCardProps {
  showHeader: boolean;
  defaults: SessionDefaults;
  onDefaultsChange: (defaults: SessionDefaults) => void;
}

@ComponentV2
export struct SessionDefaultsCard {
  @Param showHeader: boolean = true;
  @Param defaults: SessionDefaults = new SessionDefaults();
  @Local viewportWidth: number = 390;
  @Event onDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults) => {};

  private isWide(): boolean {
    return this.viewportWidth >= 720;
  }

  private copyDefaults(): SessionDefaults {
    const next = new SessionDefaults();
    next.relativeMouseMode = this.defaults.relativeMouseMode;
    next.audioEnabled = this.defaults.audioEnabled;
    next.clipboardEnabled = this.defaults.clipboardEnabled;
    next.qualityPreset = this.defaults.qualityPreset;
    next.preferredCodec = this.defaults.preferredCodec;
    next.gesturesEnabled = this.defaults.gesturesEnabled;
    next.toolbarExpanded = this.defaults.toolbarExpanded;
    return next;
  }

  private emit(next: SessionDefaults): void {
    this.onDefaultsChange(next);
  }

  private updatePointerMode(relativeMouseMode: boolean): void {
    const next = this.copyDefaults();
    next.relativeMouseMode = relativeMouseMode;
    this.emit(next);
  }

  private updateAudio(enabled: boolean): void {
    const next = this.copyDefaults();
    next.audioEnabled = enabled;
    this.emit(next);
  }

  private updateClipboard(enabled: boolean): void {
    const next = this.copyDefaults();
    next.clipboardEnabled = enabled;
    this.emit(next);
  }

  private updateGestures(enabled: boolean): void {
    const next = this.copyDefaults();
    next.gesturesEnabled = enabled;
    this.emit(next);
  }

  private updateToolbar(enabled: boolean): void {
    const next = this.copyDefaults();
    next.toolbarExpanded = enabled;
    this.emit(next);
  }

  private updateQuality(preset: string): void {
    const next = this.copyDefaults();
    next.qualityPreset = preset;
    this.emit(next);
  }

  private updateCodec(codec: string): void {
    const next = this.copyDefaults();
    next.preferredCodec = codec;
    this.emit(next);
  }

  private qualityIndex(): number {
    if (this.defaults.qualityPreset === 'low') {
      return 0;
    }
    if (this.defaults.qualityPreset === 'best') {
      return 2;
    }
    return 1;
  }

  private updateQualityIndex(index: number): void {
    if (index === 0) {
      this.updateQuality('low');
    } else if (index === 2) {
      this.updateQuality('best');
    } else {
      this.updateQuality('balanced');
    }
  }

  private codecIndex(): number {
    if (this.defaults.preferredCodec === 'h264') {
      return 1;
    }
    if (this.defaults.preferredCodec === 'h265') {
      return 2;
    }
    if (this.defaults.preferredCodec === 'vp9') {
      return 3;
    }
    if (this.defaults.preferredCodec === 'av1') {
      return 4;
    }
    return 0;
  }

  private updateCodecIndex(index: number): void {
    if (index === 1) {
      this.updateCodec('h264');
    } else if (index === 2) {
      this.updateCodec('h265');
    } else if (index === 3) {
      this.updateCodec('vp9');
    } else if (index === 4) {
      this.updateCodec('av1');
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

  @Builder
  private ToggleRow(label: ResourceStr, enabled: boolean, onChange: (enabled: boolean) => void) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSwitch({
        label: label,
        description: '',
        isOn: enabled,
        rowWidth: this.toggleRowWidth(),
        onChange: onChange,
      })
    }
    .width(this.toggleRowWidth())
    .height(52)
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
          new LuminousSelectionItem('mouse', $r('app.string.settings_pointer_mouse')),
          new LuminousSelectionItem('touchpad', $r('app.string.settings_pointer_touchpad')),
        ],
        selectedIndex: this.defaults.relativeMouseMode ? 1 : 0,
        controlWidth: this.selectorWidth(520),
        controlHeight: 50,
        onChange: (index: number) => this.updatePointerMode(index === 1),
      })
        .margin({ top: -10 })
    }
    .width('100%');
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
        items: [
          new LuminousSelectionItem('speed', $r('app.string.settings_quality_speed')),
          new LuminousSelectionItem('balanced', $r('app.string.settings_quality_balanced')),
          new LuminousSelectionItem('best', $r('app.string.settings_quality_best')),
        ],
        selectedIndex: this.qualityIndex(),
        controlWidth: this.selectorWidth(620),
        controlHeight: 50,
        onChange: (index: number) => this.updateQualityIndex(index),
      })
        .margin({ top: -10 })
    }
    .width('100%');
  }

  @Builder
  private CodecSelector() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_codec_preference'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('auto', $r('app.string.settings_codec_auto')),
          new LuminousSelectionItem('h264', 'H.264'),
          new LuminousSelectionItem('h265', 'H.265'),
          new LuminousSelectionItem('vp9', 'VP9'),
          new LuminousSelectionItem('av1', 'AV1'),
        ],
        selectedIndex: this.codecIndex(),
        controlWidth: this.fullSelectorWidth(720),
        controlHeight: 50,
        onChange: (index: number) => this.updateCodecIndex(index),
      })
        .margin({ top: -10 })

      Text($r('app.string.settings_codec_hint'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.neu_text_secondary'))
        .margin({ top: -10 });
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
                  this.ToggleRow(
                    '播放远端音频',
                    this.defaults.audioEnabled,
                    (enabled: boolean) => this.updateAudio(enabled),
                  )
                }
                .layoutWeight(1);

                Column() {
                  this.ToggleRow(
                    '同步剪贴板',
                    this.defaults.clipboardEnabled,
                    (enabled: boolean) => this.updateClipboard(enabled),
                  )
                }
                .layoutWeight(1);
              }
              .width('100%');

              Row({ space: $r('app.float.space_8') }) {
                Column() {
                  this.ToggleRow(
                    '变换手势',
                    this.defaults.gesturesEnabled,
                    (enabled: boolean) => this.updateGestures(enabled),
                  )
                }
                .layoutWeight(1);

                Column() {
                  this.ToggleRow(
                    '默认展开工具栏',
                    this.defaults.toolbarExpanded,
                    (enabled: boolean) => this.updateToolbar(enabled),
                  )
                }
                .layoutWeight(1);
              }
              .width('100%');
            }
            .width('100%');
          } else {
            Column({ space: 0 }) {
              this.ToggleRow(
                '播放远端音频',
                this.defaults.audioEnabled,
                (enabled: boolean) => this.updateAudio(enabled),
              )
              this.ToggleRow(
                '同步剪贴板',
                this.defaults.clipboardEnabled,
                (enabled: boolean) => this.updateClipboard(enabled),
              )
              this.ToggleRow(
                '变换手势',
                this.defaults.gesturesEnabled,
                (enabled: boolean) => this.updateGestures(enabled),
              )
              this.ToggleRow(
                '默认展开工具栏',
                this.defaults.toolbarExpanded,
                (enabled: boolean) => this.updateToolbar(enabled),
              )
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

      if (this.isWide()) {
        Row({ space: $r('app.float.space_20') }) {
          Column() {
            this.PointerModeSelector()
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
          this.QualitySelector()
        }
        .width('100%');
      }

      this.CodecSelector()
      this.ToggleGrid()
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
