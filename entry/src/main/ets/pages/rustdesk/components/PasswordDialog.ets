import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

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
  @Local pressedAction: string = '';
  @Event onPasswordChange: (value: string) => void = (_value: string) => {};
  @Event onRememberChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onCancel: () => void = () => {};
  @Event onSubmit: () => void = () => {};


  private animateActionBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedAction = key;
      } else if (this.pressedAction === key) {
        this.pressedAction = '';
      }
    });
  }

  @Builder
  private DialogAction(key: string, label: string, primary: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (primary) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary'));
        }
        Row() {
          Text(label)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(primary ? $r('app.color.white') : $r('app.color.text_primary'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.pressedAction === key,
          primary ? $r('app.color.point_light') : $r('app.color.brand_primary'),
          0.58,
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .layoutWeight(1)
    .height($r('app.float.control_small'))
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateActionBlur(key, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateActionBlur(key, false);
      }
    })
    .onClick(onClick);
  }

  build() {
    if (this.visible) {
      Column() {
        Column({ space: $r('app.float.space_16') }) {
          Column({ space: $r('app.float.space_6') }) {
            Text('输入密码')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'));

            Text('连接已建立，请在 60 秒内完成密码验证。')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'));
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .visualEffect(RustDeskGlassEffect.contentReceiver());

          TextInput({ text: this.password, placeholder: 'Password' })
            .width('100%')
            .height($r('app.float.control_regular'))
            .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
            .backgroundColor($r('app.color.field_background'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .type(InputType.Password)
            .border({ width: $r('app.float.stroke_hairline'), color: $r('app.color.field_border') })
            .borderRadius($r('app.float.radius_14'))
            .onChange((value: string) => this.onPasswordChange(value));

          Row({ space: $r('app.float.space_8') }) {
            Checkbox()
              .select(this.rememberPassword)
              .selectedColor($r('app.color.brand_primary'))
              .onChange((value: boolean) => this.onRememberChange(value));

            Text('记住密码')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_primary'));
          }
          .width('100%')
          .height($r('app.float.control_regular'))
          .alignItems(VerticalAlign.Center)
          .visualEffect(RustDeskGlassEffect.contentReceiver());

          Row({ space: $r('app.float.space_8') }) {
            this.DialogAction('cancel', '取消', false, () => this.onCancel())
            this.DialogAction('submit', '提交', true, () => this.onSubmit())
          }
          .width('100%');
        }
        .width('82%')
        .constraintSize({ maxWidth: 480 })
        .padding($r('app.float.card_padding'))
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.72,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .borderRadius($r('app.float.radius_24'))
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .visualEffect(RustDeskGlassEffect.featherReceiver());
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.overlay'));
    }
  }
}
