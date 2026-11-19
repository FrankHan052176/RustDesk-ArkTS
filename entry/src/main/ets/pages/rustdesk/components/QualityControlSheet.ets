import { FALLBACK_REFRESH_RATE } from '../RustDeskRefreshRate';
import { QualityTelemetry } from '../RustDeskSessionTypes';
import { PeerProtocol, SessionDefaults, SessionImageQuality } from '../RustDeskDirectoryTypes';
import { DirectSessionSettingsCard } from './DirectSessionSettingsCard';

export interface QualityControlSheetProps {
  refreshRate: number;
  /** The picture trade-off this session asked the other device for. */
  imageQuality: SessionImageQuality;
  onImageQualityChange: (quality: SessionImageQuality) => void;
  /** Rates this device can show, ascending. Comes from the panel, not a constant. */
  refreshRateChoices: number[];
  telemetry: QualityTelemetry;
  onRefreshRateChange: (value: number) => void;
  onClose: () => void;
  protocol: PeerProtocol;
  directDefaults: SessionDefaults;
  onDirectDefaultsChange: (defaults: SessionDefaults) => void;
}

/**
 * One telemetry row.
 *
 * This is a component rather than a `@Builder` on purpose: a builder's
 * parameters are not dependencies, so a builder row keeps the value it was
 * first called with while the session runs. A child component re-renders when
 * the value it was passed changes, which is what makes the panel live.
 */
@ComponentV2
struct TelemetryRow {
  @Param label: ResourceStr = '';
  @Param value: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'));
      Text(this.value.length > 0 ? this.value : '--')
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
}

@ComponentV2
export struct QualityControlSheet {
  @Param refreshRate: number = 60;
  @Param imageQuality: SessionImageQuality = 'balanced';
  @Event onImageQualityChange: (quality: SessionImageQuality) => void = (_quality: SessionImageQuality) => {};
  @Param refreshRateChoices: number[] = [FALLBACK_REFRESH_RATE];
  /**
   * The rate the panel reports while the session runs, or 0 when unknown.
   *
   * The rows below count what the decoder produced; this is the ceiling the
   * picture is actually shown at, and the two differ whenever the request is not
   * honoured.
   */
  @Param panelRefreshRate: number = 0;
  @Param telemetry: QualityTelemetry = {
    submittedFps: '',
    requestedFps: '',
    receivedFps: '',
    queuedUnits: '',
    codec: '',
    networkRttMs: '',
    receiveBandwidthKBs: '',
    targetBitrateKbps: '',
  };
  @Event onRefreshRateChange: (value: number) => void = (_value: number) => {};
  @Event onClose: () => void = () => {};
  @Param protocol: PeerProtocol = 'rustdesk';
  @Param directDefaults: SessionDefaults = new SessionDefaults();
  @Param actionMessage: string = '';
  @Event onDirectDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults): void => {};

  /**
   * The offers are exactly the device's rates.
   *
   * There is no slider on purpose. The panel can only display the rates it
   * reports, so a slider mostly produces values that are not among them, and a
   * control whose output the device refuses is worse than no control.
   */
  private rateChoices(): number[] {
    return this.refreshRateChoices.length > 0 ? this.refreshRateChoices : [FALLBACK_REFRESH_RATE];
  }

  @Builder
  private ImageQualityButton(quality: SessionImageQuality, label: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.imageQuality === quality
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .backgroundColor(this.imageQuality === quality
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.imageQuality === quality
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .accessibilitySelected(this.imageQuality === quality)
    .onClick((): void => {
      this.onImageQualityChange(quality);
    });
  }

  @Builder
  private RateButton(rate: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(`${rate}`)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.refreshRate === rate
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .backgroundColor(this.refreshRate === rate
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.refreshRate === rate
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(`刷新率 ${rate} 帧`)
    .onClick((): void => {
      this.onRefreshRateChange(rate);
    });
  }

  /**
   * A measured rate with its unit.
   *
   * The telemetry carries bare values, so the unit lives here, once per row.
   */
  private rateText(raw: string): string {
    return raw.length > 0 ? `${raw} fps` : '';
  }

  /** The peer's measured network round trip. */
  private rttText(): string {
    const raw = this.telemetry.networkRttMs;
    return raw.length > 0 ? `${raw} ms` : '';
  }

  /** The peer's receive bandwidth, which its quality event writes in kB/s. */
  private bandwidthText(): string {
    const raw = this.telemetry.receiveBandwidthKBs;
    return raw.length > 0 ? `${raw} kB/s` : '';
  }

  /** The peer encoder's target bitrate, in kbps. */
  private bitrateText(): string {
    const raw = this.telemetry.targetBitrateKbps;
    return raw.length > 0 ? `${raw} kbps` : '';
  }

  /** The panel's own rate, which is the rate the operator actually sees. */
  private panelRateText(): string {
    return this.panelRefreshRate > 0 ? `${this.panelRefreshRate} Hz` : '';
  }

  build() {
    Scroll() {
      Column({ space: $r('app.float.space_24') }) {
        if (this.protocol === 'rustdesk') {
        Column({ space: $r('app.float.space_8') }) {
          Text('画面')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          Row({ space: $r('app.float.space_6') }) {
            this.ImageQualityButton('low', '流畅优先')
            this.ImageQualityButton('balanced', '均衡')
            this.ImageQualityButton('best', '清晰优先')
          }
          .width('100%')
          .constraintSize({ maxWidth: 620 });

          Text('网络较慢时选“流畅优先”，网络好时选“清晰优先”。')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        Column({ space: $r('app.float.space_8') }) {
          Text('刷新率')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

          Row({ space: $r('app.float.space_6') }) {
            ForEach(this.rateChoices(), (rate: number) => {
              this.RateButton(rate)
            }, (rate: number) => `rate-${rate}`)
          }
          .width('100%')
          .constraintSize({ maxWidth: 620 });

          Text('可选刷新率取自本机屏幕。它同时是对方画面帧率的上限；实际帧率取决于对方设备。')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(3);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
        } else {
          DirectSessionSettingsCard({
            protocol: this.protocol,
            defaults: this.directDefaults,
            liveSession: true,
            onDefaultsChange: (defaults: SessionDefaults): void => this.onDirectDefaultsChange(defaults),
          })
          if (this.actionMessage.length > 0) {
            Text(this.actionMessage)
              .width('100%')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'));
          }
        }

        Column({ space: 0 }) {
          Text('连接信息')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: $r('app.float.space_4') });

          // Only what the pipeline really reports: the engine's own counters give
          // the frame rates, the queue depth and the codec, and the peer's delay
          // probe gives the round trip. There is no source for a submission-path
          // latency, a decode duration or an admission rate, so no row claims one.
          TelemetryRow({ label: $r('app.string.quality_submitted_fps'), value: this.rateText(this.telemetry.submittedFps) })
          TelemetryRow({ label: $r('app.string.quality_requested_fps'), value: this.rateText(this.telemetry.requestedFps) })
          TelemetryRow({ label: $r('app.string.quality_panel_refresh_rate'), value: this.panelRateText() })
          TelemetryRow({ label: $r('app.string.quality_received_fps'), value: this.rateText(this.telemetry.receivedFps) })
          TelemetryRow({ label: $r('app.string.quality_queued_units'), value: this.telemetry.queuedUnits })
          TelemetryRow({ label: $r('app.string.quality_codec'), value: this.telemetry.codec })
          TelemetryRow({ label: $r('app.string.quality_network_rtt'), value: this.rttText() })
          // Bandwidth and target bitrate come only from a peer's quality event,
          // which this engine does not produce today. A row with no source is
          // not shown as a permanent "--"; it appears when a value does.
          if (this.bandwidthText().length > 0) {
            TelemetryRow({ label: $r('app.string.quality_receive_bandwidth'), value: this.bandwidthText() })
          }
          if (this.bitrateText().length > 0) {
            TelemetryRow({ label: $r('app.string.quality_target_bitrate'), value: this.bitrateText() })
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
