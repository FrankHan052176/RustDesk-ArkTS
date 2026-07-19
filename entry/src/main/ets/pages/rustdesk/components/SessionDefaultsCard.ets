import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { SessionDefaults } from '../RustDeskDirectoryTypes';
import { FloatingSegmentedControl } from './FloatingSegmentedControl';

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

  @Builder
  private ToggleRow(label: ResourceStr, enabled: boolean, onChange: (enabled: boolean) => void) {
    Row({ space: $r('app.float.space_12') }) {
      Text(label)
        .layoutWeight(1)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor($r('app.color.brand_primary'))
        .switchPointColor($r('app.color.white'))
        .onChange(onChange);
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_8') });
  }

  @Builder
  private PointerModeSelector() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_pointer_mode'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

      FloatingSegmentedControl({
        labels: [
          $r('app.string.settings_pointer_mouse'),
          $r('app.string.settings_pointer_touchpad'),
        ],
        badges: [],
        selectedIndex: this.defaults.relativeMouseMode ? 1 : 0,
        progress: -1,
        controlId: 'settings-pointer-mode',
        compact: false,
        onPreviewIndex: (_index: number) => {},
        onProgressChange: (_progress: number) => {},
        onDragStateChange: (_dragging: boolean) => {},
        onChange: (index: number) => this.updatePointerMode(index === 1),
      })
      .width('100%')
      .constraintSize({ maxWidth: 520 });
    }
    .width('100%');
  }

  @Builder
  private QualitySelector() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_quality_default'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

      FloatingSegmentedControl({
        labels: [
          $r('app.string.settings_quality_speed'),
          $r('app.string.settings_quality_balanced'),
          $r('app.string.settings_quality_best'),
        ],
        badges: [],
        selectedIndex: this.qualityIndex(),
        progress: -1,
        controlId: 'settings-quality',
        compact: true,
        onPreviewIndex: (_index: number) => {},
        onProgressChange: (_progress: number) => {},
        onDragStateChange: (_dragging: boolean) => {},
        onChange: (index: number) => this.updateQualityIndex(index),
      })
      .width('100%')
      .constraintSize({ maxWidth: 620 });
    }
    .width('100%');
  }

  @Builder
  private CodecSelector() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_codec_preference'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

      FloatingSegmentedControl({
        labels: [
          $r('app.string.settings_codec_auto'),
          'H.264',
          'H.265',
          'VP9',
          'AV1',
        ],
        badges: [],
        selectedIndex: this.codecIndex(),
        progress: -1,
        controlId: 'settings-codec',
        compact: true,
        onPreviewIndex: (_index: number) => {},
        onProgressChange: (_progress: number) => {},
        onDragStateChange: (_dragging: boolean) => {},
        onChange: (index: number) => this.updateCodecIndex(index),
      })
      .width('100%')
      .constraintSize({ maxWidth: 720 });

      Text($r('app.string.settings_codec_hint'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%');
  }

  @Builder
  private ToggleGrid() {
    Column() {
      if (this.isWide()) {
        Column({ space: $r('app.float.space_4') }) {
          Row({ space: $r('app.float.space_4') }) {
            Column() {
              this.ToggleRow(
                $r('app.string.settings_remote_audio'),
                this.defaults.audioEnabled,
                (enabled: boolean) => this.updateAudio(enabled),
              )
            }
            .layoutWeight(1);

            Column() {
              this.ToggleRow(
                $r('app.string.settings_clipboard_sync'),
                this.defaults.clipboardEnabled,
                (enabled: boolean) => this.updateClipboard(enabled),
              )
            }
            .layoutWeight(1);
          }
          .width('100%');

          Row({ space: $r('app.float.space_4') }) {
            Column() {
              this.ToggleRow(
                $r('app.string.settings_transform_gestures'),
                this.defaults.gesturesEnabled,
                (enabled: boolean) => this.updateGestures(enabled),
              )
            }
            .layoutWeight(1);

            Column() {
              this.ToggleRow(
                $r('app.string.settings_toolbar_expanded'),
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
        Column({ space: $r('app.float.space_4') }) {
          this.ToggleRow(
            $r('app.string.settings_remote_audio'),
            this.defaults.audioEnabled,
            (enabled: boolean) => this.updateAudio(enabled),
          )
          this.ToggleRow(
            $r('app.string.settings_clipboard_sync'),
            this.defaults.clipboardEnabled,
            (enabled: boolean) => this.updateClipboard(enabled),
          )
          this.ToggleRow(
            $r('app.string.settings_transform_gestures'),
            this.defaults.gesturesEnabled,
            (enabled: boolean) => this.updateGestures(enabled),
          )
          this.ToggleRow(
            $r('app.string.settings_toolbar_expanded'),
            this.defaults.toolbarExpanded,
            (enabled: boolean) => this.updateToolbar(enabled),
          )
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.48,
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius($r('app.float.radius_18'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  build() {
    Column({ space: $r('app.float.space_24') }) {
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
        Column({ space: $r('app.float.space_20') }) {
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
