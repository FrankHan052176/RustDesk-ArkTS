export interface PasswordDialogProps {
  visible: boolean;
  password: string;
  rememberPassword: boolean;
  onPasswordChange: (value: string) => void;
  onRememberChange: (value: boolean) => void;
  onCancel: () => void;
  onSubmit: () => void;
}

@Component
export struct PasswordDialog {
  @Prop visible: boolean = false;
  @Prop password: string = '';
  @Prop rememberPassword: boolean = false;
  onPasswordChange: (value: string) => void = (_value: string) => {};
  onRememberChange: (value: boolean) => void = (_value: boolean) => {};
  onCancel: () => void = () => {};
  onSubmit: () => void = () => {};

  build() {
    if (this.visible) {
      Column() {
        Column({ space: 14 }) {
          Text('输入密码')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F5F7FA');

          Text('连接已建立，请在 60 秒内完成密码验证。')
            .fontSize(13)
            .fontColor('#9FB2C8');

          TextInput({ text: this.password, placeholder: 'Password' })
            .height(44)
            .backgroundColor('#0B1523')
            .fontColor('#F5F7FA')
            .placeholderColor('#60738A')
            .type(InputType.Password)
            .onChange((value: string) => this.onPasswordChange(value));

          Row({ space: 10 }) {
            Checkbox()
              .select(this.rememberPassword)
              .onChange((value: boolean) => this.onRememberChange(value));

            Text('记住密码')
              .fontSize(13)
              .fontColor('#D6E2F0');
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Row({ space: 10 }) {
            Button('取消')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#513042')
              .fontColor('#F5F7FA')
              .onClick(() => this.onCancel());

            Button('提交')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#23485E')
              .fontColor('#F5F7FA')
              .onClick(() => this.onSubmit());
          }
          .width('100%');
        }
        .width('82%')
        .padding(20)
        .backgroundColor('#101D2E')
        .borderRadius(24);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#AA06111F');
    }
  }
}
