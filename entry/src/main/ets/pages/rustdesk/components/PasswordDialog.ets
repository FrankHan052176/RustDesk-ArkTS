import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

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
  @Local panelContentHeight: number = 0;
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

  private updatePanelContentHeight(newArea: Area): void {
    const height = Number(newArea.height);
    if (height > 0 && Math.abs(height - this.panelContentHeight) > 0.5) {
      this.panelContentHeight = height;
    }
  }

  @Builder
  private DialogAction(key: string, label: string, primary: boolean, onClick: () => void) {
    Stack() {
      FloatingPressDepthShell({
        pressed: this.pressedAction === key,
        compact: true,
        radius: $r('app.float.radius_14'),
      }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            if (primary) {
              Row()
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.brand_primary'));
            }

            FloatingDepthOverlay({
              pressed: this.pressedAction === key,
              compact: true,
              radius: $r('app.float.radius_14'),
            });

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
        .width('100%')
        .height('100%')
        .padding(0)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.pressedAction === key ? 0.18 : 0.48,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.animateActionBlur(key, true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.animateActionBlur(key, false);
          }
        })
        .onClick(onClick);
      }
    }
    .layoutWeight(1)
    .height($r('app.float.control_small'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  build() {
    if (this.visible) {
      Column() {
        Stack() {
          FloatingDepthOverlay({
            radius: $r('app.float.radius_24'),
          })
            .height(this.panelContentHeight);

          Column({ space: $r('app.float.space_16') }) {
            Column({ space: $r('app.float.space_6') }) {
              Text('输入密码')
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'));

              Text('保持竖屏完成验证；连接成功后再进入横屏会话。')
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
              .borderWidth(0)
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
          .width('100%')
          .padding($r('app.float.card_padding'))
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.updatePanelContentHeight(newArea);
          });
        }
        .width('82%')
        .constraintSize({ maxWidth: 480 })
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
