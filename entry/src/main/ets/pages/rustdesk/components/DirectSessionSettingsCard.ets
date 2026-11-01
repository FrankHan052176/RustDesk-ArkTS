import { LuminousSwitch } from 'luminous_neo';
import { PeerProtocol, SessionDefaults } from '../RustDeskDirectoryTypes';
import { copySessionDefaults, RDP_RESOLUTION_CHOICES, RDP_SETTING_SCALE_CHOICES } from '../DirectSessionSettings';

@ComponentV2
struct DirectSettingsChoice {
  @Param label: ResourceStr = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = (): void => {};

  build(): void {
    Button(this.label, { type: ButtonType.Normal, stateEffect: true })
      .height(44)
      .padding({ left: 12, right: 12 })
      .margin({ right: 8, bottom: 8 })
      .fontSize($r('app.float.font_label'))
      .fontColor(this.selected ? $r('app.color.white') : $r('app.color.neu_text_primary'))
      .backgroundColor(this.selected ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
      .borderRadius($r('app.float.radius_10'))
      .accessibilitySelected(this.selected)
      .onClick(this.onSelect);
  }
}

@ComponentV2
export struct DirectSessionSettingsCard {
  @Param defaults: SessionDefaults = new SessionDefaults();
  @Param protocol: PeerProtocol = 'rustdesk';
  @Param liveSession: boolean = false;
  @Local viewportWidth: number = 390;
  @Event onDefaultsChange: (defaults: SessionDefaults) => void = (_defaults: SessionDefaults): void => {};

  private resolutionLabel(value: string): ResourceStr {
    return value === 'follow' ? $r('app.string.direct_rdp_follow_recommended') : value.replace('x', '×');
  }

  private scaleLabel(value: number): ResourceStr {
    return value === 0 ? $r('app.string.direct_follow_device') : `${value}%`;
  }

  private selectResolution(value: string): void {
    const next = copySessionDefaults(this.defaults);
    next.rdpResolution = value;
    this.onDefaultsChange(next);
  }

  private selectScale(value: number): void {
    const next = copySessionDefaults(this.defaults);
    next.rdpScaleFactor = value;
    this.onDefaultsChange(next);
  }

  private selectQuality(index: number): void {
    const next = copySessionDefaults(this.defaults);
    next.vncQuality = index === 0 ? 'lossless' : (index === 1 ? 'balanced' : 'fast');
    this.onDefaultsChange(next);
  }

  private qualityLabel(index: number): ResourceStr {
    return index === 0 ? $r('app.string.direct_vnc_lossless') :
      (index === 1 ? $r('app.string.direct_vnc_balanced') : $r('app.string.direct_vnc_fast'));
  }

  private qualitySelected(index: number): boolean {
    return this.defaults.vncQuality === (index === 0 ? 'lossless' : (index === 1 ? 'balanced' : 'fast'));
  }


  @Builder
  private Heading(label: ResourceStr) {
    Text(label)
      .fontSize($r('app.float.font_body_large'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.neu_text_primary'));
  }

  build(): void {
    Column({ space: 16 }) {
      if (this.protocol !== 'vnc') {
        this.Heading($r('app.string.direct_rdp_resolution'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(RDP_RESOLUTION_CHOICES, (value: string): void => {
            DirectSettingsChoice({ label: this.resolutionLabel(value), selected: this.defaults.rdpResolution === value,
              onSelect: (): void => this.selectResolution(value) })
          }, (value: string): string => value)
        }
        .width('100%');
        this.Heading($r('app.string.direct_rdp_scale'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(RDP_SETTING_SCALE_CHOICES, (value: number): void => {
            DirectSettingsChoice({ label: this.scaleLabel(value), selected: this.defaults.rdpScaleFactor === value,
              onSelect: (): void => this.selectScale(value) })
          }, (value: number): string => String(value))
        }
        .width('100%');
        if (!this.liveSession) {
          LuminousSwitch({
            label: $r('app.string.direct_rdp_audio'),
            description: '',
            isOn: this.defaults.rdpAudioEnabled,
            rowWidth: Math.max(240, this.viewportWidth - 24),
            motionEnabled: true,
            onChange: (enabled: boolean): void => {
              const next = copySessionDefaults(this.defaults);
              next.rdpAudioEnabled = enabled;
              this.onDefaultsChange(next);
            },
          })
        }
      }
      if (this.protocol !== 'rdp') {
        this.Heading($r('app.string.direct_vnc_quality'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach([0, 1, 2], (index: number): void => {
            DirectSettingsChoice({ label: this.qualityLabel(index), selected: this.qualitySelected(index),
              onSelect: (): void => this.selectQuality(index) })
          }, (index: number): string => String(index))
        }
        .width('100%');
      }
      Text(this.liveSession && this.protocol === 'rdp'
        ? $r('app.string.direct_rdp_live_hint') : $r('app.string.direct_next_connection_hint'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.viewportWidth = Number(newArea.width);
    });
  }
}
