@ComponentV2
export struct FloatingDepthOverlay {
  @Param pressed: boolean = false;
  @Param compact: boolean = false;
  @Param radius: Resource = $r('app.float.radius_14');

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.transparent'))
        .borderRadius(this.radius)
        .shadow({
          radius: this.pressed ? (this.compact ? 3 : 3.5) : (this.compact ? 5.5 : 7),
          color: $r('app.color.depth_occlusion'),
          offsetX: this.pressed ? (this.compact ? 0.35 : 0.4) : (this.compact ? 1 : 1.25),
          offsetY: this.pressed ? (this.compact ? 0.6 : 0.7) : (this.compact ? 1.25 : 1.75),
          fill: true,
        })
        .opacity(this.pressed ? 0.30 : 0.56);

      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.transparent'))
        .borderRadius(this.radius)
        .shadow({
          radius: this.pressed ? (this.compact ? 1.75 : 2) : (this.compact ? 3.5 : 4.5),
          color: $r('app.color.depth_highlight'),
          offsetX: this.pressed ? (this.compact ? -0.25 : -0.3) : (this.compact ? -0.65 : -0.8),
          offsetY: this.pressed ? (this.compact ? -0.25 : -0.3) : (this.compact ? -0.65 : -0.8),
          fill: true,
        })
        .opacity(this.pressed ? 0.18 : 0.32);

      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.transparent'))
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.depth_specular'), 0],
            [$r('app.color.transparent'), 0.28],
            [$r('app.color.transparent'), 1],
          ],
        })
        .borderRadius(this.radius)
        .opacity(this.pressed ? 0.12 : 0.26);
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.radius)
    .clip(true)
    .hitTestBehavior(HitTestMode.None);
  }
}

@ComponentV2
export struct FloatingPressDepthShell {
  @Param pressed: boolean = false;
  @Param compact: boolean = false;
  @Param radius: Resource = $r('app.float.radius_14');
  @Param shadowColor: ResourceColor = $r('app.color.depth_shadow_level2');

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  build() {
    Stack() {
      Stack() {
        this.content();
      }
      .width('100%')
      .height('100%')
      .translate({ y: this.pressed ? 1 : 0 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .shadow({
      radius: this.pressed ? (this.compact ? 4.5 : 6) : (this.compact ? 10 : 14),
      color: this.shadowColor,
      offsetX: 0,
      offsetY: this.pressed ? (this.compact ? 1 : 1.5) : (this.compact ? 3.5 : 5),
    })
    .borderRadius(this.radius);
  }
}
