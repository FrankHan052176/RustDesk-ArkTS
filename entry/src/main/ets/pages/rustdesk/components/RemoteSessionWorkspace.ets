@ComponentV2
export struct RemoteSessionResumeChip {
  @Param sessionCount: number = 0;
  @Param label: string = '远程会话';
  @Param needsAttention: boolean = false;
  @Event onResume: () => void = (): void => {};

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        Stack()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.needsAttention
            ? $r('app.color.error')
            : $r('app.color.success'));
        Column({ space: 1 }) {
          Text('返回远控')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));
          Text(`${this.label} · ${this.sessionCount} 个会话`)
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('›')
          .fontSize(22)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%')
      .padding({ left: 12, right: 10 });
    }
    .width('100%')
    .height(54)
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.66,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_18'))
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .accessibilityText(`返回远控，${this.sessionCount} 个已连接设备`)
    .onClick((): void => this.onResume());
  }
}
