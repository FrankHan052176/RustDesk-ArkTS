import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { ServerConfig, ServerMode, ServerProfileState } from '../RustDeskDirectoryTypes';

export interface ServerSettingsCardProps {
  showHeader: boolean;
  config: ServerConfig;
  profile: ServerProfileState;
  validating: boolean;
  saving: boolean;
  onConfigChange: (config: ServerConfig) => void;
  onValidate: (config: ServerConfig) => void;
  onSave: (config: ServerConfig) => void;
}

@ComponentV2
export struct ServerSettingsCard {
  @Param showHeader: boolean = true;
  @Param config: ServerConfig = new ServerConfig();
  @Param profile: ServerProfileState = new ServerProfileState();
  @Param validating: boolean = false;
  @Param saving: boolean = false;
  @Local viewportWidth: number = 390;
  @Event onConfigChange: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onValidate: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onSave: (config: ServerConfig) => void = (_config: ServerConfig) => {};

  private isBusy(): boolean {
    return this.validating || this.saving;
  }

  private selectorWidth(): number {
    return Math.max(96, Math.min(this.viewportWidth - 40, 560));
  }

  private inputWidth(): number {
    return Math.max(96, this.viewportWidth - 16);
  }

  private copyDraft(): ServerConfig {
    const next = new ServerConfig();
    next.mode = this.config.mode;
    next.idServer = this.config.idServer;
    next.relayServer = this.config.relayServer;
    next.key = this.config.key;
    return next;
  }

  private updateMode(mode: ServerMode): void {
    const next = this.copyDraft();
    next.mode = mode;
    this.onConfigChange(next);
  }

  private updateIdServer(value: string): void {
    const next = this.copyDraft();
    next.idServer = value;
    this.onConfigChange(next);
  }

  private updateRelayServer(value: string): void {
    const next = this.copyDraft();
    next.relayServer = value;
    this.onConfigChange(next);
  }

  private updateKey(value: string): void {
    const next = this.copyDraft();
    next.key = value;
    this.onConfigChange(next);
  }

  private approvalText(): ResourceStr {
    if (this.profile.approval === 'approved') {
      return $r('app.string.resk_server_approved');
    }
    if (this.profile.approval === 'legacy-unapproved') {
      return $r('app.string.resk_server_legacy');
    }
    return $r('app.string.resk_server_unapproved');
  }

  private resultText(): ResourceStr {
    if (this.config.resultState === 'format-valid') {
      return $r('app.string.resk_server_format_valid');
    }
    if (this.config.resultState === 'saved') {
      return $r('app.string.resk_server_saved');
    }
    return this.config.message;
  }

  @Builder
  private ServerField(placeholder: ResourceStr, label: ResourceStr, value: string,
    onChange: (value: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .width(this.inputWidth())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));
      Row() {
        LuminousTextField({
          value: value,
          placeholder: placeholder,
          fieldWidth: this.inputWidth(),
          fieldHeight: 48,
          isEnabled: !this.isBusy(),
          motionEnabled: true,
          onChange: onChange,
        })
          .margin({ top: -10 })
          .translate({ x: -(LuminousNeoTokens.shadowPaddingFor(48) - 8) })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ActionButton(label: ResourceStr, primary: boolean, onClick: () => void) {
    LuminousButton({
      label: label,
      controlWidth: Math.max(120, this.inputWidth() - 32),
      controlSizeMode: LuminousControlSize.Regular,
      tone: primary ? LuminousTone.Accent : LuminousTone.Neutral,
      isEnabled: !this.isBusy(),
      motionEnabled: true,
      onAction: onClick,
    })
  }

  build() {
    Column({ space: $r('app.float.space_8') }) {
      if (this.showHeader) {
        Column({ space: $r('app.float.space_4') }) {
          Text($r('app.string.settings_server_title'))
            .width('100%')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
          Text($r('app.string.settings_server_subtitle'))
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }

      Row() {
        LuminousSegmentedControl({
          items: [
            new LuminousSelectionItem('official', $r('app.string.settings_server_official')),
            new LuminousSelectionItem('custom', $r('app.string.settings_server_custom')),
          ],
          selectedIndex: this.config.mode === 'custom' ? 1 : 0,
          controlWidth: Math.max(96, this.selectorWidth() - LuminousNeoTokens.shadowPaddingFor(50) * 2),
          controlHeight: 50,
          isEnabled: !this.isBusy(),
          motionEnabled: true,
          onChange: (index: number): void => this.updateMode(index === 1 ? 'custom' : 'official'),
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);

      Text(this.config.mode === 'official'
        ? $r('app.string.settings_server_public_hint')
        : $r('app.string.settings_server_custom_hint'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(20)
        .fontColor($r('app.color.neu_text_secondary'));

      if (this.config.mode === 'custom') {
        this.ServerField($r('app.string.settings_id_server_placeholder'), $r('app.string.settings_id_server'),
          this.config.idServer, (value: string): void => this.updateIdServer(value));
        this.ServerField($r('app.string.settings_relay_server_placeholder'), $r('app.string.settings_relay_server'),
          this.config.relayServer, (value: string): void => this.updateRelayServer(value));
        this.ServerField($r('app.string.settings_server_key_placeholder'), $r('app.string.settings_server_key'),
          this.config.key, (value: string): void => this.updateKey(value));
      }

      Text(this.approvalText())
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.neu_text_secondary'));
      Text($r('app.string.settings_server_validation_note'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.text_secondary'));

      Column() {
        this.ActionButton($r('app.string.resk_server_validate'), false,
          (): void => this.onValidate(this.copyDraft()));
        this.ActionButton(this.saving ? $r('app.string.settings_server_saving')
          : $r('app.string.settings_server_save'), true,
          (): void => this.onSave(this.copyDraft()));
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);

      if (this.config.resultState === 'format-valid' || this.config.resultState === 'saved' ||
        this.config.message.length > 0) {
        Text(this.resultText())
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .fontColor(this.config.resultState === 'error' ? $r('app.color.error') : $r('app.color.text_primary'));
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
