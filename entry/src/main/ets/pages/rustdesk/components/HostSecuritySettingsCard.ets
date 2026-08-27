import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSwitch,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import {
  ControlledHostState,
  ControlledPasswordMode,
  ControlledTrustedDevice,
  ControlledTwoFactorState,
  PASSWORD_MODE_BOTH,
  PASSWORD_MODE_PERMANENT,
  PASSWORD_MODE_TEMPORARY,
} from '../../../services/controlled/ControlledHostTypes';
import { FloatingGlassSurface } from './FloatingSurface';

export interface HostSecuritySettingsCardProps {
  hostState: ControlledHostState;
  twoFactor: ControlledTwoFactorState;
  onRefresh: () => void;
  onPasswordModeChange: (mode: ControlledPasswordMode) => void;
  onSetPermanentPassword: (password: string, confirmation: string) => void;
  onRemovePermanentPassword: () => void;
  onBeginTwoFactor: () => void;
  onVerifyTwoFactor: (code: string) => void;
  onCancelTwoFactor: () => void;
  onDisableTwoFactor: () => void;
  onTrustedDevicesEnabledChange: (enabled: boolean) => void;
  onRemoveTrustedDevice: (device: ControlledTrustedDevice) => void;
  onClearTrustedDevices: () => void;
}

@ComponentV2
export struct HostSecuritySettingsCard {
  @Param hostState: ControlledHostState = new ControlledHostState();
  @Param twoFactor: ControlledTwoFactorState = new ControlledTwoFactorState();
  @Local viewportWidth: number = 390;
  @Local fixedPassword: string = '';
  @Local fixedPasswordConfirmation: string = '';
  @Local twoFactorCode: string = '';
  @Local setupSecretVisible: boolean = false;
  @Local confirmRemovePassword: boolean = false;
  @Local confirmDisableTwoFactor: boolean = false;
  @Local confirmClearTrustedDevices: boolean = false;
  @Event onRefresh: () => void = () => {};
  @Event onPasswordModeChange: (mode: ControlledPasswordMode) => void = (_mode: ControlledPasswordMode) => {};
  @Event onSetPermanentPassword: (password: string, confirmation: string) => void =
    (_password: string, _confirmation: string) => {};
  @Event onRemovePermanentPassword: () => void = () => {};
  @Event onBeginTwoFactor: () => void = () => {};
  @Event onVerifyTwoFactor: (code: string) => void = (_code: string) => {};
  @Event onCancelTwoFactor: () => void = () => {};
  @Event onDisableTwoFactor: () => void = () => {};
  @Event onTrustedDevicesEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onRemoveTrustedDevice: (device: ControlledTrustedDevice) => void = (_device: ControlledTrustedDevice) => {};
  @Event onClearTrustedDevices: () => void = () => {};

  aboutToDisappear(): void {
    this.clearSecretDrafts();
    this.setupSecretVisible = false;
    if (this.twoFactor.setupUri.length > 0 && !this.twoFactor.enabled) {
      this.onCancelTwoFactor();
    }
  }

  @Monitor('twoFactor.setupUri')
  private onTwoFactorSetupChanged(_monitor: IMonitor): void {
    this.twoFactorCode = '';
    this.setupSecretVisible = false;
  }

  private compact(): boolean {
    return this.viewportWidth < 640;
  }

  private surfaceWidth(): number {
    return Math.max(280, Math.min(this.viewportWidth - 16, 920));
  }

  private innerWidth(): number {
    return Math.max(220, this.surfaceWidth() - (this.compact() ? 32 : 44));
  }

  private fieldWidth(): number {
    return Math.max(200, this.innerWidth() - LuminousNeoTokens.shadowPaddingFor(48) * 2);
  }

  private selectorWidth(): number {
    return Math.max(240, this.innerWidth() - LuminousNeoTokens.shadowPaddingFor(52) * 2);
  }

  private actionWidth(): number {
    return Math.max(108, (this.innerWidth() - 12) / 2 - LuminousNeoTokens.shadowPaddingFor(48) * 2);
  }

  private passwordModeIndex(): number {
    if (this.hostState.verificationMethod === PASSWORD_MODE_TEMPORARY) {
      return 0;
    }
    if (this.hostState.verificationMethod === PASSWORD_MODE_PERMANENT) {
      return 1;
    }
    return 2;
  }

  private permanentPasswordEnabled(): boolean {
    return this.hostState.verificationMethod !== PASSWORD_MODE_TEMPORARY;
  }

  private passwordValidationText(): string {
    if (this.fixedPassword.length === 0 && this.fixedPasswordConfirmation.length === 0) {
      return '';
    }
    if (this.fixedPassword.length < 6) {
      return '固定密码至少需要 6 个字符。';
    }
    if (this.fixedPassword.length > this.hostState.maxPasswordLength) {
      return `固定密码不能超过 ${this.hostState.maxPasswordLength} 个字符。`;
    }
    if (this.fixedPassword !== this.fixedPasswordConfirmation) {
      return '两次输入的固定密码不一致。';
    }
    return '';
  }

  private canSubmitPassword(): boolean {
    return !this.hostState.permanentPasswordChangeDisabled && this.fixedPassword.length >= 6 &&
      this.fixedPassword === this.fixedPasswordConfirmation &&
      this.fixedPassword.length <= this.hostState.maxPasswordLength;
  }

  private clearPasswordDrafts(): void {
    this.fixedPassword = '';
    this.fixedPasswordConfirmation = '';
  }

  private clearSecretDrafts(): void {
    this.clearPasswordDrafts();
    this.twoFactorCode = '';
  }

  private submitPermanentPassword(): void {
    if (!this.canSubmitPassword()) {
      return;
    }
    const password: string = this.fixedPassword;
    const confirmation: string = this.fixedPasswordConfirmation;
    this.clearPasswordDrafts();
    this.onSetPermanentPassword(password, confirmation);
  }

  private setupSecret(): string {
    const result: RegExpExecArray | null = /(?:\?|&)secret=([^&]+)/.exec(this.twoFactor.setupUri);
    if (result === null || result.length < 2) {
      return '';
    }
    return decodeURIComponent(result[1]);
  }

  private trustedDeviceTitle(device: ControlledTrustedDevice): string {
    const name: string = device.name.trim();
    if (name.length > 0) {
      return name;
    }
    const id: string = device.id.trim();
    return id.length > 0 ? id : '未命名设备';
  }

  private passwordMeasurementKey(): string {
    return `${this.hostState.verificationMethod}:${String(this.hostState.permanentPasswordSet)}:` +
      `${String(this.confirmRemovePassword)}:${this.passwordValidationText()}`;
  }

  private twoFactorMeasurementKey(): string {
    return `${String(this.twoFactor.setupUri.length > 0)}:${String(this.twoFactor.enabled)}:` +
      `${String(this.confirmDisableTwoFactor)}:${String(this.setupSecretVisible)}:` +
      `${this.twoFactor.trustedDevices.length}`;
  }

  @Builder
  private SectionHeading(icon: Resource, title: ResourceStr, subtitle: ResourceStr) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor([$r('app.color.neu_accent')]);
      Column({ space: 3 }) {
        Text(title)
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text(subtitle)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%');
  }

  @Builder
  private PasswordSection() {
    FloatingGlassSurface({
      surfaceWidth: this.surfaceWidth(),
      radius: $r('app.float.radius_24'),
      measurementKey: this.passwordMeasurementKey(),
    }) {
      Column({ space: 16 }) {
        this.SectionHeading($r('sys.symbol.lock_shield'), '访问密码',
          '密码只通过回调交给安全服务处理；输入草稿不会持久化，也不会写入日志。');
        LuminousSegmentedControl({
          items: [
            new LuminousSelectionItem('temporary', '临时密码'),
            new LuminousSelectionItem('permanent', '固定密码'),
            new LuminousSelectionItem('both', '两者'),
          ],
          selectedIndex: this.passwordModeIndex(),
          controlWidth: this.selectorWidth(),
          controlHeight: 52,
          motionEnabled: true,
          onChange: (index: number): void => {
            const modes: ControlledPasswordMode[] = [
              PASSWORD_MODE_TEMPORARY,
              PASSWORD_MODE_PERMANENT,
              PASSWORD_MODE_BOTH,
            ];
            this.clearPasswordDrafts();
            this.onPasswordModeChange(modes[index]);
          },
        })
          .opacity(this.hostState.verificationMethodFixed ? 0.56 : 1)
          .enabled(!this.hostState.verificationMethodFixed);
        if (this.permanentPasswordEnabled()) {
          Text(this.hostState.permanentPasswordSet ? '固定密码已设置' : '固定密码尚未设置')
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.hostState.permanentPasswordSet
              ? $r('app.color.success') : $r('app.color.warning'));
          LuminousTextField({
            value: this.fixedPassword,
            placeholder: this.hostState.permanentPasswordSet ? '输入新的固定密码' : '设置固定密码',
            fieldWidth: this.fieldWidth(),
            fieldHeight: 48,
            inputType: InputType.Password,
            maxLength: this.hostState.maxPasswordLength,
            isEnabled: !this.hostState.permanentPasswordChangeDisabled,
            onChange: (value: string): void => {
              this.fixedPassword = value;
            },
          });
          LuminousTextField({
            value: this.fixedPasswordConfirmation,
            placeholder: '再次输入固定密码',
            fieldWidth: this.fieldWidth(),
            fieldHeight: 48,
            inputType: InputType.Password,
            maxLength: this.hostState.maxPasswordLength,
            isEnabled: !this.hostState.permanentPasswordChangeDisabled,
            onChange: (value: string): void => {
              this.fixedPasswordConfirmation = value;
            },
          });
          Text('至少 6 个字符；两次输入必须一致。')
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r('app.color.neu_text_secondary'));
          if (this.passwordValidationText().length > 0) {
            Text(this.passwordValidationText())
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.error'));
          }
          LuminousButton({
            label: this.hostState.permanentPasswordSet ? '更改固定密码' : '设置固定密码',
            controlWidth: this.fieldWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Accent,
            isEnabled: this.canSubmitPassword(),
            onAction: () => this.submitPermanentPassword(),
          });
          if (this.hostState.permanentPasswordSet) {
            if (this.confirmRemovePassword) {
              Text('移除后，固定密码模式将无法继续用于认证。')
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.warning'));
              Row({ space: 12 }) {
                LuminousButton({
                  label: '取消',
                  controlWidth: this.actionWidth(),
                  controlSizeMode: LuminousControlSize.Compact,
                  tone: LuminousTone.Neutral,
                  onAction: () => this.confirmRemovePassword = false,
                });
                LuminousButton({
                  label: '确认移除',
                  controlWidth: this.actionWidth(),
                  controlSizeMode: LuminousControlSize.Compact,
                  tone: LuminousTone.Danger,
                  onAction: (): void => {
                    this.confirmRemovePassword = false;
                    this.clearPasswordDrafts();
                    this.onRemovePermanentPassword();
                  },
                });
              }
              .width('100%');
            } else {
              LuminousButton({
                label: '移除固定密码',
                controlWidth: this.fieldWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                isEnabled: !this.hostState.permanentPasswordChangeDisabled,
                onAction: () => this.confirmRemovePassword = true,
              });
            }
          }
        }
        if (this.hostState.passwordError.length > 0) {
          Text(this.hostState.passwordError)
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.error'));
        }
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private TwoFactorSection() {
    FloatingGlassSurface({
      surfaceWidth: this.surfaceWidth(),
      radius: $r('app.float.radius_24'),
      measurementKey: this.twoFactorMeasurementKey(),
    }) {
      Column({ space: 16 }) {
        this.SectionHeading($r('sys.symbol.checkmark_shield'), '双重认证',
          '2FA 在密码验证成功后执行，不能替代密码。');
        if (this.twoFactor.setupUri.length > 0 && !this.twoFactor.enabled) {
          Text('使用验证器扫描二维码，或手动输入下方密钥。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.neu_text_secondary'));
          QRCode(this.twoFactor.setupUri)
            .width(180)
            .height(180)
            .color(Color.Black)
            .backgroundColor(Color.White);
          Text(this.setupSecretVisible ? this.setupSecret() : '•••• •••• •••• ••••')
            .width('100%')
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor($r('app.color.neu_text_primary'))
            .copyOption(this.setupSecretVisible ? CopyOptions.LocalDevice : CopyOptions.None);
          LuminousButton({
            label: this.setupSecretVisible ? '隐藏手动密钥' : '显示手动密钥',
            controlWidth: this.fieldWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Neutral,
            onAction: () => this.setupSecretVisible = !this.setupSecretVisible,
          });
          LuminousTextField({
            value: this.twoFactorCode,
            placeholder: '输入 6 位验证码',
            fieldWidth: this.fieldWidth(),
            fieldHeight: 48,
            inputType: InputType.Number,
            maxLength: 6,
            isEnabled: !this.twoFactor.busy,
            onChange: (value: string): void => {
              this.twoFactorCode = value;
            },
          });
          Row({ space: 12 }) {
            LuminousButton({
              label: '取消',
              controlWidth: this.actionWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Neutral,
              onAction: (): void => {
                this.twoFactorCode = '';
                this.setupSecretVisible = false;
                this.onCancelTwoFactor();
              },
            });
            LuminousButton({
              label: '验证并启用',
              controlWidth: this.actionWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Accent,
              isEnabled: /^\d{6}$/.test(this.twoFactorCode) && !this.twoFactor.busy,
              onAction: (): void => {
                const code: string = this.twoFactorCode;
                this.twoFactorCode = '';
                this.onVerifyTwoFactor(code);
              },
            });
          }
          .width('100%');
        } else if (this.twoFactor.enabled) {
          Text('双重认证已启用')
            .width('100%')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.success'));
          LuminousSwitch({
            label: '启用受信任设备',
            description: '受信任设备仍需密码，只在有效期内免除第二因素。',
            isOn: this.twoFactor.trustedDevicesEnabled,
            rowWidth: this.fieldWidth(),
            motionEnabled: true,
            onChange: (enabled: boolean): void => {
              if (!this.twoFactor.trustedDevicesFixed && !this.twoFactor.busy) {
                this.onTrustedDevicesEnabledChange(enabled);
              }
            },
          })
            .opacity(this.twoFactor.trustedDevicesFixed ? 0.56 : 1)
            .enabled(!this.twoFactor.trustedDevicesFixed && !this.twoFactor.busy);
          if (this.confirmDisableTwoFactor) {
            Text('关闭 2FA 会同时清空全部受信任设备。')
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.warning'));
            Row({ space: 12 }) {
              LuminousButton({
                label: '取消',
                controlWidth: this.actionWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                onAction: () => this.confirmDisableTwoFactor = false,
              });
              LuminousButton({
                label: '确认关闭',
                controlWidth: this.actionWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                onAction: (): void => {
                  this.confirmDisableTwoFactor = false;
                  this.onDisableTwoFactor();
                },
              });
            }
            .width('100%');
          } else {
            LuminousButton({
              label: '关闭双重认证',
              controlWidth: this.fieldWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Danger,
              isEnabled: !this.twoFactor.busy,
              onAction: () => this.confirmDisableTwoFactor = true,
            });
          }
        } else {
          LuminousButton({
            label: '设置双重认证',
            controlWidth: this.fieldWidth(),
            controlSizeMode: LuminousControlSize.Regular,
            tone: LuminousTone.Accent,
            isEnabled: !this.twoFactor.busy,
            onAction: () => this.onBeginTwoFactor(),
          });
        }
        if (this.twoFactor.errorText.length > 0) {
          Text(this.twoFactor.errorText)
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.error'));
        }
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private TrustedDevicesSection() {
    FloatingGlassSurface({
      surfaceWidth: this.surfaceWidth(),
      radius: $r('app.float.radius_24'),
      measurementKey: `${this.twoFactor.trustedDevices.length}:${String(this.confirmClearTrustedDevices)}`,
    }) {
      Column({ space: 14 }) {
        this.SectionHeading($r('sys.symbol.person_crop_circle_fill'), '受信任设备',
          '列表仅显示设备标识信息；受信任状态只跳过 2FA，不会绕过密码。');
        Text(this.twoFactor.trustedDevicesEnabled ? '功能已启用' : '功能已关闭')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.twoFactor.trustedDevicesEnabled
            ? $r('app.color.success') : $r('app.color.neu_text_secondary'));
        if (this.twoFactor.trustedDevices.length === 0) {
          Text('暂无受信任设备')
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.neu_text_secondary'));
        } else {
          ForEach(this.twoFactor.trustedDevices, (device: ControlledTrustedDevice) => {
            Row({ space: 12 }) {
              Column({ space: 3 }) {
                Text(this.trustedDeviceTitle(device))
                  .width('100%')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.neu_text_primary'));
                Text(`${device.platform.length > 0 ? device.platform : '未知平台'} · ${device.id}`)
                  .width('100%')
                  .fontSize(11)
                  .fontColor($r('app.color.neu_text_secondary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              LuminousButton({
                label: '移除',
                controlWidth: 96,
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                onAction: () => this.onRemoveTrustedDevice(device),
              });
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .alignItems(VerticalAlign.Center);
          }, (device: ControlledTrustedDevice) => `${device.id}-${device.time}`);
          if (this.confirmClearTrustedDevices) {
            Text('确认清空全部受信任设备？此操作不能撤销。')
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.warning'));
            Row({ space: 12 }) {
              LuminousButton({
                label: '取消',
                controlWidth: this.actionWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                onAction: () => this.confirmClearTrustedDevices = false,
              });
              LuminousButton({
                label: '确认清空',
                controlWidth: this.actionWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                onAction: (): void => {
                  this.confirmClearTrustedDevices = false;
                  this.onClearTrustedDevices();
                },
              });
            }
            .width('100%');
          } else {
            LuminousButton({
              label: '清空受信任设备',
              controlWidth: this.fieldWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Danger,
              onAction: () => this.confirmClearTrustedDevices = true,
            });
          }
        }
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  build(): void {
    Column({ space: 22 }) {
      this.PasswordSection();
      this.TwoFactorSection();
      if (this.twoFactor.enabled) {
        this.TrustedDevicesSection();
      }
      LuminousButton({
        label: '刷新安全状态',
        controlWidth: this.surfaceWidth(),
        controlSizeMode: LuminousControlSize.Compact,
        tone: LuminousTone.Neutral,
        onAction: () => this.onRefresh(),
      });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width: number = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
