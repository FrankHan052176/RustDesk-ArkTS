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

@ComponentV2
export struct ServerSettingsCard {
  @Param showHeader: boolean = false;
  @Param config: ServerConfig = new ServerConfig();
  @Param profile: ServerProfileState = new ServerProfileState();
  @Param validating: boolean = false;
  @Param saving: boolean = false;
  @Param probeMessage: string = '';
  @Local viewportWidth: number = 390;
  @Event onConfigChange: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onValidate: (config: ServerConfig) => void = (_config: ServerConfig) => {};
  @Event onFlush: (retry?: boolean) => void = (_retry?: boolean) => {};

  aboutToDisappear(): void { this.onFlush(false); }

  private inputWidth(): number {
    return Math.max(96, this.viewportWidth - 16);
  }

  private copyDraft(): ServerConfig {
    const next = new ServerConfig();
    next.mode = this.config.mode;
    next.idServer = this.config.idServer;
    next.relayServer = this.config.relayServer;
    next.apiServer = this.config.apiServer;
    next.key = this.config.key;
    next.keyInput = this.config.keyInput;
    next.keyEdited = this.config.keyEdited;
    next.keyNeedsEntry = this.config.keyNeedsEntry;
    next.draftRevision = this.config.draftRevision;
    next.draftEditToken = this.config.draftEditToken;
    next.draftKeyConfigured = this.config.draftKeyConfigured;
    next.draftKeyAction = this.config.draftKeyAction;
    next.keyKind = this.config.keyKind;
    next.keyConfigured = this.config.keyConfigured;
    next.keyVersion = this.config.keyVersion;
    return next;
  }

  private updateMode(mode: ServerMode): void {
    const next = this.copyDraft();
    next.mode = mode;
    this.onConfigChange(next);
  }

  private updateField(field: string, value: string): void {
    const next = this.copyDraft();
    if (field === 'id') { next.idServer = value; }
    else if (field === 'relay') { next.relayServer = value; }
    else if (field === 'api') { next.apiServer = value; }
    else {
      next.keyInput = value;
      next.keyEdited = true;
      next.keyNeedsEntry = false;
    }
    this.onConfigChange(next);
  }

  private keyValue(): string {
    if (this.config.keyEdited) { return this.config.keyInput; }
    return this.config.draftKeyConfigured ||
      (this.config.draftRevision > 0 && this.config.draftKeyAction === 'clear') ? '' : this.config.key;
  }

  private statusText(): string {
    if (this.saving || this.config.resultState === 'pending') { return '正在自动保存…'; }
    if (this.config.resultState === 'saved') { return this.config.message || '已自动生效'; }
    return this.config.message;
  }

  private retryable(): boolean {
    return this.config.resultState === 'error' || this.config.resultState === 'unknown';
  }

  @Builder
  private ServerField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, secret: boolean = false) {
    Column({ space: 4 }) {
      Text(label)
        .width(this.inputWidth())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));
      LuminousTextField({
        value: value,
        placeholder: placeholder,
        fieldWidth: this.inputWidth(),
        fieldHeight: 48,
        inputType: secret ? InputType.Password : InputType.Normal,
        motionEnabled: true,
        onChange: onChange,
      })
        .margin({ top: -8 })
        .translate({ x: -(LuminousNeoTokens.shadowPaddingFor(48) - 8) })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  build() {
    Column({ space: 12 }) {
      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('official', '官方服务器'),
          new LuminousSelectionItem('custom', '自定义服务器'),
        ],
        selectedIndex: this.config.mode === 'custom' ? 1 : 0,
        controlWidth: Math.max(96, this.inputWidth() - LuminousNeoTokens.shadowPaddingFor(50) * 2),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number): void => this.updateMode(index === 1 ? 'custom' : 'official'),
      })

      if (this.config.mode === 'custom') {
        this.ServerField('ID Server', 'id.example.com:21116', this.config.idServer,
          (value: string): void => this.updateField('id', value));
        this.ServerField('Relay Server', '选填，relay.example.com:21117', this.config.relayServer,
          (value: string): void => this.updateField('relay', value));
        this.ServerField('API Server', '选填，https://api.example.com', this.config.apiServer,
          (value: string): void => this.updateField('api', value));
        this.ServerField('Key', (this.config.draftKeyConfigured || this.config.keyKind === 'shared') && !this.config.keyEdited
          ? '已保存 Key，输入新 Key 可替换' : '公钥或共享密钥', this.keyValue(),
          (value: string): void => this.updateField('key', value),
          this.config.keyEdited || this.config.draftKeyConfigured || this.config.keyKind === 'shared');
        if (this.config.keyConfigured || this.config.draftKeyConfigured || this.config.keyEdited || this.config.keyKind === 'conflict') {
          Row() {
            if (this.config.keyKind === 'shared' && !this.config.keyEdited) {
              Text('已配置共享 Key').fontSize(12).fontColor($r('app.color.neu_text_secondary'));
            }
            Blank();
            Text('清除 Key')
              .fontSize(12)
              .fontColor($r('app.color.neu_accent'))
              .padding(8)
              .onClick((): void => this.updateField('key', ''));
          }.width(this.inputWidth());
        }
        if (this.config.keyKind === 'conflict') {
          Text('旧配置包含两个 Key，未用于新连接。请在此输入一个 Key 或清除。')
            .width(this.inputWidth()).fontSize(12).fontColor($r('app.color.warning'));
        }
        if (this.config.keyKind === 'shared' && !this.config.keyEdited) {
          Text('共享 Key 无法验证远程身份，连接可能不加密。')
            .width(this.inputWidth()).fontSize(12).fontColor($r('app.color.warning'));
        }
      }

      if (this.statusText().length > 0) {
        Row({ space: 6 }) {
          if (this.saving) { LoadingProgress().width(16).height(16); }
          Text(this.statusText())
            .fontSize(12)
            .fontColor(this.retryable() ? $r('app.color.error') : $r('app.color.neu_text_secondary'));
        }.width(this.inputWidth());
      }
      if (this.retryable() && !this.saving) {
        Text('重试自动保存')
          .fontSize(12).fontColor($r('app.color.neu_accent'))
          .padding(8).onClick((): void => this.onFlush(true));
      }
      if (this.probeMessage.length > 0) {
        Text(this.probeMessage).width(this.inputWidth()).fontSize(12)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      LuminousButton({
        label: this.validating ? '正在测试 TCP 连接…' : '测试连接',
        controlWidth: Math.max(96, this.inputWidth() - 32),
        controlSizeMode: LuminousControlSize.Regular,
        tone: LuminousTone.Accent,
        isEnabled: !this.validating,
        motionEnabled: true,
        onAction: (): void => this.onValidate(this.copyDraft()),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) { this.viewportWidth = width; }
    });
  }
}
