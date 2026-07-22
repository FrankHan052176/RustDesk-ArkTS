import { ImageQualityPreset } from '../SessionDisplayController';
import { QualityTelemetry } from '../RustDeskSessionTypes';

export type QualityPreset = ImageQualityPreset;

export interface QualityControlSheetProps {
  selectedPreset: ImageQualityPreset;
  customQuality: number;
  customFps: number;
  telemetry: QualityTelemetry;
  onSelectPreset: (preset: ImageQualityPreset) => void;
  onCustomQualityChange: (value: number) => void;
  onCustomFpsChange: (value: number) => void;
  onClose: () => void;
}

@ComponentV2
export struct QualityControlSheet {
  @Param selectedPreset: ImageQualityPreset = 'balanced';
  @Param customQuality: number = 10;
  @Param customFps: number = 5;
  @Param telemetry: QualityTelemetry = {
    fps: '--',
    delay: '--',
    codec: '--',
    speed: '--',
    targetBitrate: '--',
    chroma: '--',
  };
  @Local viewportWidth: number = 390;
  @Event onSelectPreset: (preset: ImageQualityPreset) => void = (_preset: ImageQualityPreset) => {};
  @Event onCustomQualityChange: (value: number) => void = (_value: number) => {};
  @Event onCustomFpsChange: (value: number) => void = (_value: number) => {};
  @Event onClose: () => void = () => {};

  private clampQuality(value: number): number {
    if (!Number.isFinite(value)) {
      return 10;
    }
    return Math.min(2000, Math.max(10, Math.round(value)));
  }

  private clampFps(value: number): number {
    if (!Number.isFinite(value)) {
      return 5;
    }
    return Math.min(120, Math.max(5, Math.round(value)));
  }

  private presetIndex(): number {
    if (this.selectedPreset === 'best') {
      return 0;
    }
    if (this.selectedPreset === 'low') {
      return 2;
    }
    if (this.selectedPreset === 'custom') {
      return 3;
    }
    return 1;
  }

  private selectPresetIndex(index: number): void {
    if (index === 0) {
      this.onSelectPreset('best');
    } else if (index === 2) {
      this.onSelectPreset('low');
    } else if (index === 3) {
      this.onSelectPreset('custom');
    } else {
      this.onSelectPreset('balanced');
    }
  }

  private sliderWidth(): number {
    return Math.max(180, Math.min(520, this.viewportWidth - 48));
  }

  @Builder
  private PresetButton(label: string, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.presetIndex() === index
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(40)
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .backgroundColor(this.presetIndex() === index
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.presetIndex() === index
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .onClick((): void => {
      this.selectPresetIndex(index);
    });
  }

  @Builder
  private SliderControl(
    key: string,
    value: number,
    min: number,
    max: number,
    step: number,
    onChange: (value: number) => void,
  ) {
    Stack({ alignContent: Alignment.Center }) {
      Slider({
        value: value,
        min: min,
        max: max,
        step: step,
        style: SliderStyle.OutSet,
      })
        .width(this.sliderWidth())
        .selectedColor($r('app.color.brand_primary'))
        .trackColor($r('app.color.mica_control'))
        .blockColor($r('app.color.white'))
        .showTips(false)
        .onChange((nextValue: number, _mode: SliderChangeMode): void => {
          onChange(nextValue);
        });
    }
    .width('100%')
    .height(48)
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .accessibilityText(key);
  }

  @Builder
  private TelemetryRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'));
      Text(value || '--')
        .layoutWeight(1)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });
  }

  build() {
    Scroll() {
      Column({ space: $r('app.float.space_24') }) {
        Column({ space: $r('app.float.space_8') }) {
          Text('预设')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          Row({ space: $r('app.float.space_6') }) {
            this.PresetButton('最佳画质', 0)
            this.PresetButton('均衡', 1)
            this.PresetButton('低带宽', 2)
            this.PresetButton('自定义', 3)
          }
          .width('100%')
          .constraintSize({ maxWidth: 620 });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: $r('app.float.space_8') }) {
          Row() {
            Text('自定义画质')
              .layoutWeight(1)
              .fontSize($r('app.float.font_body_large'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'));
            Text(`${this.clampQuality(this.customQuality)}`)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.brand_primary'));
          }
          .width('100%');

          this.SliderControl('quality-slider', this.clampQuality(this.customQuality), 10, 2000, 10,
            (value: number) => this.onCustomQualityChange(this.clampQuality(value)))

          Row() {
            Text('自定义 FPS')
              .layoutWeight(1)
              .fontSize($r('app.float.font_body_large'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'));
            Text(`${this.clampFps(this.customFps)}`)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.brand_primary'));
          }
          .width('100%')
          .margin({ top: $r('app.float.space_8') });

          this.SliderControl('fps-slider', this.clampFps(this.customFps), 5, 120, 1,
            (value: number) => this.onCustomFpsChange(this.clampFps(value)))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: 0 }) {
          Text('连接遥测')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: $r('app.float.space_4') });

          this.TelemetryRow('速度', this.telemetry.speed)
          this.TelemetryRow('目标码率', this.telemetry.targetBitrate)
          this.TelemetryRow('延迟', this.telemetry.delay)
          this.TelemetryRow('FPS', this.telemetry.fps)
          this.TelemetryRow('编解码器', this.telemetry.codec)
          this.TelemetryRow('色度', this.telemetry.chroma)
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
    .clip(true)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      let width: number = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
