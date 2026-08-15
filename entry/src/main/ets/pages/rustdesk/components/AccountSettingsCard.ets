import { AccountLoginProvider, AccountState } from '../RustDeskDirectoryTypes';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousSurface,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { FloatingGlassSurface } from './FloatingSurface';

export interface AccountSettingsCardProps {
  showHeader: boolean;
  accountState: AccountState;
  loginProviders: AccountLoginProvider[];
  onLogin: (username: string, password: string) => void;
  onVerify: (code: string) => void;
  onCancelChallenge: () => void;
  onOidcLogin: (provider: string) => void;
  onOidcCancel: () => void;
  onSync: () => void;
  onLogout: () => void;
}

@ComponentV2
export struct AccountSettingsCard {
  @Param showHeader: boolean = true;
  @Param accountState: AccountState = new AccountState();
  @Param loginProviders: AccountLoginProvider[] = [];
  @Local username: string = '';
  @Local password: string = '';
  @Local verificationCode: string = '';
  @Local inputError: string = '';
  @Local viewportWidth: number = 390;
  @Event onLogin: (username: string, password: string) => void = (_username: string, _password: string) => {};
  @Event onVerify: (code: string) => void = (_code: string) => {};
  @Event onCancelChallenge: () => void = () => {};
  @Event onOidcLogin: (provider: string) => void = (_provider: string) => {};
  @Event onOidcCancel: () => void = () => {};
  @Event onSync: () => void = () => {};
  @Event onLogout: () => void = () => {};

  aboutToAppear(): void {
    if (this.username.length === 0 && this.accountState.name.trim().length > 0) {
      this.username = this.accountState.name.trim();
    }
  }

  private isWide(): boolean {
    return this.viewportWidth >= 720;
  }

  private isBusy(): boolean {
    return this.accountState.busy || this.accountState.syncing;
  }

  private fieldSurfaceWidth(): number {
    if (this.isWide()) {
      return Math.max(280, (this.viewportWidth - 104) / 2);
    }
    return Math.max(280, Math.min(this.viewportWidth - 40, 560));
  }

  private actionButtonWidth(): number {
    return Math.min(this.fieldSurfaceWidth(), 440);
  }

  private fieldFrameWidth(): number {
    return this.fieldSurfaceWidth() + 40;
  }

  private providerButtonWidth(): number {
    if (this.loginProviders.length <= 1) {
      return this.actionButtonWidth();
    }
    return Math.max(118, (this.actionButtonWidth() - 36) / 2);
  }

  private hasChallenge(): boolean {
    return this.accountState.challengeId.trim().length > 0
      || this.accountState.challengeType.trim().length > 0;
  }

  private isTotpChallenge(): boolean {
    return this.accountState.challengeType.trim().toLowerCase() === 'totp';
  }

  private isOidcActive(): boolean {
    return this.accountState.oidcProvider.trim().length > 0;
  }

  private canLogin(): boolean {
    return !this.isBusy()
      && this.accountState.apiServer.trim().length > 0
      && this.username.trim().length > 0
      && this.password.length > 0;
  }

  private canVerify(): boolean {
    return !this.isBusy()
      && this.accountState.challengeId.trim().length > 0
      && this.verificationCode.trim().length > 0;
  }

  private requestLogin(): void {
    const normalizedUsername = this.username.trim();
    const submittedPassword = this.password;
    if (this.isBusy()) {
      return;
    }
    if (normalizedUsername.length === 0 || submittedPassword.trim().length === 0) {
      this.inputError = '请输入用户名和密码';
      return;
    }
    this.inputError = '';
    this.username = normalizedUsername;
    this.password = '';
    this.onLogin(normalizedUsername, submittedPassword);
  }

  private requestVerification(): void {
    const code = this.verificationCode.trim();
    if (code.length === 0 || this.isBusy()) {
      return;
    }
    this.verificationCode = '';
    this.onVerify(code);
  }

  private cancelChallenge(): void {
    if (this.isBusy()) {
      return;
    }
    this.verificationCode = '';
    this.onCancelChallenge();
  }

  private requestOidc(provider: string): void {
    const providerName = provider.trim();
    if (providerName.length === 0 || this.isBusy()) {
      return;
    }
    this.onOidcLogin(providerName);
  }

  private providerLabel(provider: AccountLoginProvider): string {
    const label = provider.label.trim();
    return label.length > 0 ? label : provider.name.trim();
  }

  private providerActionLabel(provider: AccountLoginProvider): ResourceStr {
    const normalizedProvider = provider.name.trim().toLowerCase();
    if (normalizedProvider === 'github') {
      return $r('app.string.settings_account_oidc_github');
    }
    if (normalizedProvider === 'google') {
      return $r('app.string.settings_account_oidc_google');
    }
    if (normalizedProvider === 'microsoft' || normalizedProvider === 'azure') {
      return $r('app.string.settings_account_oidc_microsoft');
    }
    return this.providerLabel(provider);
  }

  private activeOidcProviderLabel(): string {
    const activeProvider = this.accountState.oidcProvider.trim().toLowerCase();
    for (let index = 0; index < this.loginProviders.length; index += 1) {
      if (this.loginProviders[index].name.trim().toLowerCase() === activeProvider) {
        return this.providerLabel(this.loginProviders[index]);
      }
    }
    return activeProvider;
  }

  private accountTitle(): ResourceStr {
    if (this.accountState.displayName.trim().length > 0) {
      return this.accountState.displayName.trim();
    }
    if (this.accountState.name.trim().length > 0) {
      return this.accountState.name.trim();
    }
    if (this.accountState.email.trim().length > 0) {
      return this.accountState.email.trim();
    }
    return $r('app.string.settings_account_default_user');
  }

  private optionalValue(value: string): ResourceStr {
    const normalized = value.trim();
    if (normalized.length > 0) {
      return normalized;
    }
    return $r('app.string.settings_account_not_provided');
  }

  private apiServerText(): ResourceStr {
    const apiServer = this.accountState.apiServer.trim();
    if (apiServer.length > 0) {
      return apiServer;
    }
    return $r('app.string.settings_account_api_unavailable');
  }

  private statusText(): ResourceStr {
    if (this.accountState.syncing) {
      return $r('app.string.settings_account_syncing');
    }
    if (this.accountState.busy) {
      if (this.isOidcActive()) {
        return $r('app.string.settings_account_oidc_waiting_short');
      }
      return this.hasChallenge()
        ? $r('app.string.settings_account_verifying')
        : $r('app.string.settings_account_logging_in');
    }
    if (this.hasChallenge()) {
      return $r('app.string.settings_account_awaiting_verification');
    }
    if (this.accountState.loggedIn) {
      return $r('app.string.settings_account_signed_in');
    }
    return $r('app.string.settings_account_signed_out');
  }

  private statusColor(): ResourceColor {
    if (this.accountState.busy || this.accountState.syncing) {
      return $r('app.color.info');
    }
    if (this.hasChallenge()) {
      return $r('app.color.warning');
    }
    if (this.accountState.loggedIn) {
      return $r('app.color.success');
    }
    return $r('app.color.outline');
  }

  private statusBackground(): ResourceColor {
    if (this.accountState.busy || this.accountState.syncing) {
      return $r('app.color.info_soft');
    }
    if (this.hasChallenge()) {
      return $r('app.color.warning_soft');
    }
    if (this.accountState.loggedIn) {
      return $r('app.color.success_soft');
    }
    return $r('app.color.surface_secondary');
  }

  private messageColor(): ResourceColor {
    if (this.accountState.busy || this.accountState.syncing) {
      return $r('app.color.info');
    }
    if (this.accountState.loggedIn && !this.hasChallenge()) {
      return $r('app.color.success');
    }
    return $r('app.color.warning');
  }

  private messageBackground(): ResourceColor {
    if (this.accountState.busy || this.accountState.syncing) {
      return $r('app.color.info_soft');
    }
    if (this.accountState.loggedIn && !this.hasChallenge()) {
      return $r('app.color.success_soft');
    }
    return $r('app.color.warning_soft');
  }

  @Builder
  private Header() {
    Row({ space: $r('app.float.space_16') }) {
      Column({ space: $r('app.float.space_4') }) {
        Text($r('app.string.settings_account_title'))
          .width('100%')
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'));

        Text($r('app.string.settings_account_subtitle'))
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Row({ space: $r('app.float.space_8') }) {
        Circle()
          .width($r('app.float.space_8'))
          .height($r('app.float.space_8'))
          .fill(this.statusColor());

        Text(this.statusText())
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor())
          .maxLines(1);
      }
      .padding({
        left: $r('app.float.space_12'),
        right: $r('app.float.space_12'),
        top: $r('app.float.space_8'),
        bottom: $r('app.float.space_8'),
      })
      .backgroundColor(this.statusBackground())
      .borderRadius($r('app.float.radius_pill'));
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private FloatingInput(controlId: string, placeholder: ResourceStr, value: string, inputType: InputType,
    maxLength: number, enabled: boolean, onChange: (value: string) => void) {
    LuminousTextField({
      value: value,
      placeholder: placeholder,
      fieldWidth: this.fieldSurfaceWidth(),
      fieldHeight: controlId === 'verification-code' ? 58 : 54,
      inputType: inputType,
      maxLength: maxLength,
      isEnabled: enabled,
      motionEnabled: true,
      onChange: onChange,
    })
      .margin({ top: -10 })
  }

  @Builder
  private UsernameField() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_account_username'))
        .width(this.fieldSurfaceWidth())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      Row() {
        this.FloatingInput(
          'username',
          $r('app.string.settings_account_username_placeholder'),
          this.username,
          InputType.Normal,
          256,
          !this.isBusy(),
          (value: string) => this.username = value,
        )
      }
      .width(this.fieldFrameWidth())
      .justifyContent(FlexAlign.Center);
    }
    .width(this.fieldFrameWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private PasswordField() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_account_password'))
        .width(this.fieldSurfaceWidth())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      Row() {
        this.FloatingInput(
          'password',
          $r('app.string.settings_account_password_placeholder'),
          this.password,
          InputType.Password,
          256,
          !this.isBusy(),
          (value: string) => this.password = value,
        )
      }
      .width(this.fieldFrameWidth())
      .justifyContent(FlexAlign.Center);
    }
    .width(this.fieldFrameWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private VerificationField() {
    Column({ space: 2 }) {
      Text($r('app.string.settings_account_verification_code'))
        .width(this.fieldSurfaceWidth())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'));

      Row() {
        this.FloatingInput(
          'verification-code',
          $r('app.string.settings_account_code_placeholder'),
          this.verificationCode,
          InputType.Number,
          8,
          !this.isBusy(),
          (value: string) => this.verificationCode = value,
        )
      }
      .width(this.fieldFrameWidth())
      .justifyContent(FlexAlign.Center);
    }
    .width(this.fieldFrameWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ActionButton(label: ResourceStr, tone: string, enabled: boolean,
    onClick: () => void) {
    LuminousButton({
      label: label,
      controlWidth: this.actionButtonWidth(),
      controlSizeMode: LuminousControlSize.Regular,
      tone: tone === 'primary'
        ? LuminousTone.Accent
        : (tone === 'danger' ? LuminousTone.Danger : LuminousTone.Neutral),
      isEnabled: enabled,
      motionEnabled: true,
      onAction: onClick,
    })
  }

  @Builder
  private LoginButton() {
    LuminousButton({
      label: this.accountState.busy
        ? $r('app.string.settings_account_logging_in')
        : $r('app.string.settings_account_login'),
      controlWidth: this.actionButtonWidth(),
      controlSizeMode: LuminousControlSize.Regular,
      tone: LuminousTone.Accent,
      isEnabled: this.canLogin(),
      motionEnabled: true,
      onAction: () => this.requestLogin(),
    })
      .margin({ top: -16 })
  }

  @Builder
  private OidcProviderButton(provider: AccountLoginProvider) {
    LuminousButton({
      label: this.providerActionLabel(provider),
      controlWidth: this.providerButtonWidth(),
      controlSizeMode: LuminousControlSize.Compact,
      tone: LuminousTone.Neutral,
      isEnabled: !this.isBusy(),
      motionEnabled: true,
      onAction: () => this.requestOidc(provider.name),
    })
  }

  @Builder
  private OidcProviderButtons() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(this.loginProviders, (provider: AccountLoginProvider) => {
        Row() {
          this.OidcProviderButton(provider)
        }
        .margin({ left: 3, right: 3, bottom: -8 });
      })
    }
    .width(this.fieldFrameWidth());
  }

  @Builder
  private OidcLoginContent() {
    if (this.loginProviders.length > 0) {
      Column({ space: 2 }) {
        Text('浏览器授权')
          .width(this.fieldSurfaceWidth())
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_primary'));

        Text(this.isOidcActive()
          ? $r('app.string.settings_account_oidc_active_hint')
          : $r('app.string.settings_account_oidc_hint'))
          .width(this.fieldSurfaceWidth())
          .fontSize($r('app.float.font_caption'))
          .lineHeight(17)
          .fontColor($r('app.color.neu_text_secondary'));

        if (this.isOidcActive()) {
          Text(this.activeOidcProviderLabel())
            .width(this.fieldSurfaceWidth())
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_primary'));

          this.ActionButton(
            $r('app.string.settings_account_oidc_cancel'),
            'secondary',
            true,
            () => this.onOidcCancel(),
          )
        } else {
          this.OidcProviderButtons()
        }
      }
      .width(this.fieldFrameWidth())
      .alignItems(HorizontalAlign.Center);
    }
  }

  @Builder
  private LoginStatus() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.fieldSurfaceWidth(),
        surfaceHeight: 58,
        cornerRadius: 21,
        motionEnabled: true,
      }) {
        Row({ space: 10 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(this.statusColor());
          Column({ space: 2 }) {
            Text(this.statusText())
              .width('100%')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_primary'));
            Text(this.apiServerText())
              .width('100%')
              .fontSize(10)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.fieldSurfaceWidth())
        .height(58)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.fieldFrameWidth())
    .height(94)
    .clip(false)
  }

  @Builder
  private LoginContent() {
    Column({ space: 4 }) {
      this.LoginStatus();

      Text('登录后可在设备之间同步通讯录和账户信息。')
        .width(this.fieldSurfaceWidth())
        .fontSize($r('app.float.font_label'))
        .lineHeight(19)
        .fontColor($r('app.color.neu_text_secondary'))
        .margin({ top: -8 });

      if (this.isWide()) {
        Row({ space: $r('app.float.space_16') }) {
          Column() {
            this.UsernameField()
          }
          .layoutWeight(1);

          Column() {
            this.PasswordField()
          }
          .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Column({ space: 2 }) {
          this.UsernameField()
          this.PasswordField()
        }
        .width('100%');
      }

      this.LoginButton()

      if (this.inputError.length > 0) {
        Text(this.inputError)
          .width(this.fieldSurfaceWidth())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.warning'));
      }

      Text($r('app.string.settings_account_password_note'))
        .width(this.fieldSurfaceWidth())
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.neu_text_secondary'));

      this.OidcLoginContent()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ChallengeActions() {
    if (this.viewportWidth >= 520) {
      Row({ space: $r('app.float.space_12') }) {
        Column() {
          this.ActionButton(
            $r('app.string.settings_account_cancel'),
            'secondary',
            !this.isBusy(),
            () => this.cancelChallenge(),
          )
        }
        .layoutWeight(1);

        Column() {
          this.ActionButton(
            this.accountState.busy
              ? $r('app.string.settings_account_verifying')
              : $r('app.string.settings_account_verify'),
            'primary',
            this.canVerify(),
            () => this.requestVerification(),
          )
        }
        .layoutWeight(1);
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_12') }) {
        this.ActionButton(
          this.accountState.busy
            ? $r('app.string.settings_account_verifying')
            : $r('app.string.settings_account_verify'),
          'primary',
          this.canVerify(),
          () => this.requestVerification(),
        )
        this.ActionButton(
          $r('app.string.settings_account_cancel'),
          'secondary',
          !this.isBusy(),
          () => this.cancelChallenge(),
        )
      }
      .width('100%');
    }
  }

  @Builder
  private ChallengeContent() {
    Column({ space: $r('app.float.space_20') }) {
      Column({ space: $r('app.float.space_6') }) {
        Text(this.isTotpChallenge()
          ? $r('app.string.settings_account_totp_title')
          : $r('app.string.settings_account_email_title'))
          .width('100%')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));

        Text(this.isTotpChallenge()
          ? $r('app.string.settings_account_totp_hint')
          : $r('app.string.settings_account_email_hint'))
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'));

        if (!this.isTotpChallenge() && this.accountState.emailHint.trim().length > 0) {
          Text(this.accountState.emailHint.trim())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      if (this.isWide()) {
        Row({ space: $r('app.float.space_20') }) {
          Column() {
            this.VerificationField()
          }
          .layoutWeight(1);

          Column() {
            this.ChallengeActions()
          }
          .layoutWeight(1)
          .padding({ top: $r('app.float.space_20') });
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Column({ space: $r('app.float.space_16') }) {
          this.VerificationField()
          this.ChallengeActions()
        }
        .width('100%');
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private AccountInfoRow(label: ResourceStr, value: ResourceStr, isLast: boolean) {
    Row({ space: $r('app.float.space_16') }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));

      Text(value)
        .layoutWeight(1)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .constraintSize({ minHeight: 46 })
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: $r('app.color.divider'),
    });
  }

  @Builder
  private AccountIdentity() {
    Stack() {
      Row({ space: $r('app.float.space_16') }) {
        Stack() {
          Circle()
            .width($r('app.float.control_regular'))
            .height($r('app.float.control_regular'))
            .fill($r('app.color.brand_primary'));

          Text('R')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_inverse'));
        }
        .width($r('app.float.control_regular'))
        .height($r('app.float.control_regular'));

        Column({ space: $r('app.float.space_4') }) {
          Text(this.accountTitle())
            .width('100%')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text($r('app.string.settings_account_signed_in_hint'))
            .width('100%')
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding($r('app.float.space_16'))
      .borderRadius($r('app.float.radius_18'))
      .clip(true);
    }
    .width('100%');
  }

  @Builder
  private AccountDetails() {
    Stack() {
      FloatingGlassSurface({
        inset: true,
        radius: $r('app.float.radius_18'),
      }) {
        Column({ space: 0 }) {
          this.AccountInfoRow(
            $r('app.string.settings_account_username'),
            this.optionalValue(this.accountState.name),
            false,
          )
          this.AccountInfoRow(
            $r('app.string.settings_account_email'),
            this.optionalValue(this.accountState.email),
            false,
          )
          this.AccountInfoRow(
            $r('app.string.settings_server_effective_api'),
            this.apiServerText(),
            true,
          )
        }
        .width('100%')
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') });
      }
    }
    .width('100%')
    .borderRadius($r('app.float.radius_18'))
    .clip(false);
  }

  @Builder
  private SignedInActions() {
    if (this.viewportWidth >= 520) {
      Row({ space: $r('app.float.space_12') }) {
        Column() {
          this.ActionButton(
            $r('app.string.settings_account_logout'),
            'danger',
            !this.isBusy(),
            () => this.onLogout(),
          )
        }
        .layoutWeight(1);

        Column() {
          this.ActionButton(
            this.accountState.syncing
              ? $r('app.string.settings_account_syncing')
              : $r('app.string.settings_account_sync'),
            'primary',
            !this.isBusy(),
            () => this.onSync(),
          )
        }
        .layoutWeight(1);
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_12') }) {
        this.ActionButton(
          this.accountState.syncing
            ? $r('app.string.settings_account_syncing')
            : $r('app.string.settings_account_sync'),
          'primary',
          !this.isBusy(),
          () => this.onSync(),
        )
        this.ActionButton(
          $r('app.string.settings_account_logout'),
          'danger',
          !this.isBusy(),
          () => this.onLogout(),
        )
      }
      .width('100%');
    }
  }

  @Builder
  private SignedInContent() {
    Column({ space: $r('app.float.space_16') }) {
      Stack() {
        FloatingGlassSurface({
          radius: $r('app.float.radius_18'),
        }) {
          Column({ space: 0 }) {
            this.AccountIdentity()

            Divider()
              .width('100%')
              .strokeWidth(0.5)
              .color($r('app.color.divider'));

            this.AccountDetails()
          }
          .width('100%')
          .borderRadius($r('app.float.radius_18'))
          .clip(true);
        }
      }
      .width('100%')
      .borderRadius($r('app.float.radius_18'))
      .clip(false);

      this.SignedInActions()
    }
    .width('100%');
  }

  @Builder
  private MessageBanner() {
    if (this.accountState.message.trim().length > 0) {
      Row({ space: $r('app.float.space_12') }) {
        Circle()
          .width($r('app.float.space_8'))
          .height($r('app.float.space_8'))
          .fill(this.messageColor());

        Text(this.accountState.message.trim())
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor(this.messageColor());
      }
      .width('100%')
      .padding($r('app.float.space_16'))
      .backgroundColor(this.messageBackground())
      .borderRadius($r('app.float.radius_14'))
    }
  }

  build() {
    Column({ space: 8 }) {
      if (this.showHeader) {
        this.Header()
      }

      if (this.hasChallenge()) {
        this.ChallengeContent()
      } else if (this.accountState.loggedIn) {
        this.SignedInContent()
      } else {
        this.LoginContent()
      }

      this.MessageBanner()
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
