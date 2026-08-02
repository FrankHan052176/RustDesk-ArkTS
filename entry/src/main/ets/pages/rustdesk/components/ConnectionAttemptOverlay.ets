export interface ConnectionAttemptOverlayProps {
  visible: boolean;
  phase: string;
  target: string;
  message: string;
  bottomAvoidInset: number;
  onCancel: () => void;
  onRetry: () => void;
  onDismiss: () => void;
}

@ComponentV2
export struct ConnectionAttemptOverlay {
  @Param visible: boolean = false;
  @Param phase: string = 'idle';
  @Param target: string = '';
  @Param message: string = '';
  @Param bottomAvoidInset: number = 0;
  @Event onCancel: () => void = () => {};
  @Event onRetry: () => void = () => {};
  @Event onDismiss: () => void = () => {};

  private isFailed(): boolean {
    return this.phase === 'failed';
  }

  private title(): string {
    if (this.phase === 'waiting_for_easytier') {
      return '正在准备 EasyTier 网络';
    }
    if (this.phase === 'awaiting_password') {
      return '等待密码验证';
    }
    if (this.phase === 'authenticating') {
      return '正在验证密码';
    }
    if (this.phase === 'connected') {
      return '连接成功';
    }
    if (this.isFailed()) {
      return '连接未完成';
    }
    return '正在连接';
  }

  private detail(): string {
    if (this.message.trim().length > 0) {
      return this.message.trim();
    }
    if (this.isFailed()) {
      return '请检查设备状态、网络或密码后重试。';
    }
    if (this.phase === 'waiting_for_easytier') {
      return 'RustDesk 尚未创建会话；EasyTier 确认实例运行后才会继续。';
    }
    return '仍停留在当前页面，连接成功后再进入会话。';
  }

  private isConnected(): boolean {
    return this.phase === 'connected';
  }

  private panelHeight(): number {
    return this.isFailed() ? 228 : 216;
  }

  private innerContentPadding(): number {
    return 20;
  }

  private messageSlotHeight(): number {
    return this.isFailed() ? 44 : 40;
  }

  private statusBackground(): ResourceColor {
    if (this.isFailed()) {
      return $r('app.color.error_soft');
    }
    if (this.isConnected()) {
      return $r('app.color.success_soft');
    }
    return $r('app.color.brand_primary_soft');
  }

  private statusColor(): ResourceColor {
    if (this.isFailed()) {
      return $r('app.color.error');
    }
    if (this.isConnected()) {
      return $r('app.color.success');
    }
    return $r('app.color.brand_primary');
  }

  @Builder
  private StatusMark() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isFailed()) {
        Text('!')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusColor());
      } else if (this.isConnected()) {
        Text('✓')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusColor());
      } else {
        LoadingProgress()
          .width($r('app.float.icon_regular'))
          .height($r('app.float.icon_regular'))
          .color(this.statusColor());
      }
    }
    .width($r('app.float.control_small'))
    .height($r('app.float.control_small'))
    .backgroundColor(this.statusBackground())
    .borderRadius($r('app.float.radius_pill'))
    .accessibilityLevel('no');
  }

  @Builder
  private DetailSlot() {
    Stack({ alignContent: Alignment.Start }) {
      Text(this.detail())
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(21)
        .fontColor(this.isFailed() ? $r('app.color.error') : $r('app.color.neu_text_secondary'))
        .maxLines(this.isFailed() ? 3 : 2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .height(this.messageSlotHeight())
    .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4') });
  }

  @Builder
  private DialogButton(label: string, accent: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor(accent ? $r('app.color.white') : $r('app.color.neu_text_primary'));
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
    .backgroundColor(accent ? $r('app.color.brand_primary') : $r('app.color.surface_secondary'))
    .border({ width: 1, color: accent ? $r('app.color.brand_primary') : $r('app.color.outline') })
    .borderRadius($r('app.float.radius_14'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .onClick((): void => {
      onClick();
    });
  }

  @Builder
  private ActionRow() {
    if (this.isFailed()) {
      Row({ space: $r('app.float.space_12') }) {
        this.DialogButton('关闭', false, (): void => this.onDismiss())
        this.DialogButton('重试', true, (): void => this.onRetry())
      }
      .width('100%');
    } else {
      Row() {
        Blank()
        Row() {
          this.DialogButton('取消连接', false, (): void => this.onCancel())
        }
        .width(240)
        Blank()
      }
      .width('100%');
    }
  }

  build(): void {
    if (this.visible) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Row({ space: $r('app.float.space_12') }) {
            this.StatusMark();

            Column({ space: $r('app.float.space_4') }) {
              Text(this.title())
                .width('100%')
                .fontSize($r('app.float.font_body_large'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'));

              Text(this.target.length > 0 ? this.target : '远端设备')
                .width('100%')
                .fontSize($r('app.float.font_label'))
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          this.DetailSlot();
          this.ActionRow();
        }
        .width('calc(100% - 40vp)')
        .height(this.panelHeight())
        .constraintSize({ minWidth: 312, maxWidth: 520 })
        .padding(this.innerContentPadding())
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.outline') })
        .borderRadius($r('app.float.radius_24'))
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD);
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.overlay'))
      .accessibilityGroup(true)
      .accessibilityText(this.title());
    }
  }
}
