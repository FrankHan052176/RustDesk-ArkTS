import {
  LuminousButton,
  LuminousControlSize,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
  LuminousSurfaceState,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { ServerConfig, ServerMode } from '../RustDeskDirectoryTypes';

export interface ServerSettingsCardProps {
  showHeader: boolean;
  config: ServerConfig;
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
  @Param validating: boolean = false;
  @Param saving: boolean = false;
  @Local viewportWidth: number = 390;
  @Local validationMessage: ResourceStr = '';
  @Local validationField: string = '';
  @Event onConfigChange: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onValidate: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onSave: (config: ServerConfig) => void = (_config: ServerConfig) => {};

  private isWide(): boolean {
    return this.viewportWidth >= 720;
  }

  private isBusy(): boolean {
    return this.validating || this.saving;
  }

  private selectorWidth(): number {
    return Math.max(280, Math.min(this.viewportWidth - 40, 560));
  }

  private inputWidth(): number {
    if (this.isWide()) {
      return Math.max(280, (this.viewportWidth - 72) / 2);
    }
    return Math.max(280, Math.min(this.viewportWidth - 40, 560));
  }

  private actionButtonWidth(): number {
    if (this.viewportWidth >= 520) {
      return Math.max(150, (this.viewportWidth - 96) / 2);
    }
    return Math.max(104, (this.viewportWidth - 84) / 2);
  }

  private statusSummaryHeight(): number {
    return 150;
  }

  private statusRowHeight(): number {
    return this.statusSummaryHeight() / 3;
  }

  private copyConfig(): ServerConfig {
    const next = new ServerConfig();
    next.mode = this.config.mode;
    next.idServer = this.config.idServer;
    next.relayServer = this.config.relayServer;
    next.apiServer = this.config.apiServer;
    next.key = this.config.key;
    next.effectiveApiServer = this.config.effectiveApiServer;
    next.usingPublicServer = this.config.usingPublicServer;
    next.remoteReachable = this.config.remoteReachable;
    next.accountAvailable = this.config.accountAvailable;
    next.message = this.config.message;
    return next;
  }

  private emitDraft(next: ServerConfig): void {
    next.remoteReachable = false;
    next.accountAvailable = false;
    next.message = '';
    this.validationMessage = '';
    this.validationField = '';
    this.onConfigChange(next);
  }

  private updateMode(mode: ServerMode): void {
    const next = this.copyConfig();
    next.mode = mode;
    next.usingPublicServer = mode === 'official';
    this.emitDraft(next);
  }

  private updateModeIndex(index: number): void {
    this.updateMode(index === 1 ? 'custom' : 'official');
  }

  private updateIdServer(value: string): void {
    const next = this.copyConfig();
    next.idServer = value;
    this.emitDraft(next);
  }

  private updateRelayServer(value: string): void {
    const next = this.copyConfig();
    next.relayServer = value;
    this.emitDraft(next);
  }

  private updateApiServer(value: string): void {
    const next = this.copyConfig();
    next.apiServer = value;
    this.emitDraft(next);
  }

  private updateKey(value: string): void {
    const next = this.copyConfig();
    next.key = value;
    this.emitDraft(next);
  }

  private normalizedConfig(): ServerConfig {
    const next = this.copyConfig();
    next.idServer = next.idServer.trim();
    next.relayServer = next.relayServer.trim();
    next.apiServer = next.apiServer.trim();
    next.key = next.key.trim();
    return next;
  }

  private validateFormat(config: ServerConfig): ResourceStr {
    if (config.mode === 'official') {
      return '';
    }
    if (config.idServer.length === 0) {
      return $r('app.string.settings_server_error_id_required');
    }
    if (config.idServer.includes(' ')) {
      return $r('app.string.settings_server_error_id_space');
    }
    if (config.relayServer.includes(' ')) {
      return $r('app.string.settings_server_error_relay_space');
    }
    if (config.apiServer.length > 0
      && !config.apiServer.startsWith('http://')
      && !config.apiServer.startsWith('https://')) {
      return $r('app.string.settings_server_error_api_scheme');
    }
    return '';
  }

  private findValidationField(config: ServerConfig): string {
    if (config.mode === 'official') {
      return '';
    }
    if (config.idServer.length === 0 || config.idServer.includes(' ')) {
      return 'id-server';
    }
    if (config.relayServer.includes(' ')) {
      return 'relay-server';
    }
    if (config.apiServer.length > 0
      && !config.apiServer.startsWith('http://')
      && !config.apiServer.startsWith('https://')) {
      return 'api-server';
    }
    return '';
  }

  private requestValidation(): void {
    const next = this.normalizedConfig();
    const message = this.validateFormat(next);
    if (message !== '') {
      this.validationMessage = message;
      this.validationField = this.findValidationField(next);
      return;
    }
    this.validationMessage = '';
    this.validationField = '';
    this.onConfigChange(next);
    this.onValidate(next);
  }

  private requestSave(): void {
    const next = this.normalizedConfig();
    const message = this.validateFormat(next);
    if (message !== '') {
      this.validationMessage = message;
      this.validationField = this.findValidationField(next);
      return;
    }
    this.validationMessage = '';
    this.validationField = '';
    this.onConfigChange(next);
    this.onSave(next);
  }

  private remoteStatusText(): ResourceStr {
    if (this.config.mode === 'official') {
      return $r('app.string.settings_server_remote_auto');
    }
    if (this.config.remoteReachable) {
      return $r('app.string.settings_server_remote_ready');
    }
    return $r('app.string.settings_server_remote_pending');
  }

  private accountStatusText(): ResourceStr {
    if (this.config.accountAvailable) {
      return $r('app.string.settings_server_account_ready');
    }
    if (this.config.mode === 'custom' && this.config.apiServer.trim().length === 0) {
      return $r('app.string.settings_server_account_unconfigured');
    }
    return $r('app.string.settings_server_account_pending');
  }

  private effectiveApiText(): ResourceStr {
    const apiServer = this.config.effectiveApiServer.trim();
    if (apiServer.length > 0) {
      return apiServer;
    }
    return $r('app.string.settings_server_effective_api_auto');
  }

  @Builder
  private ServerInput(controlId: string, placeholder: ResourceStr, value: string,
    onChange: (value: string) => void) {
    Row() {
      LuminousTextField({
        value: value,
        placeholder: placeholder,
        fieldWidth: this.inputWidth(),
        fieldHeight: 48,
        onChange: onChange,
      })
        .margin({ top: -10 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private ModeSelector() {
    Row() {
      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('official', $r('app.string.settings_server_official')),
          new LuminousSelectionItem('custom', $r('app.string.settings_server_custom')),
        ],
        selectedIndex: this.config.mode === 'custom' ? 1 : 0,
        controlWidth: this.selectorWidth(),
        controlHeight: 50,
        onChange: (index: number) => this.updateModeIndex(index),
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private ServerField(controlId: string, label: ResourceStr, placeholder: ResourceStr, value: string,
    onChange: (value: string) => void) {
    Column({ space: 2 }) {
      Text(label)
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.validationField === controlId
          ? $r('app.color.error')
          : $r('app.color.text_secondary'));

      this.ServerInput(controlId, placeholder, value, onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private CapabilityRow(label: ResourceStr, value: ResourceStr, available: boolean, isLast: boolean) {
    Row({ space: $r('app.float.space_12') }) {
      Circle()
        .width($r('app.float.space_8'))
        .height($r('app.float.space_8'))
        .fill(available ? $r('app.color.success') : $r('app.color.outline'));

      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'));

      Text(value)
        .layoutWeight(1)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(available ? $r('app.color.success') : $r('app.color.text_secondary'))
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .height(this.statusRowHeight())
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: $r('app.color.divider'),
    });
  }

  @Builder
  private CustomFields() {
    if (this.isWide()) {
      Column({ space: 0 }) {
        Row({ space: $r('app.float.space_16') }) {
          Column() {
            this.ServerField(
              'id-server',
              $r('app.string.settings_id_server'),
              $r('app.string.settings_id_server_placeholder'),
              this.config.idServer,
              (value: string) => this.updateIdServer(value),
            )
          }
          .layoutWeight(1);

          Column() {
            this.ServerField(
              'relay-server',
              $r('app.string.settings_relay_server'),
              $r('app.string.settings_relay_server_placeholder'),
              this.config.relayServer,
              (value: string) => this.updateRelayServer(value),
            )
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);

        Row({ space: $r('app.float.space_16') }) {
          Column() {
            this.ServerField(
              'api-server',
              $r('app.string.settings_api_server'),
              $r('app.string.settings_api_server_placeholder'),
              this.config.apiServer,
              (value: string) => this.updateApiServer(value),
            )
          }
          .layoutWeight(1);

          Column() {
            this.ServerField(
              'server-key',
              $r('app.string.settings_server_key'),
              $r('app.string.settings_server_key_placeholder'),
              this.config.key,
              (value: string) => this.updateKey(value),
            )
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      }
      .width('100%');
    } else {
      Column({ space: 0 }) {
        this.ServerField(
          'id-server',
          $r('app.string.settings_id_server'),
          $r('app.string.settings_id_server_placeholder'),
          this.config.idServer,
          (value: string) => this.updateIdServer(value),
        )
        this.ServerField(
          'relay-server',
          $r('app.string.settings_relay_server'),
          $r('app.string.settings_relay_server_placeholder'),
          this.config.relayServer,
          (value: string) => this.updateRelayServer(value),
        )
        this.ServerField(
          'api-server',
          $r('app.string.settings_api_server'),
          $r('app.string.settings_api_server_placeholder'),
          this.config.apiServer,
          (value: string) => this.updateApiServer(value),
        )
        this.ServerField(
          'server-key',
          $r('app.string.settings_server_key'),
          $r('app.string.settings_server_key_placeholder'),
          this.config.key,
          (value: string) => this.updateKey(value),
        )
      }
      .width('100%');
    }
  }

  @Builder
  private StatusSummary() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        state: LuminousSurfaceState.Inset,
        surfaceWidth: this.selectorWidth(),
        surfaceHeight: this.statusSummaryHeight(),
        cornerRadius: 18,
      }) {
        Column({ space: 0 }) {
          Row({ space: $r('app.float.space_12') }) {
            Text($r('app.string.settings_server_effective_api'))
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.neu_text_secondary'));
            Text(this.effectiveApiText())
              .layoutWeight(1)
              .fontSize($r('app.float.font_label'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_primary'))
              .textAlign(TextAlign.End)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .width('100%')
          .height(this.statusRowHeight())
          .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });

          this.CapabilityRow(
            $r('app.string.settings_server_remote_capability'),
            this.remoteStatusText(),
            this.config.remoteReachable,
            false,
          )
          this.CapabilityRow(
            $r('app.string.settings_server_account_capability'),
            this.accountStatusText(),
            this.config.accountAvailable,
            true,
          )
        }
        .width(this.selectorWidth())
        .height(this.statusSummaryHeight())
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') });
      }
    }
    .width('100%')
    .height(this.statusSummaryHeight())
    .clip(false);
  }

  @Builder
  private ActionButton(label: ResourceStr, primary: boolean, enabled: boolean,
    onClick: () => void) {
    LuminousButton({
      label: label,
      controlWidth: this.actionButtonWidth(),
      controlSizeMode: LuminousControlSize.Regular,
      tone: primary ? LuminousTone.Accent : LuminousTone.Neutral,
      isEnabled: enabled,
      onAction: onClick,
    })
  }

  @Builder
  private ActionButtons() {
    if (this.viewportWidth >= 300) {
      Row({ space: 8 }) {
        Column() {
          this.ActionButton(
            this.validating
              ? $r('app.string.settings_server_testing')
              : $r('app.string.settings_server_test'),
            false,
            !this.isBusy(),
            () => this.requestValidation(),
          )
        }
        .layoutWeight(1);

        Column() {
          this.ActionButton(
            this.saving
              ? $r('app.string.settings_server_saving')
              : $r('app.string.settings_server_save'),
            true,
            !this.isBusy(),
            () => this.requestSave(),
          )
        }
        .layoutWeight(1);
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_12') }) {
        this.ActionButton(
          this.validating
            ? $r('app.string.settings_server_testing')
            : $r('app.string.settings_server_test'),
          false,
          !this.isBusy(),
          () => this.requestValidation(),
        )
        this.ActionButton(
          this.saving
            ? $r('app.string.settings_server_saving')
            : $r('app.string.settings_server_save'),
          true,
          !this.isBusy(),
          () => this.requestSave(),
        )
      }
      .width('100%');
    }
  }

  build() {
    Column({ space: 8 }) {
      if (this.showHeader) {
        Row({ space: $r('app.float.space_16') }) {
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
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Circle()
            .width($r('app.float.space_12'))
            .height($r('app.float.space_12'))
            .fill(this.config.remoteReachable ? $r('app.color.success') : $r('app.color.outline'));
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }

      this.ModeSelector()

      Text(this.config.mode === 'official'
        ? $r('app.string.settings_server_public_hint')
        : $r('app.string.settings_server_custom_hint'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(20)
        .fontColor($r('app.color.neu_text_secondary'))
        .margin({ top: -12 });

      if (this.config.mode === 'custom') {
        this.CustomFields()
      }

      this.StatusSummary()

      if (this.validationMessage !== '') {
        Text(this.validationMessage)
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor($r('app.color.error'));
      } else if (this.config.message.trim().length > 0) {
        Text(this.config.message)
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor(this.config.remoteReachable
            ? $r('app.color.text_secondary')
            : $r('app.color.warning'));
      }

      Text($r('app.string.settings_server_validation_note'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.text_secondary'));

      this.ActionButtons()
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
