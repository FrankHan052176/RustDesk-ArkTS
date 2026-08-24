import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSurface,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { ServerConfig, ServerEndpointTestState } from '../RustDeskDirectoryTypes';

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
    return Math.max(280, this.viewportWidth - this.surfaceHorizontalInset() * 2);
  }

  private surfaceHorizontalInset(): number {
    return 8;
  }

  private inputShadowPadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(48);
  }

  private actionButtonWidth(): number {
    return Math.max(240, this.inputWidth() - 32);
  }

  private statusSummaryHeight(): number {
    return 150;
  }

  private statusRowHeight(): number {
    return this.statusSummaryHeight() / 3;
  }

  private copyConfig(): ServerConfig {
    const next = new ServerConfig();
    next.mode = 'custom';
    next.idServer = this.config.idServer;
    next.relayServer = this.config.relayServer;
    next.apiServer = this.config.apiServer;
    next.key = this.config.key;
    next.effectiveApiServer = this.config.effectiveApiServer;
    next.usingPublicServer = false;
    next.remoteReachable = this.config.remoteReachable;
    next.accountAvailable = this.config.accountAvailable;
    next.resultState = this.config.resultState;
    next.message = this.config.message;
    next.idServerTestState = this.config.idServerTestState;
    next.relayServerTestState = this.config.relayServerTestState;
    next.apiServerTestState = this.config.apiServerTestState;
    next.idServerTestMessage = this.config.idServerTestMessage;
    next.relayServerTestMessage = this.config.relayServerTestMessage;
    next.apiServerTestMessage = this.config.apiServerTestMessage;
    return next;
  }

  private emitDraft(next: ServerConfig): void {
    next.remoteReachable = false;
    next.accountAvailable = false;
    next.resultState = 'idle';
    next.message = '';
    next.idServerTestState = 'untested';
    next.relayServerTestState = 'untested';
    next.apiServerTestState = 'untested';
    next.idServerTestMessage = '';
    next.relayServerTestMessage = '';
    next.apiServerTestMessage = '';
    this.validationMessage = '';
    this.validationField = '';
    this.onConfigChange(next);
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
    if (config.idServer.includes(' ')) {
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
    if (this.config.idServer.trim().length === 0 && this.config.relayServer.trim().length === 0) {
      return $r('app.string.settings_server_remote_unconfigured');
    }
    if (this.config.remoteReachable) {
      return $r('app.string.settings_server_remote_ready');
    }
    return $r('app.string.settings_server_remote_pending');
  }

  private resultIsSuccess(): boolean {
    return this.config.resultState === 'test-success' || this.config.resultState === 'save-success' ||
      this.config.resultState === 'empty-success' || this.config.resultState === 'success';
  }

  private resultTitle(): ResourceStr {
    if (this.config.resultState === 'save-success') {
      return $r('app.string.settings_server_save_success');
    }
    if (this.config.resultState === 'empty-success') {
      return $r('app.string.settings_server_empty_success');
    }
    return this.resultIsSuccess()
      ? $r('app.string.settings_server_test_success')
      : $r('app.string.settings_server_test_failed');
  }

  @Builder
  private ResultBanner() {
    Row({ space: $r('app.float.space_12') }) {
      Circle()
        .width($r('app.float.space_12'))
        .height($r('app.float.space_12'))
        .fill(this.resultIsSuccess() ? $r('app.color.success') : $r('app.color.error'));
      Column({ space: 2 }) {
        Text(this.resultTitle())
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.resultIsSuccess() ? $r('app.color.success') : $r('app.color.error'));
        Text(this.config.message)
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor($r('app.color.text_primary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding($r('app.float.space_16'))
    .borderRadius(16)
    .backgroundColor(this.resultIsSuccess() ? $r('app.color.success_soft') : $r('app.color.error_soft'));
  }

  private accountStatusText(): ResourceStr {
    if (this.config.accountAvailable) {
      return $r('app.string.settings_server_account_ready');
    }
    if (this.config.effectiveApiServer.trim().length === 0) {
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
        motionEnabled: true,
        onChange: onChange,
      })
        .margin({ top: -10 })
        .translate({ x: -(this.inputShadowPadding() - this.surfaceHorizontalInset()) })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }

  private endpointStatusText(value: string, state: ServerEndpointTestState): ResourceStr {
    if (value.trim().length === 0) {
      return $r('app.string.settings_server_status_unconfigured');
    }
    if (state === 'success') {
      return $r('app.string.settings_server_status_success');
    }
    if (state === 'error') {
      return $r('app.string.settings_server_status_failed');
    }
    return $r('app.string.settings_server_status_untested');
  }

  private endpointStatusColor(value: string, state: ServerEndpointTestState): ResourceColor {
    if (value.trim().length === 0 || state === 'untested') {
      return $r('app.color.text_secondary');
    }
    return state === 'success' ? $r('app.color.success') : $r('app.color.error');
  }

  private endpointActionText(state: ServerEndpointTestState): ResourceStr {
    if (state === 'success') {
      return $r('app.string.settings_server_action_retest');
    }
    if (state === 'error') {
      return $r('app.string.settings_server_action_retry');
    }
    return $r('app.string.settings_server_action_test');
  }

  private endpointErrorPrefix(controlId: string): string {
    if (controlId === 'id-server') {
      return 'ID Server:';
    }
    if (controlId === 'relay-server') {
      return 'Relay Server:';
    }
    return 'API Server:';
  }

  private hasEndpointErrorDetails(): boolean {
    return this.config.message.includes('ID Server:') || this.config.message.includes('Relay Server:') ||
      this.config.message.includes('API Server:');
  }

  private endpointDisplayState(controlId: string, value: string,
    state: ServerEndpointTestState): ServerEndpointTestState {
    if (this.validationField === controlId) {
      return 'error';
    }
    if (state !== 'untested' || value.trim().length === 0) {
      return state;
    }
    if (this.config.resultState === 'test-success' || this.config.resultState === 'success') {
      return 'success';
    }
    if (this.config.resultState === 'error') {
      if (!this.hasEndpointErrorDetails()) {
        return 'error';
      }
      return this.config.message.includes(this.endpointErrorPrefix(controlId)) ? 'error' : 'success';
    }
    return 'untested';
  }

  private endpointDisplayMessage(controlId: string, message: string): string {
    if (message.length > 0) {
      return message;
    }
    const prefix = this.endpointErrorPrefix(controlId);
    const entries = this.config.message.split(' · ');
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index].trim();
      if (entry.startsWith(prefix)) {
        return entry.substring(prefix.length).trim();
      }
    }
    return '';
  }

  @Builder
  private EndpointTestStatus(controlId: string, value: string, state: ServerEndpointTestState) {
    Row({ space: $r('app.float.space_8') }) {
      if (this.validating && value.trim().length > 0) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color($r('app.color.brand_primary'));
        Text($r('app.string.settings_server_status_testing'))
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'));
      } else {
        Circle()
          .width($r('app.float.space_8'))
          .height($r('app.float.space_8'))
          .fill(this.endpointStatusColor(value, this.endpointDisplayState(controlId, value, state)));
        Text(this.endpointStatusText(value, this.endpointDisplayState(controlId, value, state)))
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.endpointStatusColor(value, this.endpointDisplayState(controlId, value, state)));

        if (value.trim().length > 0) {
          Button(this.endpointActionText(this.endpointDisplayState(controlId, value, state)), {
            type: ButtonType.Capsule,
            stateEffect: true,
          })
            .height(30)
            .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.neu_base'))
            .border({ width: 1, color: $r('app.color.outline') })
            .enabled(!this.isBusy())
            .onClick((): void => {
              if (!this.isBusy()) {
                this.requestValidation();
              }
            })
            .accessibilityText($r('app.string.settings_server_test'));
        }
      }
    }
    .height(32)
    .padding({ left: $r('app.float.space_4') });
  }

  @Builder
  private ServerField(controlId: string, label: ResourceStr, placeholder: ResourceStr, value: string,
    state: ServerEndpointTestState, testMessage: string, testable: boolean,
    onChange: (value: string) => void) {
    Column({ space: 4 }) {
      Row() {
        Text(label)
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.validationField === controlId
            ? $r('app.color.error')
            : $r('app.color.text_secondary'));

        if (testable) {
          this.EndpointTestStatus(controlId, value, state)
        }
      }
      .width(this.inputWidth())
      .alignItems(VerticalAlign.Center);

      this.ServerInput(controlId, placeholder, value, onChange)

      if (this.validationField === controlId && this.validationMessage !== '') {
        Text(this.validationMessage)
          .width(this.inputWidth())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.error'));
      } else if (this.endpointDisplayState(controlId, value, state) === 'error' &&
        this.endpointDisplayMessage(controlId, testMessage).length > 0) {
        Text(this.endpointDisplayMessage(controlId, testMessage))
          .width(this.inputWidth())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.error'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
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
    Column({ space: $r('app.float.space_8') }) {
      this.ServerField(
        'id-server',
        $r('app.string.settings_id_server'),
        $r('app.string.settings_id_server_placeholder'),
        this.config.idServer,
        this.config.idServerTestState,
        this.config.idServerTestMessage,
        true,
        (value: string) => this.updateIdServer(value),
      )
      this.ServerField(
        'relay-server',
        $r('app.string.settings_relay_server'),
        $r('app.string.settings_relay_server_placeholder'),
        this.config.relayServer,
        this.config.relayServerTestState,
        this.config.relayServerTestMessage,
        true,
        (value: string) => this.updateRelayServer(value),
      )
      this.ServerField(
        'api-server',
        $r('app.string.settings_api_server'),
        $r('app.string.settings_api_server_placeholder'),
        this.config.apiServer,
        this.config.apiServerTestState,
        this.config.apiServerTestMessage,
        true,
        (value: string) => this.updateApiServer(value),
      )
      this.ServerField(
        'server-key',
        $r('app.string.settings_server_key'),
        $r('app.string.settings_server_key_placeholder'),
        this.config.key,
        'untested',
        '',
        false,
        (value: string) => this.updateKey(value),
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private StatusSummary() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.selectorWidth(),
        surfaceHeight: this.statusSummaryHeight(),
        cornerRadius: 18,
        motionEnabled: true,
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
      motionEnabled: true,
      onAction: onClick,
    })
  }

  @Builder
  private ActionButtons() {
    Row() {
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
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
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

      Text($r('app.string.settings_server_custom_hint'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(20)
        .fontColor($r('app.color.neu_text_secondary'));

      this.CustomFields()

      this.ActionButtons()

      Row() {
        Text($r('app.string.settings_server_validation_note'))
          .width(this.inputWidth())
          .fontSize($r('app.float.font_caption'))
          .lineHeight(17)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);
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
