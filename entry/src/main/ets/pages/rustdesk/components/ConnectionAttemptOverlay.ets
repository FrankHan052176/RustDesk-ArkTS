export interface ConnectionAttemptOverlayProps {
  visible: boolean;
  phase: string;
  target: string;
  message: string;
  /** The direct route is what failed: offer one retry through the relay. */
  relayHint: boolean;
  /** No server profile is confirmed yet: `official` or `custom`, `''` for none. */
  serverHint: string;
  bottomAvoidInset: number;
  onCancel: () => void;
  onRetry: () => void;
  onRetryViaRelay: () => void;
  onConfirmServer: () => void;
  onDismiss: () => void;
}

@ComponentV2
export struct ConnectionAttemptOverlay {
  @Param visible: boolean = false;
  @Param phase: string = 'idle';
  @Param target: string = '';
  @Param message: string = '';
  @Param relayHint: boolean = false;
  @Param serverHint: string = '';
  @Param bottomAvoidInset: number = 0;
  @Event onCancel: () => void = () => {};
  @Event onRetry: () => void = () => {};
  @Event onRetryViaRelay: () => void = () => {};
  @Event onConfirmServer: () => void = () => {};
  @Event onDismiss: () => void = () => {};

  private isFailed(): boolean {
    return this.phase === 'failed';
  }

  private title(): ResourceStr {
    if (this.phase === 'waiting_for_easytier') {
      return '正在准备 EasyTier 网络';
    }
    if (this.phase === 'awaiting_password') {
      return '等待密码验证';
    }
    if (this.phase === 'awaiting_approval') {
      return $r('app.string.resk_phase_approval');
    }
    if (this.phase === 'authenticating') {
      return '正在验证密码';
    }
    if (this.phase === 'rendering') {
      return '正在显示对方画面';
    }
    if (this.phase === 'connected') {
      return '连接成功';
    }
    if (this.offersServer()) {
      return '需要确认服务器';
    }
    if (this.isFailed()) {
      return '连接未完成';
    }
    return '正在连接';
  }

  private accessibleTitle(): string {
    const title = this.title();
    if (typeof title === 'string') {
      return title;
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(title.id) ?? this.phase;
  }

  private detail(): ResourceStr {
    if (this.message.trim().length > 0) {
      return this.message.trim();
    }
    if (this.isFailed()) {
      return '请检查设备状态、网络或密码后重试。';
    }
    if (this.phase === 'waiting_for_easytier') {
      return '正在等待 EasyTier 网络就绪，就绪后会自动继续连接。';
    }
    if (this.phase === 'awaiting_approval') {
      return $r('app.string.resk_status_approval');
    }
    if (this.phase === 'rendering') {
      return '连接已建立，正在等待首帧画面。';
    }
    return '连接成功后会自动显示远程画面。';
  }

  private isConnected(): boolean {
    return this.phase === 'connected';
  }

  private offersRelay(): boolean {
    return this.isFailed() && this.relayHint && !this.offersServer();
  }

  private offersServer(): boolean {
    return this.isFailed() && this.serverHint.length > 0;
  }

  private panelHeight(): number {
    if (this.offersServer()) {
      return 300;
    }
    if (this.offersRelay()) {
      return 284;
    }
    return this.isFailed() ? 228 : 216;
  }

  private innerContentPadding(): number {
    return 20;
  }

  private messageSlotHeight(): number {
    if (this.offersServer()) {
      return 66;
    }
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
        // A missing confirmation is a step to take, not an error.
        .fontColor(this.isFailed() && !this.offersServer()
          ? $r('app.color.error') : $r('app.color.neu_text_secondary'))
        .maxLines(this.offersServer() ? 4 : (this.isFailed() ? 3 : 2))
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
    if (this.offersServer()) {
      // Nothing failed here: one confirmation is missing, so it is the action.
      Column({ space: $r('app.float.space_12') }) {
        Row() {
          this.DialogButton(this.serverHint === 'official' ? '使用官方服务器并连接' : '保存并连接', true,
            (): void => this.onConfirmServer())
        }
        .width('100%');
        Row() {
          this.DialogButton('关闭', false, (): void => this.onDismiss())
        }
        .width('100%');
      }
      .width('100%');
    } else if (this.offersRelay()) {
      // The relayed route is the one that can still work, so it is the primary
      // action; a plain retry of the same direct route stays available.
      Column({ space: $r('app.float.space_12') }) {
        Row() {
          this.DialogButton('通过中继重试', true, (): void => this.onRetryViaRelay())
        }
        .width('100%');
        Row({ space: $r('app.float.space_12') }) {
          this.DialogButton('关闭', false, (): void => this.onDismiss())
          this.DialogButton('重试', false, (): void => this.onRetry())
        }
        .width('100%');
      }
      .width('100%');
    } else if (this.isFailed()) {
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

              Text(this.target.length > 0 ? this.target : '对方设备')
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
      .accessibilityText(this.accessibleTitle());
    }
  }
}
