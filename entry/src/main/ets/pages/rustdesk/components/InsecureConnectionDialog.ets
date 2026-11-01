import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousTone,
} from 'luminous_neo';
import { groupedRdpFingerprint, RdpCertificateChallenge } from '../RdpCertificateTrust';

export interface InsecureConnectionDialogProps {
  visible: boolean;
  message: ResourceStr;
  title?: Resource;
  subtitle?: Resource;
  certificate?: RdpCertificateChallenge;
  replaceConfirmation?: boolean;
  busy?: boolean;
  certificateError?: ResourceStr;
  onRemember?: () => void;
  onContinue: () => void;
  onDisconnect: () => void;
}

@ComponentV2
export struct InsecureConnectionDialog {
  @Param visible: boolean = false;
  /**
   * What the engine could not establish about this connection.
   *
   * An encrypted session with an unproven peer identity is not the same as an
   * unencrypted one, so the caller names which evidence is missing instead of
   * this component claiming the weaker of the two. The title and subtitle stay
   * resource references because the title is also this dialog's accessibility
   * text, and the framework resolves that from `string` or `Resource`, not from
   * their union. The detail is whatever the caller reported — the engine names
   * it at runtime — so it accepts either form, as the other dialogs here do.
   */
  @Param title: Resource = $r('app.string.insecure_connection_title');
  @Param subtitle: Resource = $r('app.string.insecure_connection_subtitle');
  @Param message: ResourceStr = '';
  @Param certificate: RdpCertificateChallenge | undefined = undefined;
  @Param replaceConfirmation: boolean = false;
  @Param busy: boolean = false;
  @Param certificateError: ResourceStr = '';
  @Local viewportWidth: number = 390;
  @Event onContinue: () => void = () => {};
  @Event onDisconnect: () => void = () => {};
  @Event onRemember: () => void = () => {};

  private panelWidth(): number {
    return Math.max(300, Math.min(480, this.viewportWidth - 48));
  }

  private buttonShadowPadding(): number {
    const controlHeight: number = LuminousNeoTokens.controlHeight(LuminousControlSize.Compact);
    return LuminousNeoTokens.shadowPaddingFor(controlHeight);
  }

  private buttonWidth(): number {
    const shadowPadding: number = this.buttonShadowPadding();
    return Math.max(112, (this.panelWidth() - 48 - 12 - shadowPadding * 4) / 2);
  }

  private buttonRowGap(): number {
    return this.buttonShadowPadding() * 2 + 12;
  }

  private buttonFrameOffsetX(): number {
    return -this.buttonShadowPadding();
  }

  private detail(): ResourceStr {
    const reported: ResourceStr = this.message;
    if (typeof reported === 'string') {
      const trimmed: string = (reported as string).trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
      return $r('app.string.insecure_connection_detail');
    }
    return reported;
  }

  private certificateReason(): Resource {
    switch (this.certificate?.reason ?? '') {
      case 'name_mismatch': return $r('app.string.rdp_certificate_name_mismatch');
      case 'expired': return $r('app.string.rdp_certificate_expired');
      case 'not_yet_valid': return $r('app.string.rdp_certificate_not_yet_valid');
      case 'pin_mismatch': return $r('app.string.rdp_certificate_pin_mismatch');
      default: return $r('app.string.rdp_certificate_untrusted');
    }
  }

  @Builder
  private certificateField(label: Resource, value: string, fingerprint: boolean = false): void {
    Column({ space: $r('app.float.space_4') }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_primary'));
      Text(value)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontFamily(fingerprint ? 'monospace' : '')
        .fontColor($r('app.color.neu_text_secondary'));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private certificateDetails(): void {
    Scroll() {
      Column({ space: $r('app.float.space_12') }) {
        Text(this.certificate?.target ?? '')
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.neu_text_primary'));
        Text(this.certificateReason())
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.error'));
        if (this.certificate?.reason === 'pin_mismatch') {
          Text($r('app.string.rdp_certificate_changed_help'))
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.neu_text_secondary'));
        }
        this.certificateField($r('app.string.rdp_certificate_subject'), this.certificate?.subject ?? '');
        this.certificateField($r('app.string.rdp_certificate_issuer'), this.certificate?.issuer ?? '');
        this.certificateField($r('app.string.rdp_certificate_validity'),
          `${this.certificate?.notBefore ?? ''}\n${this.certificate?.notAfter ?? ''}`);
        if (this.certificate?.reason === 'pin_mismatch') {
          this.certificateField($r('app.string.rdp_certificate_old_fingerprint'),
            groupedRdpFingerprint(this.certificate?.pinnedSha256 ?? ''), true);
          this.certificateField($r('app.string.rdp_certificate_new_fingerprint'),
            groupedRdpFingerprint(this.certificate?.sha256 ?? ''), true);
        } else {
          this.certificateField($r('app.string.rdp_certificate_fingerprint'),
            groupedRdpFingerprint(this.certificate?.sha256 ?? ''), true);
        }
        if (this.replaceConfirmation) {
          Text($r('app.string.rdp_certificate_replace_help'))
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.error'));
        }
        if (this.certificateError !== '') {
          Text(this.certificateError)
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.error'));
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  private certificateActions(): void {
    Column({ space: $r('app.float.space_8') }) {
      Button($r('app.string.direct_credentials_cancel'))
        .width('100%').height(44)
        .onClick((): void => this.onDisconnect());
      Button($r('app.string.rdp_certificate_connect_once'))
        .width('100%').height(44).enabled(!this.busy)
        .onClick((): void => this.onContinue());
      Button(this.replaceConfirmation ? $r('app.string.rdp_certificate_replace') : $r('app.string.rdp_certificate_remember'))
        .width('100%').height(44).enabled(!this.busy)
        .onClick((): void => this.onRemember());
    }
    .width('100%');
  }

  build(): void {
    if (this.visible) {
      Row() {
        Column({ space: $r('app.float.space_16') }) {
          Row({ space: $r('app.float.space_12') }) {
            Stack({ alignContent: Alignment.Center }) {
              Text('!')
                .fontSize($r('app.float.font_body_large'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.error'));
            }
            .width($r('app.float.control_small'))
            .height($r('app.float.control_small'))
            .backgroundColor($r('app.color.error_soft'))
            .borderRadius($r('app.float.radius_pill'))
            .accessibilityLevel('no');

            Column({ space: $r('app.float.space_4') }) {
              Text(this.title)
                .width('100%')
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.neu_text_primary'));

              Text(this.subtitle)
                .width('100%')
                .fontSize($r('app.float.font_label'))
                .fontColor($r('app.color.error'));
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          if (this.certificate !== undefined) {
            this.certificateDetails();
            this.certificateActions();
          } else {
          Text(this.detail())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .lineHeight(22)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(6)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Row({ space: this.buttonRowGap() }) {
            Row() {
              LuminousButton({
                label: '继续连接',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                motionEnabled: true,
                onAction: (): void => {
                  this.onContinue();
                },
              })
                .translate({ x: this.buttonFrameOffsetX() })
            }
            .width(this.buttonWidth())
            .clip(false);

            Row() {
              LuminousButton({
                label: '断开连接',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                motionEnabled: true,
                onAction: (): void => {
                  this.onDisconnect();
                },
              })
                .translate({ x: this.buttonFrameOffsetX() })
            }
            .width(this.buttonWidth())
            .clip(false);
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);
          }
        }
        .width(this.panelWidth())
        .height(this.certificate !== undefined ? '85%' : 'auto')
        .constraintSize({ minHeight: 300, maxHeight: this.certificate !== undefined ? 760 : 420 })
        .padding(24)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.outline') })
        .borderRadius(28)
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.overlay'))
      .accessibilityGroup(true)
      .accessibilityText(this.title)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
  }
}
