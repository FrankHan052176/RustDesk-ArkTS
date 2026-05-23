@CustomDialog
export struct PasswordPromptDialog {
  controller: CustomDialogController;
  initialPassword: string = '';
  initialRememberPassword: boolean = false;
  onCancel: () => void = () => {};
  onSubmit: (password: string, rememberPassword: boolean) => void = (_password: string, _remember: boolean) => {};

  @State password: string = '';
  @State rememberPassword: boolean = false;

  aboutToAppear(): void {
    this.password = this.initialPassword;
    this.rememberPassword = this.initialRememberPassword;
  }

  build() {
    Column() {
      Column({ space: 14 }) {
        Text('输入密码')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'));

        Text('连接已建立，请在 60 秒内完成密码验证。')
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));

        TextInput({ text: this.password, placeholder: 'Password' })
          .height(44)
          .backgroundColor($r('sys.color.ohos_id_color_text_field_sub_bg'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
          .type(InputType.Password)
          .onChange((value: string) => this.password = value);

        Row({ space: 10 }) {
          Checkbox()
            .select(this.rememberPassword)
            .onChange((value: boolean) => this.rememberPassword = value);

          Text('记住密码')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_primary'));
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(40)
            .backgroundColor($r('sys.color.ohos_id_color_alert'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.onCancel());

          Button('提交')
            .layoutWeight(1)
            .height(40)
            .backgroundColor($r('sys.color.ohos_id_color_component_activated'))
            .fontColor($r('sys.color.ohos_id_color_foreground_contrary'))
            .onClick(() => this.onSubmit(this.password, this.rememberPassword));
        }
        .width('100%');
      }
      .width('82%')
      .padding(20)
      .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
      .borderRadius(24);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.mask_fourth'));
  }
}
