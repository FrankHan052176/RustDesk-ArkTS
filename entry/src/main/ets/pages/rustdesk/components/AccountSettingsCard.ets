import { AccountLoginProvider, AccountState } from '../RustDeskDirectoryTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

export interface AccountSettingsCardProps {
  showHeader: boolean;
  officialServer: boolean;
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
  @Param officialServer: boolean = true;
  @Param accountState: AccountState = new AccountState();
  @Param loginProviders: AccountLoginProvider[] = [];
  @Local username: string = '';
  @Local password: string = '';
  @Local verificationCode: string = '';
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
    if (normalizedUsername.length === 0 || submittedPassword.length === 0 || this.isBusy()) {
      return;
    }
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
    const normalizedProvider = provider.trim().toLowerCase();
    if (normalizedProvider.length === 0 || this.isBusy()) {
      return;
    }
    this.onOidcLogin(normalizedProvider);
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
    Stack() {
      FloatingGlassSurface({
        surfaceColor: enabled ? $r('app.color.glass_surface') : $r('app.color.disabled_background'),
      }) {
        Row() {
          TextInput({ text: value, placeholder: placeholder })
            .width('100%')
            .height('100%')
            .enabled(enabled)
            .type(inputType)
            .fontSize(controlId === 'verification-code'
              ? $r('app.float.font_body_large')
              : $r('app.float.font_body'))
            .fontWeight(controlId === 'verification-code' ? FontWeight.Medium : FontWeight.Regular)
            .letterSpacing(controlId === 'verification-code' ? 3 : 0)
            .fontColor(enabled ? $r('app.color.text_primary') : $r('app.color.disabled_text'))
            .placeholderColor(enabled ? $r('app.color.text_tertiary') : $r('app.color.disabled_text'))
            .caretColor($r('app.color.brand_primary'))
            .borderWidth(0)
            .backgroundColor($r('app.color.transparent'))
            .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
            .maxLength(maxLength)
            .onChange(onChange);
        }
        .width('100%')
        .height('100%')
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private UsernameField() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_account_username'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

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
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private PasswordField() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_account_password'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

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
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private VerificationField() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.settings_account_verification_code'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'));

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
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private ActionButton(label: ResourceStr, tone: string, enabled: boolean,
    onClick: () => void) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: enabled,
        touchLight: true,
        lightColor: tone === 'danger' ? $r('app.color.error') : $r('app.color.point_light'),
        lightPeakIntensity: 0.58,
        onActivate: onClick,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(enabled
              ? (tone === 'primary'
                ? $r('app.color.text_inverse')
                : (tone === 'danger' ? $r('app.color.error') : $r('app.color.brand_primary')))
              : $r('app.color.disabled_text'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(enabled
          ? (tone === 'primary'
            ? $r('app.color.brand_primary')
            : (tone === 'danger' ? $r('app.color.error_soft') : $r('app.color.brand_primary_soft')))
          : $r('app.color.disabled_background'))
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_regular'));
  }

  @Builder
  private LoginButton() {
    this.ActionButton(
      this.accountState.busy
        ? $r('app.string.settings_account_logging_in')
        : $r('app.string.settings_account_login'),
      'primary',
      this.canLogin(),
      () => this.requestLogin(),
    )
  }

  @Builder
  private OidcProviderButton(provider: AccountLoginProvider) {
    this.ActionButton(
      this.providerActionLabel(provider),
      'secondary',
      !this.isBusy(),
      () => this.requestOidc(provider.name),
    )
  }

  @Builder
  private OidcProviderButtons() {
    if (this.isWide() && this.loginProviders.length <= 3) {
      Row({ space: $r('app.float.space_12') }) {
        ForEach(this.loginProviders, (provider: AccountLoginProvider) => {
          Column() {
            this.OidcProviderButton(provider)
          }
          .layoutWeight(1);
        })
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_12') }) {
        ForEach(this.loginProviders, (provider: AccountLoginProvider) => {
          this.OidcProviderButton(provider)
        })
      }
      .width('100%');
    }
  }

  @Builder
  private OidcLoginContent() {
    if (this.loginProviders.length > 0) {
      Column({ space: $r('app.float.space_12') }) {
        Row({ space: $r('app.float.space_12') }) {
          Divider()
            .layoutWeight(1)
            .strokeWidth(0.5)
            .color($r('app.color.divider'));

          Text($r('app.string.settings_account_oidc_divider'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_tertiary'));

          Divider()
            .layoutWeight(1)
            .strokeWidth(0.5)
            .color($r('app.color.divider'));
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Text(this.isOidcActive()
          ? $r('app.string.settings_account_oidc_active_hint')
          : $r('app.string.settings_account_oidc_hint'))
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'));

        if (this.isOidcActive()) {
          Text(this.activeOidcProviderLabel())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));

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
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private LoginContent() {
    Column({ space: $r('app.float.space_20') }) {
      Text(this.officialServer
        ? $r('app.string.settings_account_official_login_hint')
        : $r('app.string.settings_account_login_hint'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(20)
        .fontColor($r('app.color.text_secondary'));

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
        Column({ space: $r('app.float.space_16') }) {
          this.UsernameField()
          this.PasswordField()
        }
        .width('100%');
      }

      if (this.viewportWidth >= 520) {
        Row() {
          Blank()
            .layoutWeight(1);
          Column() {
            this.LoginButton()
          }
          .width(220);
        }
        .width('100%');
      } else {
        this.LoginButton()
      }

      Text($r('app.string.settings_account_password_note'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .lineHeight(17)
        .fontColor($r('app.color.text_secondary'));

      this.OidcLoginContent()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
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

          Text(this.officialServer
            ? $r('app.string.settings_account_official_signed_in_hint')
            : $r('app.string.settings_account_signed_in_hint'))
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
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());
    }
    .width('100%');
  }

  @Builder
  private AccountDetails() {
    Stack() {
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
      .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());
    }
    .width('100%');
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
      .width('100%')
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
    Column({ space: $r('app.float.space_24') }) {
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
