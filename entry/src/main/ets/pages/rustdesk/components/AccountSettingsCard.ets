export interface AccountSettingsCardProps {
  showHeader: boolean;
}

@ComponentV2
export struct AccountSettingsCard {
  @Param showHeader: boolean = true;

  build() {
    Column({ space: $r('app.float.space_16') }) {
      if (this.showHeader) {
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
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }

      Column({ space: $r('app.float.space_8') }) {
        Text($r('app.string.settings_account_unavailable'))
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));

        Text($r('app.string.settings_account_unavailable_detail'))
          .width('100%')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%')
      .padding($r('app.float.space_16'))
      .backgroundColor($r('app.color.surface_secondary'))
      .borderRadius($r('app.float.radius_14'))
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true);
  }
}
