import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSwitch,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';

export interface PasswordDialogProps {
  visible: boolean;
  password: string;
  rememberPassword: boolean;
  onPasswordChange: (value: string) => void;
  onRememberChange: (value: boolean) => void;
  onCancel: () => void;
  onSubmit: () => void;
}

@ComponentV2
export struct PasswordDialog {
  @Param visible: boolean = false;
  @Param password: string = '';
  @Param rememberPassword: boolean = false;
  @Local viewportWidth: number = 390;
  @Event onPasswordChange: (value: string) => void = (_value: string) => {};
  @Event onRememberChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onCancel: () => void = () => {};
  @Event onSubmit: () => void = () => {};

  private panelWidth(): number {
    return Math.max(300, Math.min(440, this.viewportWidth - 48));
  }

  private fieldWidth(): number {
    return Math.max(220, this.panelWidth() - 96);
  }

  private buttonWidth(): number {
    let controlHeight: number = LuminousNeoTokens.controlHeight(LuminousControlSize.Compact);
    let shadowPadding: number = LuminousNeoTokens.shadowPaddingFor(controlHeight);
    return Math.max(112, (this.panelWidth() - 48 - shadowPadding * 4) / 2);
  }

  build(): void {
    if (this.visible) {
      Row() {
        Column() {
          Column({ space: $r('app.float.space_6') }) {
            Text('输入密码')
              .width('100%')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));

            Text('验证完成后自动进入远端会话。')
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Row() {
            LuminousTextField({
              value: this.password,
              placeholder: 'Password',
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

          LuminousSwitch({
            label: '记住密码',
            description: '仅保存在本机安全配置中',
            isOn: this.rememberPassword,
            rowWidth: this.panelWidth() - 48,
            motionEnabled: true,
            onChange: (value: boolean): void => {
              this.onRememberChange(value);
            },
          })

          Row() {
            LuminousButton({
              label: '取消',
              controlWidth: this.buttonWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Neutral,
              motionEnabled: true,
              onAction: (): void => {
                this.onCancel();
              },
            })

            LuminousButton({
              label: '提交',
              controlWidth: this.buttonWidth(),
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Accent,
              motionEnabled: true,
              onAction: (): void => {
                this.onSubmit();
              },
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);
        }
        .width(this.panelWidth())
        .height(338)
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
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        let width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
  }
}
