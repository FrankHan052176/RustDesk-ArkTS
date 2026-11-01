import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { DirectWireProtocol } from '../DirectWireCredentials';

export interface DirectCredentialsDialogProps {
  visible: boolean;
  protocol: DirectWireProtocol;
  target: string;
  username: string;
  password: string;
  errorMessage: ResourceStr;
  onUsernameChange: (value: string) => void;
  onPasswordChange: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
}

/**
 * Collects the credentials one direct VNC/RDP wire needs before it is dialled.
 *
 * A direct viewer consumes its password when it dials and its endpoint has to
 * name the RDP account, so these answers cannot arrive after the connection is
 * registered; they are asked for first and handed to the start call. The
 * component itself validates nothing: the caller owns the rules (they are the
 * engine's own), and this only reports what was typed.
 */
@ComponentV2
export struct DirectCredentialsDialog {
  @Param visible: boolean = false;
  @Param protocol: DirectWireProtocol = 'vnc';
  /** The endpoint the answers are for, shown so the operator can see the host. */
  @Param target: string = '';
  @Param username: string = '';
  @Param password: string = '';
  @Param errorMessage: ResourceStr = '';
  @Local viewportWidth: number = 390;
  @Event onUsernameChange: (value: string) => void = (_value: string) => {};
  @Event onPasswordChange: (value: string) => void = (_value: string) => {};
  @Event onCancel: () => void = () => {};
  @Event onSubmit: () => void = () => {};

  private panelWidth(): number {
    return Math.max(300, Math.min(480, this.viewportWidth - 48));
  }

  private fieldWidth(): number {
    return Math.max(220, this.panelWidth() - 96);
  }

  private buttonShadowPadding(): number {
    const controlHeight: number = LuminousNeoTokens.controlHeight(LuminousControlSize.Compact);
    return LuminousNeoTokens.shadowPaddingFor(controlHeight);
  }

  private buttonWidth(): number {
    const shadowPadding: number = this.buttonShadowPadding();
    return Math.max(112, (this.panelWidth() - 48 - shadowPadding * 4) / 2);
  }

  private buttonRowGap(): number {
    return this.buttonShadowPadding() * 2;
  }

  private buttonFrameOffsetX(): number {
    return -this.buttonShadowPadding();
  }

  private isRdp(): boolean {
    return this.protocol === 'rdp';
  }

  private title(): Resource {
    return this.isRdp()
      ? $r('app.string.direct_credentials_title_rdp')
      : $r('app.string.direct_credentials_title_vnc');
  }

  private subtitle(): ResourceStr {
    return this.isRdp()
      ? $r('app.string.direct_credentials_subtitle_rdp')
      : $r('app.string.direct_credentials_subtitle_vnc');
  }

  build(): void {
    if (this.visible) {
      Row() {
        Column({ space: $r('app.float.space_16') }) {
          Column({ space: $r('app.float.space_4') }) {
            Text(this.title())
              .width('100%')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));

            Text(this.target)
              .width('100%')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Text(this.subtitle())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .lineHeight(21)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          if (this.isRdp()) {
            Row() {
              LuminousTextField({
                value: this.username,
                placeholder: $r('app.string.direct_credentials_username_placeholder'),
                fieldWidth: this.fieldWidth(),
                fieldHeight: 52,
                maxLength: 128,
                motionEnabled: true,
                onChange: (value: string): void => {
                  this.onUsernameChange(value);
                },
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .clip(false);
          }

          Row() {
            LuminousTextField({
              value: this.password,
              placeholder: $r('app.string.direct_credentials_password_placeholder'),
              fieldWidth: this.fieldWidth(),
              fieldHeight: 52,
              inputType: InputType.Password,
              motionEnabled: true,
              onChange: (value: string): void => {
                this.onPasswordChange(value);
              },
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);


          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .width('100%')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_danger'))
              .fontWeight(FontWeight.Medium)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }

          Row({ space: this.buttonRowGap() }) {
            Row() {
              LuminousButton({
                label: $r('app.string.direct_credentials_cancel'),
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                motionEnabled: true,
                onAction: (): void => {
                  this.onCancel();
                },
              })
                .translate({ x: this.buttonFrameOffsetX() })
            }
            .width(this.buttonWidth())
            .clip(false);

            Row() {
              LuminousButton({
                label: $r('app.string.direct_credentials_submit'),
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Accent,
                motionEnabled: true,
                onAction: (): void => {
                  this.onSubmit();
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
        .width(this.panelWidth())
        .constraintSize({ minHeight: 320, maxHeight: 620 })
        .padding(24)
        .justifyContent(FlexAlign.Start)
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
      .accessibilityText(this.title())
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
  }
}
